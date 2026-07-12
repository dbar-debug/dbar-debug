"""
Судові засідання з відкритих даних "Список справ призначених до розгляду"
(data.gov.ua, оновлюється щодня, CC-BY).

CKAN datastore для цього ресурсу вимкнено (datastore_search → Not Found),
тож завантажуємо CSV-файл потоково і фільтруємо по номерах справ
користувача, не тримаючи весь файл (~313 МБ) у памʼяті.

Свіжий URL файлу шукаємо через package_show (resource_id може мінятись
при щоденному оновленні) з fallback на відомий прямий лінк.

Реальний порядок колонок у файлі (tab-separated, у лапках, UTF-8):
  0 date            "10.08.2026 10:30"
  1 judges          "Головуючий суддя: ..."
  2 case            "754/899/26"
  3 court_name      "Деснянський районний суд міста Києва"
  4 court_room      "36"
  5 case_involved   "Позивач: ... відповідач: ..."
  6 case_description "про стягнення заборгованості"
"""

import asyncio
import csv
import io
import json
import re
import time
import urllib.request
from typing import Iterator, List, Set

from app import hearings_db

DATASET_ID = "42eaff6e-45da-4426-b4a1-f30989bfd36f"
# Прямий лінк (fallback, якщо package_show недоступний)
FALLBACK_CSV_URL = (
    "https://data.gov.ua/dataset/3a321301-a06f-487b-9d19-e6b917250aee/"
    "resource/98d6ba0d-1c18-4835-ae68-bfc0af724bfa/download/"
    "spisok-sprav-priznachenih-do-rozglyadu.csv"
)

_UA = "Mozilla/5.0 (court-app; +personal use)"
_CACHE_TTL = 6 * 3600  # оновлюється раз на день, кеш на 6 год

# Простий кеш на рівні модуля: {numbers_key: (timestamp, hearings)}
_cache: dict = {}


async def get_hearings_for_cases(case_numbers: List[str]) -> List[dict]:
    """Повертає засідання для заданих номерів справ (з кешем)."""
    numbers = {n.strip() for n in case_numbers if n and n.strip() and n != "—"}
    if not numbers:
        return []

    # Є локальний індекс → швидкий запит з SQLite
    if hearings_db.available():
        return await asyncio.to_thread(hearings_db.query_by_cases, numbers)

    key = ",".join(sorted(numbers))
    cached = _cache.get(key)
    if cached and (time.time() - cached[0]) < _CACHE_TTL:
        print(f"[hearings] Кеш: {len(cached[1])} засідань")
        return cached[1]

    hearings = await asyncio.to_thread(_download_and_filter, numbers)
    _cache[key] = (time.time(), hearings)
    return hearings


async def get_hearings_for_name(full_name: str) -> List[dict]:
    """
    Повертає засідання, де ПІБ зустрічається серед учасників справи —
    для мультиюзерного пошуку за іменем (без КЕП/кабінету).
    """
    name_norm = _normalize(full_name)
    if len(name_norm) < 5:
        return []

    # Є локальний індекс → швидкий FTS-запит
    if hearings_db.available():
        return await asyncio.to_thread(hearings_db.query_by_name, name_norm)

    key = "name:" + name_norm
    cached = _cache.get(key)
    if cached and (time.time() - cached[0]) < _CACHE_TTL:
        print(f"[hearings] Кеш (імʼя): {len(cached[1])} засідань")
        return cached[1]

    hearings = await asyncio.to_thread(_download_and_filter_by_name, name_norm)
    _cache[key] = (time.time(), hearings)
    return hearings


def _download_and_filter(numbers: Set[str]) -> List[dict]:
    hearings = _stream_and_collect(lambda row: row[2].strip() in numbers)
    print(f"[hearings] Знайдено {len(hearings)} засідань для {len(numbers)} справ")
    return hearings


def _download_and_filter_by_name(name_norm: str) -> List[dict]:
    """Фільтр за ПІБ: імʼя має зустрічатись серед учасників справи (row[5])."""
    hearings = _stream_and_collect(
        lambda row: name_norm in _normalize(row[5])
    )
    print(f"[hearings] Знайдено {len(hearings)} засідань для «{name_norm}»")
    return hearings


def _stream_and_collect(predicate) -> List[dict]:
    """
    Потоково читає CSV і збирає засідання для рядків, що проходять predicate.
    Дедуплікує за (номер справи, дата, час) і сортує за датою/часом.
    """
    url = _resolve_csv_url()
    print(f"[hearings] Завантажую CSV: {url}")
    hearings: List[dict] = []
    seen = set()

    req = urllib.request.Request(url, headers={"User-Agent": _UA})
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            text = io.TextIOWrapper(resp, encoding="utf-8", errors="replace")
            reader = csv.reader(text, delimiter="\t", quotechar='"')
            for row in reader:
                if len(row) < 7:
                    continue
                if not predicate(row):
                    continue
                h = _row_to_hearing(row)
                dedup = (h["case_number"], h["date"], h["time"])
                if dedup in seen:
                    continue
                seen.add(dedup)
                hearings.append(h)
    except Exception as e:
        print(f"[hearings] Помилка завантаження/парсингу: {e}")

    hearings.sort(key=lambda h: (h["date"], h["time"]))
    return hearings


def iter_all_hearings() -> Iterator[dict]:
    """
    Потоково видає ВСІ засідання з CSV (для імпортера в SQLite).
    Без дедуплікації — її робить побудова бази.
    """
    url = _resolve_csv_url()
    print(f"[hearings] Імпорт CSV: {url}")
    req = urllib.request.Request(url, headers={"User-Agent": _UA})
    with urllib.request.urlopen(req, timeout=600) as resp:
        text = io.TextIOWrapper(resp, encoding="utf-8", errors="replace")
        reader = csv.reader(text, delimiter="\t", quotechar='"')
        for row in reader:
            if len(row) < 7:
                continue
            yield _row_to_hearing(row)


def _row_to_hearing(row: List[str]) -> dict:
    """Рядок CSV → словник засідання (єдина точка мапінгу колонок)."""
    date_iso, htime = _split_date_time(row[0].strip())
    return {
        "date": date_iso,
        "time": htime,
        "case_number": row[2].strip(),
        "court_name": row[3].strip(),
        "judges": row[1].strip(),
        "case_involved": row[5].strip(),
        "case_description": row[6].strip(),
        "court_room": row[4].strip(),
    }


def _normalize(s: str) -> str:
    """Нормалізація для порівняння імен: нижній регістр, стиснені пробіли."""
    return " ".join((s or "").lower().split())


def _resolve_csv_url() -> str:
    """Знайти URL найсвіжішого CSV через package_show; інакше fallback."""
    try:
        api = f"https://data.gov.ua/api/3/action/package_show?id={DATASET_ID}"
        req = urllib.request.Request(api, headers={"User-Agent": _UA})
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        resources = data.get("result", {}).get("resources", [])
        # найновіший CSV-ресурс
        csv_res = [r for r in resources if (r.get("format") or "").upper() == "CSV"]
        pick = csv_res[-1] if csv_res else (resources[-1] if resources else None)
        if pick and pick.get("url"):
            return pick["url"]
    except Exception as e:
        print(f"[hearings] package_show недоступний ({e}), використовую fallback URL")
    return FALLBACK_CSV_URL


def _split_date_time(raw: str) -> tuple[str, str]:
    """'10.08.2026 10:30' -> ('2026-08-10', '10:30'). Підтримує й ISO."""
    if not raw:
        return "", ""

    # dd.mm.yyyy [HH:MM]
    m = re.match(r"(\d{2})\.(\d{2})\.(\d{4})(?:[ ]+(\d{1,2}):(\d{2}))?", raw)
    if m:
        d, mo, y, hh, mm = m.groups()
        date_iso = f"{y}-{mo}-{d}"
        htime = f"{int(hh):02d}:{mm}" if hh and mm else ""
        return date_iso, htime

    # ISO: 2026-08-10[ T]10:30
    m = re.match(r"(\d{4})-(\d{2})-(\d{2})[ T]?(\d{2})?:?(\d{2})?", raw)
    if m:
        y, mo, d, hh, mm = m.groups()
        return f"{y}-{mo}-{d}", (f"{hh}:{mm}" if hh and mm else "")

    return raw, ""
