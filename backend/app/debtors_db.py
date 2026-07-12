"""
Локальний SQLite-індекс «Єдиного реєстру боржників» (відкриті дані) для
пошуку за ПІБ (FTS5) або за кодом (ІПН/ЄДРПОУ).

Джерело — повний знімок (~4 ГБ CSV, cp1251), тож будуємо базу з нуля й
атомарно підмінюємо. Кожен рядок = одне виконавче провадження проти
боржника (у людини їх може бути кілька).

Колонки джерела (кома-розділені, у лапках, cp1251):
  DEBTOR_NAME, DEBTOR_BIRTHDATE, DEBTOR_CODE, PUBLISHER, ORG_NAME,
  ORG_PHONE_NUM, EMP_FULL_FIO, EMP_PHONE_NUM, EMAIL_ADDR, VP_ORDERNUM, VD_CAT
"""

import os
import sqlite3
from typing import Iterable, List

_DEFAULT_DB = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "debtors.db")
DB_PATH = os.getenv("DEBTORS_DB_PATH", _DEFAULT_DB)

# Порядок кортежу від імпортера
IN_COLS = ["debtor_name", "birthdate", "code", "publisher", "org_name",
           "executor", "vp_num", "category"]
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
            CREATE TABLE debtors (
                id INTEGER PRIMARY KEY,
                debtor_name TEXT, birthdate TEXT, code TEXT, publisher TEXT,
                org_name TEXT, executor TEXT, vp_num TEXT, category TEXT
            );
            """
        )
        cur = conn.cursor()
        batch: List[tuple] = []
        total = 0
        for r in rows:
            batch.append(r)
            if len(batch) >= 50000:
                cur.executemany(
                    "INSERT INTO debtors"
                    " (debtor_name,birthdate,code,publisher,org_name,executor,vp_num,category)"
                    " VALUES (?,?,?,?,?,?,?,?)", batch
                )
                total += len(batch)
                batch.clear()
                if total % 1_000_000 == 0:
                    print(f"[debtors] вставлено: {total:,}")
        if batch:
            cur.executemany(
                "INSERT INTO debtors"
                " (debtor_name,birthdate,code,publisher,org_name,executor,vp_num,category)"
                " VALUES (?,?,?,?,?,?,?,?)", batch
            )
            total += len(batch)
        print(f"[debtors] Усього записів: {total:,}. Будую індекси...")
        conn.executescript(
            """
            CREATE INDEX idx_code ON debtors(code);
            CREATE VIRTUAL TABLE debtors_fts USING fts5(
                debtor_name, content='debtors', content_rowid='id',
                tokenize='unicode61'
            );
            INSERT INTO debtors_fts(rowid, debtor_name)
                SELECT id, debtor_name FROM debtors;
            """
        )
        conn.commit()
    finally:
        conn.close()

    os.replace(tmp, DB_PATH)
    return total


def query_by_name(name_norm: str, limit: int = 100) -> List[dict]:
    tokens = [t for t in name_norm.split() if len(t) > 1]
    if not tokens:
        return []
    match_expr = " AND ".join('"' + t.replace('"', '') + '"' for t in tokens)
    conn = _connect(DB_PATH)
    try:
        cur = conn.execute(
            f"SELECT {','.join(OUT_COLS)} FROM debtors"
            " WHERE id IN (SELECT rowid FROM debtors_fts WHERE debtors_fts MATCH ?)"
            " LIMIT ?",
            (match_expr, limit),
        )
        return [dict(r) for r in cur.fetchall()]
    finally:
        conn.close()


def query_by_code(code: str, limit: int = 100) -> List[dict]:
    c = (code or "").strip()
    if not c:
        return []
    conn = _connect(DB_PATH)
    try:
        cur = conn.execute(
            f"SELECT {','.join(OUT_COLS)} FROM debtors WHERE code = ? LIMIT ?",
            (c, limit),
        )
        return [dict(r) for r in cur.fetchall()]
    finally:
        conn.close()
