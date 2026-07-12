"""
Імпортер ЄДРСР (за 2026 рік) у локальний SQLite-індекс рішень за
номером справи.

Архів (~202 МБ) містить довідники (courts, judgment_forms, justice_kinds,
cause_categories) і головний documents.csv. Розшифровуємо коди й
зберігаємо назви прямо в рядку.

Запуск (backend/):
    python3 import_decisions.py                # найсвіжіший zip (package_show)
    python3 import_decisions.py <url>          # конкретний zip
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

from app import decisions_db

DATASET_ID = "16ab7f06-7414-405f-8354-0a492475272d"
UA = "Mozilla/5.0 (court-app; +personal use)"


def _resolve_zip_url() -> str:
    api = f"https://data.gov.ua/api/3/action/package_show?id={DATASET_ID}"
    req = urllib.request.Request(api, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        pkg = json.loads(r.read().decode("utf-8"))["result"]
    zips = [x for x in pkg.get("resources", []) if (x.get("url") or "").lower().endswith(".zip")]
    if not zips:
        raise RuntimeError("Не знайдено zip-ресурсу в наборі ЄДРСР")
    return max(zips, key=lambda x: x.get("last_modified") or x.get("created") or "")["url"]


def _load_dict(zf: zipfile.ZipFile, name: str) -> dict:
    """Довідник код→назва. Ключ — колонка [0], значення — колонка 'name' або [1]."""
    d = {}
    try:
        with zf.open(name) as f:
            reader = csv.reader(io.TextIOWrapper(f, encoding="utf-8", errors="replace"),
                                delimiter="\t", quotechar='"')
            header = next(reader, None)
            name_idx = 1
            if header:
                for i, col in enumerate(header):
                    if col.strip().lower() == "name":
                        name_idx = i
                        break
            for row in reader:
                if len(row) > name_idx and row[0]:
                    d[row[0].strip()] = row[name_idx].strip()
    except KeyError:
        print(f"[decisions] Довідник {name} відсутній — пропускаю")
    return d


def _iter_rows(zip_path: str):
    with zipfile.ZipFile(zip_path) as zf:
        courts = _load_dict(zf, "courts.csv")
        forms = _load_dict(zf, "judgment_forms.csv")
        kinds = _load_dict(zf, "justice_kinds.csv")
        cats = _load_dict(zf, "cause_categories.csv")
        print(f"[decisions] Довідники: суди={len(courts)}, форми={len(forms)}, "
              f"види={len(kinds)}, категорії={len(cats)}")

        with zf.open("documents.csv") as f:
            reader = csv.reader(io.TextIOWrapper(f, encoding="utf-8", errors="replace"),
                                delimiter="\t", quotechar='"')
            header = next(reader, None)  # doc_id,court_code,judgment_code,justice_kind,category_code,cause_num,...
            for row in reader:
                if len(row) < 12:
                    continue
                doc_id = row[0].strip()
                cause_num = row[5].strip()
                if not cause_num:
                    continue
                yield (
                    doc_id,
                    cause_num,
                    courts.get(row[1].strip(), ""),
                    forms.get(row[2].strip(), ""),
                    kinds.get(row[3].strip(), ""),
                    cats.get(row[4].strip(), ""),
                    row[6].strip()[:10],   # adjudication_date -> YYYY-MM-DD
                    row[8].strip(),        # judge
                    row[9].strip(),        # doc_url
                    row[10].strip(),       # status
                )


def main():
    t0 = time.time()
    data_dir = os.path.dirname(decisions_db.DB_PATH) or "."
    os.makedirs(data_dir, exist_ok=True)

    urls = [a for a in sys.argv[1:] if a.startswith("http")]
    url = urls[0] if urls else _resolve_zip_url()
    print(f"[decisions] Завантажую zip: {url}")

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
        print(f"[decisions] Завантажено {os.path.getsize(tmp_zip)/1024/1024:.0f} МБ "
              f"({time.time()-t0:.0f}с). Будую базу...")

        count = decisions_db.build(_iter_rows(tmp_zip))
        print(f"[decisions] Готово: {count:,} рішень за {time.time()-t0:.0f}с")
        print(f"[decisions] База: {decisions_db.DB_PATH}")
    finally:
        if os.path.exists(tmp_zip):
            os.remove(tmp_zip)


if __name__ == "__main__":
    main()
