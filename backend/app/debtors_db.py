"""
Локальний SQLite-індекс боргів/виконавчих проваджень за ПІБ (FTS5) або
кодом. Обʼєднує ДВА відкриті набори (союз рядків, кожен з позначкою source):

  • ЄРБ  — Єдиний реєстр боржників (ширший, приватні борги; поле «категорія»);
  • АСВП — Автоматизована система виконавчого провадження (стягувач,
           статус, дата відкриття; переважно держпровадження).

Обидва — повні знімки, тож базу будуємо з нуля й атомарно підмінюємо.
"""

import os
import sqlite3
from typing import Iterable, List

_DEFAULT_DB = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "debtors.db")
DB_PATH = os.getenv("DEBTORS_DB_PATH", _DEFAULT_DB)

# Уніфікований порядок полів (обидва джерела мапляться на нього)
IN_COLS = ["source", "debtor_name", "birthdate", "code", "creditor_name",
           "category", "vp_num", "vp_begindate", "vp_state", "org_name", "executor"]
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
                id INTEGER PRIMARY KEY, source TEXT,
                debtor_name TEXT, birthdate TEXT, code TEXT, creditor_name TEXT,
                category TEXT, vp_num TEXT, vp_begindate TEXT, vp_state TEXT,
                org_name TEXT, executor TEXT
            );
            """
        )
        cur = conn.cursor()
        cols = ",".join(c for c in IN_COLS)
        ph = ",".join("?" for _ in IN_COLS)
        sql = f"INSERT INTO debtors ({cols}) VALUES ({ph})"
        batch: List[tuple] = []
        total = 0
        for r in rows:
            batch.append(r)
            if len(batch) >= 50000:
                cur.executemany(sql, batch)
                total += len(batch)
                batch.clear()
                if total % 1_000_000 == 0:
                    print(f"[debtors] вставлено: {total:,}")
        if batch:
            cur.executemany(sql, batch)
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


def query_by_name(name_norm: str, limit: int = 200) -> List[dict]:
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


def query_by_code(code: str, limit: int = 200) -> List[dict]:
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
