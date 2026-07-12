"""
Локальний SQLite-індекс рішень ЄДРСР (за 2026 рік) для пошуку рішень
ЗА НОМЕРОМ СПРАВИ (у наборі немає сторін/ПІБ, лише номер справи, суддя,
дати й посилання на текст).

Текст рішення відкривається за doc_id:
    https://reyestr.court.gov.ua/Review/<doc_id>
(або doc_url, якщо він заповнений).

Довідники (суд, форма рішення, вид судочинства, категорія) розшифровуємо
під час імпорту й зберігаємо назви прямо в рядку.
"""

import os
import sqlite3
from typing import Iterable, List

_DEFAULT_DB = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "decisions.db")
DB_PATH = os.getenv("DECISIONS_DB_PATH", _DEFAULT_DB)

REVIEW_URL = "https://reyestr.court.gov.ua/Review/"

# Порядок кортежу від імпортера (вже з розшифрованими назвами)
IN_COLS = ["doc_id", "cause_num", "court_name", "judgment_form", "justice_kind",
           "category", "adjudication_date", "judge", "doc_url", "status"]


def available() -> bool:
    return os.path.exists(DB_PATH) and os.path.getsize(DB_PATH) > 0


def _connect(path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(path, timeout=60)
    conn.row_factory = sqlite3.Row
    return conn


def build(rows: Iterable[tuple]) -> int:
    """Будує базу з нуля (атомарна підміна). rows — кортежі у порядку IN_COLS."""
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
            CREATE TABLE decisions (
                id INTEGER PRIMARY KEY,
                doc_id TEXT, cause_num TEXT, court_name TEXT, judgment_form TEXT,
                justice_kind TEXT, category TEXT, adjudication_date TEXT,
                judge TEXT, doc_url TEXT, status TEXT
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
                    "INSERT INTO decisions"
                    " (doc_id,cause_num,court_name,judgment_form,justice_kind,category,"
                    "  adjudication_date,judge,doc_url,status)"
                    " VALUES (?,?,?,?,?,?,?,?,?,?)", batch
                )
                total += len(batch)
                batch.clear()
                if total % 1_000_000 == 0:
                    print(f"[decisions] вставлено: {total:,}")
        if batch:
            cur.executemany(
                "INSERT INTO decisions"
                " (doc_id,cause_num,court_name,judgment_form,justice_kind,category,"
                "  adjudication_date,judge,doc_url,status)"
                " VALUES (?,?,?,?,?,?,?,?,?,?)", batch
            )
            total += len(batch)
        print(f"[decisions] Усього рішень: {total:,}. Будую індекс...")
        conn.execute("CREATE INDEX idx_cause ON decisions(cause_num)")
        conn.commit()
    finally:
        conn.close()

    os.replace(tmp, DB_PATH)
    return total


def query_by_case(cause_num: str) -> List[dict]:
    """Рішення за номером справи. Найновіші зверху; додаємо посилання на текст."""
    num = (cause_num or "").strip()
    if not num:
        return []
    conn = _connect(DB_PATH)
    try:
        cur = conn.execute(
            "SELECT doc_id, cause_num, court_name, judgment_form, justice_kind,"
            "       category, adjudication_date, judge, doc_url, status"
            " FROM decisions WHERE cause_num = ?"
            " ORDER BY adjudication_date DESC",
            (num,),
        )
        out = []
        for r in cur.fetchall():
            d = dict(r)
            doc_id = d.get("doc_id") or ""
            # HTML-сторінка рішення (для перегляду) + пряме .rtf (для збереження)
            d["review_url"] = (REVIEW_URL + doc_id) if doc_id else (d.get("doc_url") or "")
            d["file_url"] = d.get("doc_url") or ""
            out.append(d)
        return out
    finally:
        conn.close()
