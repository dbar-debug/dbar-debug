"""
Імпортер боргів: обʼєднує ДВА відкриті набори в одну базу пошуку за
ПІБ/кодом:
  • ЄРБ  (Єдиний реєстр боржників)               id=783b9b50-...
  • АСВП (Автоматизована система вик. провадження) id=22aef563-...

Обидва — cp1251, кома-розділ, у lапках. Качаємо zip кожного по черзі,
потоково читаємо й будуємо одну базу (союз рядків з позначкою source).

Запуск (backend/):
    python3 import_debtors.py                         # обидва (через package_show)
    python3 import_debtors.py --erb <url> --asvp <url>  # явні посилання
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

ERB_DATASET_ID = os.getenv("ERB_DATASET_ID", "783b9b50-faba-4cc9-a393-60485e395b1d")
ASVP_DATASET_ID = os.getenv("ASVP_DATASET_ID", "22aef563-3e87-4ed9-92e8-d764dc02f426")
UA = "Mozilla/5.0 (court-app; +personal use)"


def _resolve_zip_url(dataset_id: str) -> str:
    api = f"https://data.gov.ua/api/3/action/package_show?id={dataset_id}"
    req = urllib.request.Request(api, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        pkg = json.loads(r.read().decode("utf-8"))["result"]
    zips = [x for x in pkg.get("resources", []) if (x.get("url") or "").lower().endswith(".zip")]
    pool = zips or pkg.get("resources", [])
    if not pool:
        raise RuntimeError(f"Немає ресурсу в наборі {dataset_id}")
    return max(pool, key=lambda x: x.get("last_modified") or x.get("created") or "")["url"]


def _download(url: str, data_dir: str) -> str:
    print(f"[debtors] Завантажую zip: {url}")
    fd, tmp = tempfile.mkstemp(suffix=".zip", dir=data_dir)
    os.close(fd)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=1800) as resp, open(tmp, "wb") as f:
        while True:
            chunk = resp.read(1 << 20)
            if not chunk:
                break
            f.write(chunk)
    print(f"[debtors] Завантажено {os.path.getsize(tmp)/1024/1024:.0f} МБ")
    return tmp


def _open_biggest_csv(zf: zipfile.ZipFile):
    """Відкриває найбільший CSV, ігноруючи розбіжність CRC (буває у держ-архівах)."""
    csv_infos = [zi for zi in zf.infolist() if zi.filename.lower().endswith(".csv")]
    biggest = max(csv_infos, key=lambda zi: zi.file_size)
    print(f"[debtors] Читаю {biggest.filename} ({biggest.file_size/1024/1024/1024:.1f} ГБ)")
    member = zf.open(biggest.filename)
    try:
        member._expected_crc = None
    except Exception:
        pass
    return member


def _erb_rows(zip_path: str):
    """ЄРБ: name,birthdate,code,publisher,org_name,phone,executor(6),...,vp_num(9),category(10)."""
    with zipfile.ZipFile(zip_path) as zf, _open_biggest_csv(zf) as member:
        text = io.TextIOWrapper(member, encoding="cp1251", errors="replace")
        for row in csv.reader(text, delimiter=",", quotechar='"'):
            if len(row) < 11 or row[0].strip().upper() == "DEBTOR_NAME":
                continue
            yield ("ЄРБ", row[0].strip(), row[1].strip(), row[2].strip(),
                   "",                     # creditor_name
                   row[10].strip(),        # category
                   row[9].strip(),         # vp_num
                   "", "",                 # vp_begindate, vp_state
                   row[4].strip(),         # org_name
                   row[6].strip())         # executor


def _asvp_rows(zip_path: str):
    """АСВП: name,birthdate,code,creditor(3),creditor_code,vp_num(5),begindate(6),state(7),org(8)."""
    with zipfile.ZipFile(zip_path) as zf, _open_biggest_csv(zf) as member:
        text = io.TextIOWrapper(member, encoding="cp1251", errors="replace")
        for row in csv.reader(text, delimiter=",", quotechar='"'):
            if len(row) < 9 or row[0].strip().upper() == "DEBTOR_NAME":
                continue
            yield ("АСВП", row[0].strip(), row[1].strip()[:10], row[2].strip(),
                   row[3].strip(),         # creditor_name
                   "",                     # category
                   row[5].strip(),         # vp_num
                   row[6].strip()[:10],    # vp_begindate
                   row[7].strip(),         # vp_state
                   row[8].strip(),         # org_name
                   "")                     # executor


def _all_rows(erb_url: str, asvp_url: str, data_dir: str):
    """Качає й читає обидва набори по черзі (по одному zip на диску за раз)."""
    for label, url, reader in (("ЄРБ", erb_url, _erb_rows), ("АСВП", asvp_url, _asvp_rows)):
        print(f"\n=== {label} ===")
        tmp = _download(url, data_dir)
        try:
            yield from reader(tmp)
        finally:
            os.remove(tmp)


def _arg(flag: str):
    if flag in sys.argv:
        i = sys.argv.index(flag)
        if i + 1 < len(sys.argv):
            return sys.argv[i + 1]
    return None


def main():
    t0 = time.time()
    data_dir = os.path.dirname(debtors_db.DB_PATH) or "."
    os.makedirs(data_dir, exist_ok=True)

    erb_url = _arg("--erb") or _resolve_zip_url(ERB_DATASET_ID)
    asvp_url = _arg("--asvp") or _resolve_zip_url(ASVP_DATASET_ID)

    count = debtors_db.build(_all_rows(erb_url, asvp_url, data_dir))
    print(f"\n[debtors] Готово: {count:,} записів (ЄРБ+АСВП) за {time.time()-t0:.0f}с")
    print(f"[debtors] База: {debtors_db.DB_PATH}")


if __name__ == "__main__":
    main()
