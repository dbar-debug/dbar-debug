"""
Імпортер «Єдиного реєстру боржників» (відкриті дані) у локальний
SQLite-індекс для пошуку за ПІБ/кодом.

Архів містить один великий CSV (~4 ГБ, cp1251, кома-розділ у лапках).
Качаємо zip у тимчасовий файл і потоково читаємо CSV.

Запуск (backend/):
    python3 import_debtors.py            # найсвіжіший zip (package_show)
    python3 import_debtors.py <url>      # конкретний zip
"""

import csv
import io
import json
import os
import sys
import tempfile
import time
import urllib.request
import zipfile

from app import debtors_db

DATASET_ID = "783b9b50-faba-4cc9-a393-60485e395b1d"
UA = "Mozilla/5.0 (court-app; +personal use)"


def _resolve_zip_url() -> str:
    api = f"https://data.gov.ua/api/3/action/package_show?id={DATASET_ID}"
    req = urllib.request.Request(api, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        pkg = json.loads(r.read().decode("utf-8"))["result"]
    zips = [x for x in pkg.get("resources", []) if (x.get("url") or "").lower().endswith(".zip")]
    pool = zips or pkg.get("resources", [])
    if not pool:
        raise RuntimeError("Не знайдено ресурсу в наборі боржників")
    return max(pool, key=lambda x: x.get("last_modified") or x.get("created") or "")["url"]


def _iter_rows(zip_path: str):
    with zipfile.ZipFile(zip_path) as zf:
        csv_infos = [zi for zi in zf.infolist() if zi.filename.lower().endswith(".csv")]
        biggest = max(csv_infos, key=lambda zi: zi.file_size)
        print(f"[debtors] Читаю {biggest.filename} ({biggest.file_size/1024/1024/1024:.1f} ГБ)")
        with zf.open(biggest.filename) as raw:
            text = io.TextIOWrapper(raw, encoding="cp1251", errors="replace")
            reader = csv.reader(text, delimiter=",", quotechar='"')
            for row in reader:
                # заголовок (через ; → один елемент) або короткі рядки пропускаємо
                if len(row) < 11 or row[0].strip().upper() == "DEBTOR_NAME":
                    continue
                # 0 name,1 birthdate,2 code,3 publisher,4 org_name,
                # 6 executor,9 vp_num,10 category
                yield (
                    row[0].strip(), row[1].strip(), row[2].strip(), row[3].strip(),
                    row[4].strip(), row[6].strip(), row[9].strip(), row[10].strip(),
                )


def main():
    t0 = time.time()
    data_dir = os.path.dirname(debtors_db.DB_PATH) or "."
    os.makedirs(data_dir, exist_ok=True)

    urls = [a for a in sys.argv[1:] if a.startswith("http")]
    url = urls[0] if urls else _resolve_zip_url()
    print(f"[debtors] Завантажую zip: {url}")

    fd, tmp_zip = tempfile.mkstemp(suffix=".zip", dir=data_dir)
    os.close(fd)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=1200) as resp, open(tmp_zip, "wb") as f:
            while True:
                chunk = resp.read(1 << 20)
                if not chunk:
                    break
                f.write(chunk)
        print(f"[debtors] Завантажено {os.path.getsize(tmp_zip)/1024/1024:.0f} МБ "
              f"({time.time()-t0:.0f}с). Будую базу...")

        count = debtors_db.build(_iter_rows(tmp_zip))
        print(f"[debtors] Готово: {count:,} записів за {time.time()-t0:.0f}с")
        print(f"[debtors] База: {debtors_db.DB_PATH}")
    finally:
        if os.path.exists(tmp_zip):
            os.remove(tmp_zip)


if __name__ == "__main__":
    main()
