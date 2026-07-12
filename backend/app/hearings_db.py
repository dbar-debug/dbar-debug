"""
Локальний SQLite-індекс засідань з відкритих даних для швидкого пошуку
за ПІБ (FTS5) — щоб не качати ~313 МБ CSV на кожен запит.

База будується імпортером (import_hearings.py) раз на добу й атомарно
підмінюється. Ендпоінти читають звідси за мілісекунди.

Схема:
  hearings(id, date, time, case_number, court_name, judges,
           case_involved, case_description, court_room)
  hearings_fts — FTS5 по case_involved (пошук ПІБ серед учасників).
"""

import os
import sqlite3
from typing import Iterable, List, Set

# backend/data/hearings.db (поряд з пакетом app/)
_DEFAULT_DB = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "hearings.db")
DB_PATH = os.getenv("HEARINGS_DB_PATH", _DEFAULT_DB)

_COLS = ["date", "time", "case_number", "court_name", "judges",
         "case_involved", "case_description", "court_room"]


def available() -> bool:
    """Чи існує готова база (для вибору DB-шляху замість стрімінгу CSV)."""
    return os.path.exists(DB_PATH) and os.path.getsize(DB_PATH) > 0


def _connect(path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    return conn


def build(rows: Iterable[dict]) -> int:
    """
    Будує базу з нуля у тимчасовий файл і атомарно підмінює DB_PATH.
    Дедуплікує за (номер справи, дата, час). Повертає кількість записів.
    """
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    tmp = DB_PATH + ".tmp"
    if os.path.exists(tmp):
        os.remove(tmp)

    conn = _connect(tmp)
    try:
        conn.executescript(
            """
            PRAGMA journal_mode = OFF;
            PRAGMA synchronous = OFF;
            CREATE TABLE hearings (
                id INTEGER PRIMARY KEY,
                date TEXT, time TEXT, case_number TEXT,
                court_name TEXT, judges TEXT, case_involved TEXT,
                case_description TEXT, court_room TEXT
            );
            CREATE INDEX idx_case ON hearings(case_number);
            CREATE VIRTUAL TABLE hearings_fts USING fts5(
                case_involved, content='hearings', content_rowid='id',
                tokenize='unicode61'
            );
            """
        )

        seen: Set[tuple] = set()
        count = 0
        cur = conn.cursor()
        for h in rows:
            key = (h["case_number"], h["date"], h["time"])
            if key in seen:
                continue
            seen.add(key)
            cur.execute(
                "INSERT INTO hearings"
                " (date,time,case_number,court_name,judges,case_involved,case_description,court_room)"
                " VALUES (?,?,?,?,?,?,?,?)",
                tuple(h[c] for c in _COLS),
            )
            count += 1

        # Наповнюємо FTS з основної таблиці
        conn.execute(
            "INSERT INTO hearings_fts(rowid, case_involved)"
            " SELECT id, case_involved FROM hearings"
        )
        conn.commit()
    finally:
        conn.close()

    os.replace(tmp, DB_PATH)  # атомарна підміна
    return count


def query_by_name(name_norm: str) -> List[dict]:
    """Пошук засідань, де ПІБ фігурує серед учасників (FTS5)."""
    tokens = [t for t in name_norm.split() if len(t) > 1]
    if not tokens:
        return []
    # Кожен токен у лапках (щоб не сплутати з операторами FTS), зʼєднані AND
    match_expr = " AND ".join('"' + t.replace('"', '') + '"' for t in tokens)

    conn = _connect(DB_PATH)
    try:
        cur = conn.execute(
            f"SELECT {','.join(_COLS)} FROM hearings"
            " WHERE id IN (SELECT rowid FROM hearings_fts WHERE hearings_fts MATCH ?)"
            " ORDER BY date, time",
            (match_expr,),
        )
        return [dict(r) for r in cur.fetchall()]
    finally:
        conn.close()


def query_by_cases(numbers: Set[str]) -> List[dict]:
    """Пошук засідань за набором номерів справ."""
    nums = [n for n in numbers if n]
    if not nums:
        return []
    placeholders = ",".join("?" for _ in nums)
    conn = _connect(DB_PATH)
    try:
        cur = conn.execute(
            f"SELECT {','.join(_COLS)} FROM hearings"
            f" WHERE case_number IN ({placeholders})"
            " ORDER BY date, time",
            nums,
        )
        return [dict(r) for r in cur.fetchall()]
    finally:
        conn.close()
