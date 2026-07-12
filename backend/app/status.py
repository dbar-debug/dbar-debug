"""
Пошук стану розгляду справ за ПІБ з локального індексу (status_db).
Потребує побудованої бази (import_status.py). Без стрімінгу — набір
завеликий (~710 МБ), тож якщо бази немає, повертаємо порожньо.
"""

import asyncio
from typing import List

from app import status_db


def _normalize(s: str) -> str:
    return " ".join((s or "").lower().split())


async def get_status_for_name(full_name: str) -> List[dict]:
    name_norm = _normalize(full_name)
    if len(name_norm) < 5 or not status_db.available():
        return []
    return await asyncio.to_thread(status_db.query_by_name, name_norm)
