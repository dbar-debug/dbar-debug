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
import zlib

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


def _decode(raw: bytes):
    """Декодує байти, визначаючи utf-8 vs cp1251 за кількістю замін."""
    u = raw.decode("utf-8", "replace")
    if u.count("�") > max(10, len(u) * 0.01):
        return raw.decode("cp1251", "replace"), "cp1251"
    return u, "utf-8"


def _print_csv_sample(raw: bytes):
    # Бінарні формати (xlsx = zip, тощо) не є CSV
    if raw[:2] == b"PK":
        print("Формат: XLSX/ZIP (Excel/архів) — потрібен окремий парсер (openpyxl).")
        return
    if raw.lstrip()[:1] in (b"{", b"["):
        print("Формат: JSON. Перші символи:")
        print("  " + raw.decode("utf-8", "replace")[:800])
        return

    text, enc = _decode(raw)
    text = text.replace("\x00", "")  # прибираємо NUL, щоб csv не падав
    first = text.split("\n", 1)[0]
    counts = {"\t": first.count("\t"), ";": first.count(";"), ",": first.count(",")}
    delim = max(counts, key=counts.get) if max(counts.values()) > 0 else ","
    names = {"\t": "TAB", ";": "крапка з комою", ",": "кома"}
    print(f"Кодування: {enc} | Роздільник: {names[delim]}\n")

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


def _stream_sample_zip(url: str) -> bool:
    """Потокова вибірка ПЕРШОГО файлу в zip без завантаження всього архіву."""
    import struct

    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=120) as resp:
        head = resp.read(65536)
        if head[:4] != b"PK\x03\x04":
            return False  # не локальний заголовок zip
        method = struct.unpack("<H", head[8:10])[0]
        fnlen = struct.unpack("<H", head[26:28])[0]
        exlen = struct.unpack("<H", head[28:30])[0]
        name = head[30:30 + fnlen].decode("utf-8", "replace")
        data = head[30 + fnlen + exlen:]
        print(f"Перший файл в архіві: {name} | метод стиснення: {method}")

        target = 300000
        if method == 0:  # без стиснення
            out = data
            while len(out) < target:
                chunk = resp.read(65536)
                if not chunk:
                    break
                out += chunk
            raw = out[:target]
        elif method == 8:  # deflate
            d = zlib.decompressobj(-15)
            out = d.decompress(data)
            while len(out) < target:
                chunk = resp.read(65536)
                if not chunk:
                    break
                out += d.decompress(chunk)
            raw = out[:target]
        else:
            print(f"Невідомий метод стиснення {method} — потрібне повне завантаження")
            return False

    _print_csv_sample(raw)
    return True


def _sample_resource(url: str):
    """Показати заголовок і перші рядки CSV (розпакувавши zip за потреби)."""
    size = _content_length(url)
    print(f"\n{'='*70}\nЗразок: {url}")
    print(f"Розмір (Content-Length): {_human(size)}")

    if url.lower().endswith(".zip"):
        # Великі архіви семплимо потоково (перший файл), малі — повністю
        if size and size > SAMPLE_SIZE_LIMIT:
            print("Тип: ZIP (великий) — потокова вибірка першого файлу...")
            if _stream_sample_zip(url):
                return
            print("Потокова вибірка не вдалась — потрібне повне завантаження.")
            return
        print("Тип: ZIP — розпаковую найбільший CSV усередині...")
        raw = _get(url)
        zf = zipfile.ZipFile(io.BytesIO(raw))
        infos = zf.infolist()
        print("Файли в архіві (розмір розпакований):")
        for zi in infos:
            print(f"  {zi.filename}  —  {_human(zi.file_size)}")
        csv_infos = [zi for zi in infos if zi.filename.lower().endswith(".csv")]
        if not csv_infos:
            print("У архіві немає CSV.")
            return
        biggest = max(csv_infos, key=lambda zi: zi.file_size)
        print(f"\nБеру найбільший: {biggest.filename} ({_human(biggest.file_size)})")
        with zf.open(biggest.filename) as f:
            _print_csv_sample(f.read(262144))
        return

    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=120) as resp:
        _print_csv_sample(resp.read(262144))


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

    if args[0] == "--url":
        _sample_resource(args[1])
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
