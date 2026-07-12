"""
Імпортер «Автоматизованої системи виконавчого провадження» (АСВП,
відкриті дані) у локальний SQLite-індекс для пошуку за ПІБ/кодом.

Архів (~3 ГБ) містить один великий CSV (cp1251, кома-розділ у лапках).
Качаємо zip у тимчасовий файл і потоково читаємо CSV.

Запуск (backend/):
    python3 import_debtors.py <url>      # конкретний zip (nais.gov.ua)
    python3 import_debtors.py            # найсвіжіший (через package_show,
                                         # якщо задано ASVP_DATASET_ID)

Свіжий URL змінюється щодня (з датою у шляху), тож для автооновлення
потрібен ASVP_DATASET_ID набору на data.gov.ua — тоді package_show
віддасть актуальне посилання.
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

# id набору АСВП на data.gov.ua — package_show віддасть актуальне
# посилання для автооновлення (пряме посилання nais щодня нове).
ASVP_DATASET_ID = os.getenv("ASVP_DATASET_ID", "22aef563-3e87-4ed9-92e8-d764dc02f426")
UA = "Mozilla/5.0 (court-app; +personal use)"


def _resolve_zip_url() -> str:
    if not ASVP_DATASET_ID:
        raise RuntimeError(
            "Передайте URL zip-файлу АСВП або встановіть ASVP_DATASET_ID "
            "(id набору на data.gov.ua) для автооновлення."
        )
    api = f"https://data.gov.ua/api/3/action/package_show?id={ASVP_DATASET_ID}"
    req = urllib.request.Request(api, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        pkg = json.loads(r.read().decode("utf-8"))["result"]
    zips = [x for x in pkg.get("resources", []) if (x.get("url") or "").lower().endswith(".zip")]
    pool = zips or pkg.get("resources", [])
    if not pool:
        raise RuntimeError("Не знайдено ресурсу в наборі АСВП")
    return max(pool, key=lambda x: x.get("last_modified") or x.get("created") or "")["url"]


def _iter_rows(zip_path: str):
    with zipfile.ZipFile(zip_path) as zf:
        csv_infos = [zi for zi in zf.infolist() if zi.filename.lower().endswith(".csv")]
        biggest = max(csv_infos, key=lambda zi: zi.file_size)
        print(f"[asvp] Читаю {biggest.filename} ({biggest.file_size/1024/1024/1024:.1f} ГБ)")
        member = zf.open(biggest.filename)
        # Деякі держ-архіви мають розбіжність CRC у кінці — не валимось на
        # цьому, використовуємо розпаковані дані як є.
        try:
            member._expected_crc = None
        except Exception:
            pass
        with member:
            text = io.TextIOWrapper(member, encoding="cp1251", errors="replace")
            reader = csv.reader(text, delimiter=",", quotechar='"')
            for row in reader:
                if len(row) < 9 or row[0].strip().upper() == "DEBTOR_NAME":
                    continue
                # 0 name,1 birthdate,2 code,3 creditor_name,5 vp_num,
                # 6 vp_begindate,7 vp_state,8 org_name
                yield (
                    row[0].strip(),
                    row[1].strip()[:10],   # 23.05.1980 00:00:00 -> 23.05.1980
                    row[2].strip(),
                    row[3].strip(),
                    row[5].strip(),
                    row[6].strip()[:10],
                    row[7].strip(),
                    row[8].strip(),
                )


def main():
    t0 = time.time()
    data_dir = os.path.dirname(debtors_db.DB_PATH) or "."
    os.makedirs(data_dir, exist_ok=True)

    urls = [a for a in sys.argv[1:] if a.startswith("http")]
    url = urls[0] if urls else _resolve_zip_url()
    print(f"[asvp] Завантажую zip: {url}")

    fd, tmp_zip = tempfile.mkstemp(suffix=".zip", dir=data_dir)
    os.close(fd)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=1800) as resp, open(tmp_zip, "wb") as f:
            while True:
                chunk = resp.read(1 << 20)
                if not chunk:
                    break
                f.write(chunk)
        print(f"[asvp] Завантажено {os.path.getsize(tmp_zip)/1024/1024:.0f} МБ "
              f"({time.time()-t0:.0f}с). Будую базу...")

        count = debtors_db.build(_iter_rows(tmp_zip))
        print(f"[asvp] Готово: {count:,} записів за {time.time()-t0:.0f}с")
        print(f"[asvp] База: {debtors_db.DB_PATH}")
    finally:
        if os.path.exists(tmp_zip):
            os.remove(tmp_zip)


if __name__ == "__main__":
    main()
