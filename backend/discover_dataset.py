"""
Розвідник відкритих наборів data.gov.ua: знаходить набір за запитом або
за id, показує його ресурси (з розмірами) і перші рядки CSV — навіть
якщо CSV запакований у .zip. Мета — дізнатись реальну схему колонок і
обсяг даних перед написанням імпортера.

Використання (на сервері, backend/):
    python3 discover_dataset.py "стан розгляду справ"     # пошук
    python3 discover_dataset.py --id 0ad60ea9-b029-456d-abc0-8c77a99b205c
"""

import csv
import io
import json
import sys
import urllib.parse
import urllib.request
import zipfile

UA = "Mozilla/5.0 (court-app; discovery)"
SAMPLE_SIZE_LIMIT = 800 * 1024 * 1024  # не качати авто-зразок, якщо файл > 800 МБ


def _get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def _content_length(url: str):
    try:
        req = urllib.request.Request(url, headers={"User-Agent": UA}, method="HEAD")
        with urllib.request.urlopen(req, timeout=30) as r:
            cl = r.headers.get("Content-Length")
            return int(cl) if cl else None
    except Exception:
        return None


def _human(n):
    if n is None:
        return "?"
    for unit in ("Б", "КБ", "МБ", "ГБ"):
        if n < 1024:
            return f"{n:.0f} {unit}"
        n /= 1024
    return f"{n:.1f} ТБ"


def _print_resources(pkg):
    print(f"Набір: {pkg.get('title')}  id={pkg.get('id')}")
    resources = pkg.get("resources", [])
    print(f"Ресурсів: {len(resources)}\n")
    for res in resources:
        fmt = (res.get("format") or "").upper()
        print(f"  • {res.get('name')}")
        print(f"    format={fmt}  size={_human(res.get('size'))}  "
              f"created={res.get('created')}  last_modified={res.get('last_modified')}")
        print(f"    {res.get('url')}")
    return resources


def _sample_resource(url: str):
    """Показати заголовок і перші рядки CSV (розпакувавши zip за потреби)."""
    size = _content_length(url)
    print(f"\n{'='*70}\nЗразок: {url}")
    print(f"Розмір (Content-Length): {_human(size)}")
    if size and size > SAMPLE_SIZE_LIMIT:
        print(f"⚠ Файл завеликий для авто-зразка (>{_human(SAMPLE_SIZE_LIMIT)}). "
              "Скажи — зробимо потокову вибірку.")
        return

    if url.lower().endswith(".zip"):
        print("Тип: ZIP — розпаковую перший CSV усередині...")
        raw = _get(url)
        zf = zipfile.ZipFile(io.BytesIO(raw))
        names = zf.namelist()
        print(f"Файли в архіві: {names}")
        csv_name = next((n for n in names if n.lower().endswith(".csv")), names[0] if names else None)
        if not csv_name:
            print("У архіві немає CSV.")
            return
        with zf.open(csv_name) as f:
            chunk = f.read(262144)
    else:
        req = urllib.request.Request(url, headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=120) as resp:
            chunk = resp.read(262144)

    text = chunk.decode("utf-8", errors="replace")
    first_line = text.split("\n", 1)[0]
    delim = "\t" if first_line.count("\t") >= first_line.count(",") else ","
    print(f"Роздільник: {'TAB' if delim == chr(9) else 'кома'}\n")

    reader = csv.reader(io.StringIO(text), delimiter=delim, quotechar='"')
    for idx, row in enumerate(reader):
        if idx == 0:
            print("ЗАГОЛОВОК (колонки):")
            for c, name in enumerate(row):
                print(f"  [{c}] {name}")
            print("\nПЕРШІ РЯДКИ ДАНИХ:")
        else:
            print(f"  рядок {idx}: {row}")
        if idx >= 3:
            break


def _newest_resource(resources):
    """Найсвіжіший ДАНИЙ ресурс (csv/zip), ігноруючи readme/pdf."""
    data_res = [
        r for r in resources
        if (r.get("format") or "").upper() in ("CSV", "ZIP")
        or (r.get("url") or "").lower().endswith((".csv", ".zip"))
    ]
    pool = data_res or resources
    dated = [r for r in pool if "vid-" in (r.get("name") or "").lower()]
    pool = dated or pool
    def keyf(r):
        return r.get("last_modified") or r.get("created") or ""
    return max(pool, key=keyf) if pool else None


def main():
    args = sys.argv[1:]
    if not args:
        print("Вкажи запит або --id <dataset_id>")
        return

    if args[0] == "--id":
        dataset_id = args[1]
        api = f"https://data.gov.ua/api/3/action/package_show?id={dataset_id}"
        pkg = json.loads(_get(api).decode("utf-8"))["result"]
        resources = _print_resources(pkg)
        newest = _newest_resource(resources)
        if newest:
            print(f"\nНайсвіжіший ресурс: {newest.get('name')}")
            _sample_resource(newest["url"])
        return

    query = args[0]
    print(f"Пошук набору: {query}\n")
    api = "https://data.gov.ua/api/3/action/package_search?q=" + urllib.parse.quote(query) + "&rows=10"
    data = json.loads(_get(api).decode("utf-8"))
    results = data.get("result", {}).get("results", [])
    print(f"Знайдено наборів: {len(results)}\n")
    for i, r in enumerate(results):
        print(f"[{i}] {r.get('title')}  id={r.get('id')}")


if __name__ == "__main__":
    main()
