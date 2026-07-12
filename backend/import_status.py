"""
Імпортер відкритих даних «Інформація щодо стану розгляду справ» у
локальний SQLite-індекс (FTS5) для пошуку стану справ за ПІБ.

Найсвіжіші дані — це .zip (~710 МБ) з десятками CSV усередині. Качаємо
zip у тимчасовий файл, потоково читаємо кожен CSV і згодовуємо рядки
у status_db.build (яка залишає останню стадію по кожній справі).

Запуск вручну (backend/):
    python3 import_status.py
Автоматично — раз на добу через systemd-таймер (server/status-import.timer).
"""

import csv
import io
import json
import os
import tempfile
import time
import urllib.request
import zipfile

from app import status_db

DATASET_ID = "0ad60ea9-b029-456d-abc0-8c77a99b205c"
UA = "Mozilla/5.0 (court-app; +personal use)"


def _resolve_zip_url() -> str:
    """URL найсвіжішого датованого zip-снепшоту через package_show."""
    api = f"https://data.gov.ua/api/3/action/package_show?id={DATASET_ID}"
    req = urllib.request.Request(api, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        pkg = json.loads(r.read().decode("utf-8"))["result"]
    resources = pkg.get("resources", [])
    zips = [r for r in resources if (r.get("url") or "").lower().endswith(".zip")]
    pool = zips or resources
    newest = max(pool, key=lambda r: r.get("last_modified") or r.get("created") or "")
    return newest["url"]


def _iter_zip_rows(zip_path: str):
    """Видає кортежі рядків (у порядку status_db.IN_COLS) з усіх CSV у zip."""
    with zipfile.ZipFile(zip_path) as zf:
        csv_names = sorted(n for n in zf.namelist() if n.lower().endswith(".csv"))
        for name in csv_names:
            print(f"[status] Читаю {name} ...")
            with zf.open(name) as raw:
                text = io.TextIOWrapper(raw, encoding="utf-8", errors="replace")
                reader = csv.reader(text, delimiter="\t", quotechar='"')
                for row in reader:
                    if len(row) < 13:
                        continue
                    if row[0] == "court_name":   # заголовок
                        continue
                    # 0 court_name,1 case_number,2 case_proc,3 registration_date,
                    # 4 judge,5 judges,6 participants,7 stage_date,8 stage_name,
                    # 9 cause_result,12 description
                    yield (
                        row[0].strip(), row[1].strip(), row[2].strip(), row[3].strip(),
                        row[4].strip(), row[5].strip(), row[6].strip(), row[7].strip(),
                        row[8].strip(), row[9].strip(), row[12].strip(),
                    )


def main():
    t0 = time.time()
    data_dir = os.path.dirname(status_db.DB_PATH) or "."
    os.makedirs(data_dir, exist_ok=True)  # zip качаємо поряд із базою

    url = _resolve_zip_url()
    print(f"[status] Завантажую zip: {url}")

    fd, tmp_zip = tempfile.mkstemp(suffix=".zip", dir=data_dir)
    os.close(fd)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=600) as resp, open(tmp_zip, "wb") as f:
            while True:
                chunk = resp.read(1 << 20)
                if not chunk:
                    break
                f.write(chunk)
        print(f"[status] Завантажено {os.path.getsize(tmp_zip) / 1024 / 1024:.0f} МБ за {time.time()-t0:.0f}с")

        count = status_db.build(_iter_zip_rows(tmp_zip))
        print(f"[status] Готово: {count:,} унікальних справ за {time.time()-t0:.0f}с")
        print(f"[status] База: {status_db.DB_PATH}")
    finally:
        if os.path.exists(tmp_zip):
            os.remove(tmp_zip)


if __name__ == "__main__":
    main()
