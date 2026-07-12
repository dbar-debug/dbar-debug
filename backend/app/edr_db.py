"""
Локальний SQLite-індекс Єдиного державного реєстру юросіб, ФОП та
громадських формувань (data.gov.ua, набір a1799820-...). Пошук за:
  • ПІБ / найменуванням (FTS5, unicode61);
  • кодом ЄДРПОУ (звичайний індекс) — щоб звʼязати бізнес із боргами.

Схема універсальна для обох типів записів:
  • ФОП (kind='ФОП') — name=ПІБ, коду немає;
  • ЮО  (kind='ЮО')  — name=найменування, code=ЄДРПОУ; окремими рядками
    додаються керівники/засновники (role), щоб людину було видно за ПІБ.

Набір — повний тижневий знімок, тож базу будуємо з нуля й атомарно
підмінюємо (як debtors_db).
"""

import os
import sqlite3
from typing import Iterable, List

_DEFAULT_DB = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "edr.db")
DB_PATH = os.getenv("EDR_DB_PATH", _DEFAULT_DB)

# Уніфікований порядок полів (обидва типи мапляться на нього)
IN_COLS = ["kind", "name", "code", "stan", "reg_date", "role", "org_name", "extra"]
OUT_COLS = IN_COLS


def available() -> bool:
    return os.path.exists(DB_PATH) and os.path.getsize(DB_PATH) > 0


def _connect(path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(path, timeout=60)
    conn.row_factory = sqlite3.Row
    return conn


def build(rows: Iterable[tuple]) -> int:
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
            PRAGMA temp_store = FILE;
            PRAGMA cache_size = -200000;
            CREATE TABLE edr (
                id INTEGER PRIMARY KEY, kind TEXT,
                name TEXT, code TEXT, stan TEXT, reg_date TEXT,
                role TEXT, org_name TEXT, extra TEXT
            );
            """
        )
        cur = conn.cursor()
        cols = ",".join(IN_COLS)
        ph = ",".join("?" for _ in IN_COLS)
        sql = f"INSERT INTO edr ({cols}) VALUES ({ph})"
        batch: List[tuple] = []
        total = 0
        for r in rows:
            batch.append(r)
            if len(batch) >= 50000:
                cur.executemany(sql, batch)
                total += len(batch)
                batch.clear()
                if total % 1_000_000 == 0:
                    print(f"[edr] вставлено: {total:,}")
        if batch:
            cur.executemany(sql, batch)
            total += len(batch)
        print(f"[edr] Усього записів: {total:,}. Будую індекси...")
        conn.executescript(
            """
            CREATE INDEX idx_edr_code ON edr(code);
            CREATE VIRTUAL TABLE edr_fts USING fts5(
                name, content='edr', content_rowid='id',
                tokenize='unicode61'
            );
            INSERT INTO edr_fts(rowid, name) SELECT id, name FROM edr;
            """
        )
        conn.commit()
    finally:
        conn.close()

    os.replace(tmp, DB_PATH)
    return total


def query_by_name(name_norm: str, limit: int = 200) -> List[dict]:
    tokens = [t for t in name_norm.split() if len(t) > 1]
    if not tokens:
        return []
    match_expr = " AND ".join('"' + t.replace('"', '') + '"' for t in tokens)
    conn = _connect(DB_PATH)
    try:
        cur = conn.execute(
            f"SELECT {','.join(OUT_COLS)} FROM edr"
            " WHERE id IN (SELECT rowid FROM edr_fts WHERE edr_fts MATCH ?)"
            " LIMIT ?",
            (match_expr, limit),
        )
        return [dict(r) for r in cur.fetchall()]
    finally:
        conn.close()


def query_by_code(code: str, limit: int = 200) -> List[dict]:
    c = (code or "").strip()
    if not c:
        return []
    conn = _connect(DB_PATH)
    try:
        cur = conn.execute(
            f"SELECT {','.join(OUT_COLS)} FROM edr WHERE code = ? LIMIT ?",
            (c, limit),
        )
        return [dict(r) for r in cur.fetchall()]
    finally:
        conn.close()
