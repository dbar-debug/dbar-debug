"""
Локальний SQLite-індекс «Стану розгляду справ» (відкриті дані) для
швидкого пошуку за ПІБ (FTS5).

Джерело — денні зрізи (~710 МБ zip, ~1.25 млн стадій за день). Один день
не містить усіх справ, тож база НАКОПИЧУЄ дані: кожен запуск додає нові
справи й оновлює наявні до найсвіжішої стадії (merge). Бекфілу немає —
покриття зростає лише вперед.

Таблиці:
  cases     — одна справа = один рядок (поточна стадія + найповніші сторони);
              UNIQUE(court_name, case_number).
  cases_fts — FTS5 по сторонах (пошук за ПІБ).
"""

import os
import re
import sqlite3
from typing import Iterable, List

_DEFAULT_DB = os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "status.db")
DB_PATH = os.getenv("STATUS_DB_PATH", _DEFAULT_DB)

# Порядок полів у кортежі, який подає імпортер (сирі рядки)
IN_COLS = ["court_name", "case_number", "case_proc", "registration_date",
           "judge", "judges", "participants", "stage_date", "stage_name",
           "cause_result", "description"]

# Поля, що віддаємо клієнту
OUT_COLS = IN_COLS


def available() -> bool:
    return os.path.exists(DB_PATH) and os.path.getsize(DB_PATH) > 0


def _connect(path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(path, timeout=60)
    conn.row_factory = sqlite3.Row
    return conn


def _date_iso(s: str) -> str:
    """'11.07.2026' -> '2026-07-11' (для сортування останньої стадії)."""
    m = re.match(r"\s*(\d{2})\.(\d{2})\.(\d{4})", s or "")
    return f"{m.group(3)}-{m.group(2)}-{m.group(1)}" if m else ""


def _ensure_schema(conn: sqlite3.Connection) -> None:
    conn.executescript(
        """
        CREATE TABLE IF NOT EXISTS cases (
            id INTEGER PRIMARY KEY,
            court_name TEXT, case_number TEXT, case_proc TEXT,
            registration_date TEXT, judge TEXT, judges TEXT,
            participants TEXT, stage_date TEXT, stage_date_iso TEXT,
            stage_name TEXT, cause_result TEXT, description TEXT
        );
        CREATE UNIQUE INDEX IF NOT EXISTS idx_case_uni
            ON cases(court_name, case_number);
        CREATE VIRTUAL TABLE IF NOT EXISTS cases_fts USING fts5(
            participants, content='cases', content_rowid='id',
            tokenize='unicode61'
        );
        """
    )


def merge(rows: Iterable[tuple]) -> int:
    """
    Додає денний зріз у накопичувальну базу: нові справи вставляє, наявні
    оновлює до найсвіжішої стадії, сторони лишає найповніші. Повертає
    загальну кількість справ у базі після злиття.
    """
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = _connect(DB_PATH)
    try:
        conn.executescript(
            "PRAGMA journal_mode = WAL;"
            "PRAGMA synchronous = NORMAL;"
            "PRAGMA temp_store = FILE;"
            "PRAGMA cache_size = -200000;"
        )
        _ensure_schema(conn)

        # Денні рядки — у тимчасову таблицю
        conn.executescript(
            """
            DROP TABLE IF EXISTS incoming;
            CREATE TEMP TABLE incoming (
                court_name TEXT, case_number TEXT, case_proc TEXT,
                registration_date TEXT, judge TEXT, judges TEXT,
                participants TEXT, stage_date TEXT, stage_date_iso TEXT,
                stage_name TEXT, cause_result TEXT, description TEXT
            );
            """
        )
        cur = conn.cursor()
        batch: List[tuple] = []
        total = 0
        for r in rows:
            iso = _date_iso(r[7])
            batch.append((r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], iso, r[8], r[9], r[10]))
            if len(batch) >= 50000:
                cur.executemany("INSERT INTO incoming VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", batch)
                total += len(batch)
                batch.clear()
        if batch:
            cur.executemany("INSERT INTO incoming VALUES (?,?,?,?,?,?,?,?,?,?,?,?)", batch)
            total += len(batch)
        print(f"[status] Денних рядків стадій: {total:,}. Згортаю й зливаю...")

        # Згортаємо денний зріз до однієї справи (остання стадія + найповніші сторони)
        conn.executescript(
            """
            DROP TABLE IF EXISTS day_cases;
            CREATE TEMP TABLE day_cases AS
            WITH latest AS (
                SELECT *, ROW_NUMBER() OVER (
                    PARTITION BY court_name, case_number
                    ORDER BY stage_date_iso DESC, rowid DESC
                ) AS rn
                FROM incoming
            ),
            parts AS (
                SELECT court_name, case_number, participants, ROW_NUMBER() OVER (
                    PARTITION BY court_name, case_number
                    ORDER BY length(participants) DESC
                ) AS pn
                FROM incoming
                WHERE participants IS NOT NULL AND trim(participants) <> ''
            )
            SELECT l.court_name, l.case_number, l.case_proc, l.registration_date,
                   l.judge, l.judges,
                   COALESCE(p.participants, l.participants, '') AS participants,
                   l.stage_date, l.stage_date_iso, l.stage_name, l.cause_result, l.description
            FROM latest l
            LEFT JOIN (SELECT * FROM parts WHERE pn = 1) p
                ON p.court_name = l.court_name AND p.case_number = l.case_number
            WHERE l.rn = 1;
            """
        )

        with conn:  # транзакція
            # 1) Нові справи
            conn.execute(
                """
                INSERT OR IGNORE INTO cases
                    (court_name, case_number, case_proc, registration_date, judge, judges,
                     participants, stage_date, stage_date_iso, stage_name, cause_result, description)
                SELECT court_name, case_number, case_proc, registration_date, judge, judges,
                       participants, stage_date, stage_date_iso, stage_name, cause_result, description
                FROM day_cases;
                """
            )
            # 2) Оновлюємо наявні до новішої стадії
            conn.execute(
                """
                UPDATE cases SET
                    case_proc = d.case_proc,
                    registration_date = d.registration_date,
                    judge = d.judge, judges = d.judges,
                    stage_date = d.stage_date, stage_date_iso = d.stage_date_iso,
                    stage_name = d.stage_name, cause_result = d.cause_result,
                    description = d.description
                FROM day_cases d
                WHERE cases.court_name = d.court_name AND cases.case_number = d.case_number
                  AND d.stage_date_iso > cases.stage_date_iso;
                """
            )
            # 3) Лишаємо найповніші сторони
            conn.execute(
                """
                UPDATE cases SET participants = d.participants
                FROM day_cases d
                WHERE cases.court_name = d.court_name AND cases.case_number = d.case_number
                  AND length(d.participants) > length(cases.participants);
                """
            )
            # 4) Перебудовуємо FTS з актуального вмісту
            conn.execute("INSERT INTO cases_fts(cases_fts) VALUES('rebuild')")

        count = conn.execute("SELECT COUNT(*) FROM cases").fetchone()[0]
        conn.execute("PRAGMA wal_checkpoint(TRUNCATE)")
        return count
    finally:
        conn.close()


def query_by_name(name_norm: str, limit: int = 100) -> List[dict]:
    """Пошук справ, де ПІБ фігурує серед сторін (FTS5). Найновіші зверху."""
    tokens = [t for t in name_norm.split() if len(t) > 1]
    if not tokens:
        return []
    match_expr = " AND ".join('"' + t.replace('"', '') + '"' for t in tokens)

    conn = _connect(DB_PATH)
    try:
        cur = conn.execute(
            f"SELECT {','.join(OUT_COLS)} FROM cases"
            " WHERE id IN (SELECT rowid FROM cases_fts WHERE cases_fts MATCH ?)"
            " ORDER BY stage_date_iso DESC LIMIT ?",
            (match_expr, limit),
        )
        return [dict(r) for r in cur.fetchall()]
    finally:
        conn.close()
