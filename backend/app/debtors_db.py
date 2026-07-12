"""
Локальний SQLite-індекс «Автоматизованої системи виконавчого
провадження» (АСВП, відкриті дані nais.gov.ua) для пошуку за ПІБ (FTS5)
або кодом. Замінює вужчий «Єдиний реєстр боржників»: тут є стягувач,
статус провадження і дата відкриття.

Джерело — повний знімок (~3 ГБ CSV, cp1251, кома-розділ), тож будуємо
базу з нуля й атомарно підмінюємо. Кожен рядок = одне виконавче
провадження проти боржника.

Колонки джерела (28-ex_csv_asvp.csv):
  DEBTOR_NAME, DEBTOR_BIRTHDATE, DEBTOR_CODE, CREDITOR_NAME, CREDITOR_CODE,
  VP_ORDERNUM, VP_BEGINDATE, VP_STATE, ORG_NAME, DVS_CODE, PHONE_NUM,
  EMAIL_ADDR, BANK_ACCOUNT
"""

import os
import sqlite3
from typing import Iterable, List

_DEFAULT_DB = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "debtors.db")
DB_PATH = os.getenv("DEBTORS_DB_PATH", _DEFAULT_DB)

# Порядок кортежу від імпортера
IN_COLS = ["debtor_name", "birthdate", "code", "creditor_name",
           "vp_num", "vp_begindate", "vp_state", "org_name"]
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
                debtor_name TEXT, birthdate TEXT, code TEXT, creditor_name TEXT,
                vp_num TEXT, vp_begindate TEXT, vp_state TEXT, org_name TEXT
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
                    " (debtor_name,birthdate,code,creditor_name,vp_num,vp_begindate,vp_state,org_name)"
                    " VALUES (?,?,?,?,?,?,?,?)", batch
                )
                total += len(batch)
                batch.clear()
                if total % 1_000_000 == 0:
                    print(f"[asvp] вставлено: {total:,}")
        if batch:
            cur.executemany(
                "INSERT INTO debtors"
                " (debtor_name,birthdate,code,creditor_name,vp_num,vp_begindate,vp_state,org_name)"
                " VALUES (?,?,?,?,?,?,?,?)", batch
            )
            total += len(batch)
        print(f"[asvp] Усього записів: {total:,}. Будую індекси...")
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
