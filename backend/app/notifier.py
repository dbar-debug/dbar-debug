"""
Порівнює поточний стан "Моїх справ" (cabinet.court.gov.ua) зі знімком,
збереженим після попередньої перевірки, і повертає список текстових
повідомлень про зміни (нова справа, зміна статусу, зміна судді).
"""

import json
import os
from pathlib import Path
from typing import Dict, List

from app.cabinet_auth import get_session
from app.cabinet_scraper import get_my_cases
from app.models import CourtCase

SNAPSHOT_FILE = Path("data/cases_snapshot.json")
SNAPSHOT_FILE.parent.mkdir(exist_ok=True)


def _tracked_fields(case: CourtCase) -> dict:
    return {
        "status": case.status,
        "judge": case.judge,
        "updated_at": case.updated_at,
        "court_name": case.court_name,
    }


def _load_snapshot() -> Dict[str, dict]:
    if not SNAPSHOT_FILE.exists():
        return {}
    try:
        return json.loads(SNAPSHOT_FILE.read_text())
    except Exception:
        return {}


def _save_snapshot(snapshot: Dict[str, dict]):
    SNAPSHOT_FILE.write_text(json.dumps(snapshot, ensure_ascii=False, indent=2))


def diff_cases(previous: Dict[str, dict], cases: List[CourtCase]) -> List[str]:
    """
    Повертає повідомлення про зміни відносно `previous`. Якщо `previous`
    порожній (перша перевірка — знімка ще не було), повідомлення не
    генеруються, щоб не "засипати" сповіщеннями про вже наявні справи.
    """
    is_first_run = not previous
    messages: List[str] = []

    for case in cases:
        current = _tracked_fields(case)
        prev = previous.get(case.case_number)

        if prev is None:
            if not is_first_run:
                messages.append(
                    f"🆕 Нова справа {case.case_number}\n"
                    f"{case.court_name}\n"
                    f"Статус: {case.status}\n"
                    f"{case.url}"
                )
            continue

        changes = []
        if prev.get("status") != current["status"]:
            changes.append(f"Статус: {prev.get('status', '—')} → {current['status']}")
        if prev.get("judge") != current["judge"]:
            changes.append(f"Суддя: {prev.get('judge', '—')} → {current['judge']}")
        if prev.get("updated_at") != current["updated_at"]:
            changes.append(f"Оновлено: {current['updated_at']}")

        if changes:
            messages.append(
                f"⚖️ Справа {case.case_number}\n" + "\n".join(changes) + f"\n{case.url}"
            )

    return messages


async def check_for_updates() -> List[str]:
    """Опитує cabinet.court.gov.ua, порівнює зі знімком і оновлює його на диску."""
    kep_file = os.getenv("KEP_FILE_PATH", "")
    password = os.getenv("KEP_PASSWORD", "")
    if not kep_file or not password:
        raise RuntimeError("Встановіть KEP_FILE_PATH та KEP_PASSWORD у .env")

    session = await get_session(kep_file, password)
    result = await get_my_cases(session)

    previous = _load_snapshot()
    messages = diff_cases(previous, result.cases)

    _save_snapshot({c.case_number: _tracked_fields(c) for c in result.cases})

    return messages
