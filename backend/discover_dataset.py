"""
Розвідник відкритих наборів data.gov.ua: знаходить набір за запитом,
показує його ресурси й перші рядки CSV (заголовок + приклади) — щоб
дізнатись реальну схему колонок перед написанням імпортера.

Використання (на сервері, backend/):
    python3 discover_dataset.py "стан розгляду справ"
"""

import csv
import io
import sys
import urllib.parse
import urllib.request

UA = "Mozilla/5.0 (court-app; discovery)"


def _get(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read()


def main():
    query = sys.argv[1] if len(sys.argv) > 1 else "стан розгляду справ"
    print(f"Пошук набору: {query}\n")

    api = "https://data.gov.ua/api/3/action/package_search?q=" + urllib.parse.quote(query) + "&rows=10"
    import json
    data = json.loads(_get(api).decode("utf-8"))
    results = data.get("result", {}).get("results", [])
    print(f"Знайдено наборів: {len(results)}\n")

    for i, r in enumerate(results):
        print(f"[{i}] {r.get('title')}")
        print(f"     id={r.get('id')}  name={r.get('name')}")
        csv_res = [res for res in r.get("resources", []) if (res.get("format") or "").upper() == "CSV"]
        for res in csv_res[:3]:
            print(f"     CSV: {res.get('name')}  id={res.get('id')}")
            print(f"          {res.get('url')}")
        print()

    if not results:
        return

    # Беремо найперший CSV найпершого набору і показуємо перші рядки
    top = results[0]
    csv_res = [res for res in top.get("resources", []) if (res.get("format") or "").upper() == "CSV"]
    if not csv_res:
        print("У першому наборі немає CSV-ресурсу.")
        return

    url = csv_res[-1]["url"]
    print("=" * 70)
    print(f"Зразок даних із: {url}\n")

    # Качаємо лише початок (перші ~256 КБ), щоб не тягнути весь файл
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as resp:
        chunk = resp.read(262144)
    text = chunk.decode("utf-8", errors="replace")

    # Пробуємо визначити роздільник за першим рядком
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


if __name__ == "__main__":
    main()
