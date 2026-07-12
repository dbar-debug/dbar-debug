"""
Судові засідання з відкритих даних "Список справ призначених до розгляду"
(data.gov.ua, оновлюється щодня, CC-BY).

Датасет має активний CKAN datastore, тож шукаємо засідання по номеру
справи через datastore_search API — без завантаження всього CSV (~313 МБ).

Поля датасету: case, judges, case_involved, court_room, case_description,
date, court_name.
"""

import re
from typing import List

from playwright.async_api import async_playwright

DATA_GOV_UA = "https://data.gov.ua"
RESOURCE_ID = "98d6ba0d-1c18-4835-ae68-bfc0af724bfa"


async def get_hearings_for_cases(case_numbers: List[str]) -> List[dict]:
    """
    Повертає засідання для заданих номерів справ.
    Кожне: {date, time, case_number, court_name, judges, case_involved,
            case_description, court_room}.
    """
    hearings: List[dict] = []
    seen = set()

    async with async_playwright() as pw:
        api = await pw.request.new_context()
        try:
            for number in case_numbers:
                if not number or number == "—":
                    continue
                records = await _datastore_search(api, number)
                for r in records:
                    # datastore може повернути частковий збіг — лишаємо точні
                    if (r.get("case") or "").strip() != number.strip():
                        continue
                    date_raw = (r.get("date") or "").strip()
                    date_iso, time = _split_date_time(date_raw)
                    key = (number, date_iso, time)
                    if key in seen:
                        continue
                    seen.add(key)
                    hearings.append({
                        "date": date_iso,
                        "time": time,
                        "case_number": number,
                        "court_name": (r.get("court_name") or "").strip(),
                        "judges": (r.get("judges") or "").strip(),
                        "case_involved": (r.get("case_involved") or "").strip(),
                        "case_description": (r.get("case_description") or "").strip(),
                        "court_room": (r.get("court_room") or "").strip(),
                    })
        finally:
            await api.dispose()

    hearings.sort(key=lambda h: (h["date"], h["time"]))
    print(f"[hearings] Знайдено {len(hearings)} засідань для {len(case_numbers)} справ")
    return hearings


async def _datastore_search(api, query: str) -> List[dict]:
    """CKAN datastore_search по номеру справи (фільтр по полю case)."""
    import json as _json

    url = f"{DATA_GOV_UA}/api/3/action/datastore_search"
    try:
        resp = await api.get(
            url,
            params={
                "resource_id": RESOURCE_ID,
                "filters": _json.dumps({"case": query}),
                "limit": 100,
            },
        )
        data = await resp.json()
        if data.get("success"):
            return data.get("result", {}).get("records", [])
    except Exception as e:
        print(f"[hearings] datastore_search помилка для {query}: {e}")
    return []


def _split_date_time(raw: str) -> tuple[str, str]:
    """
    Розбиває значення поля date на ISO-дату (YYYY-MM-DD) та час (HH:MM).
    Підтримує кілька ймовірних форматів; уточнимо за реальними даними.
    """
    if not raw:
        return "", ""

    # ISO: 2026-08-10T10:30:00 або 2026-08-10 10:30:00
    m = re.match(r"(\d{4})-(\d{2})-(\d{2})[ T]?(\d{2})?:?(\d{2})?", raw)
    if m:
        y, mo, d, hh, mm = m.groups()
        date_iso = f"{y}-{mo}-{d}"
        time = f"{hh}:{mm}" if hh and mm else ""
        return date_iso, time

    # dd.mm.yyyy [HH:MM]
    m = re.match(r"(\d{2})\.(\d{2})\.(\d{4})(?:[ ](\d{2}):(\d{2}))?", raw)
    if m:
        d, mo, y, hh, mm = m.groups()
        date_iso = f"{y}-{mo}-{d}"
        time = f"{hh}:{mm}" if hh and mm else ""
        return date_iso, time

    return raw, ""
