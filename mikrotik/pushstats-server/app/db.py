"""SQLite-сховище PushStats: роутери, часові ряди метрик, стан алертів."""

import json
import os
import sqlite3
import threading
import time

DB_PATH = os.environ.get("PUSHSTATS_DB", "pushstats.db")
KEEP_DAYS = int(os.environ.get("PUSHSTATS_KEEP_DAYS", "14"))

_lock = threading.Lock()
_conn: sqlite3.Connection | None = None


def conn() -> sqlite3.Connection:
    global _conn
    if _conn is None:
        _conn = sqlite3.connect(DB_PATH, check_same_thread=False)
        _conn.row_factory = sqlite3.Row
        _init(_conn)
    return _conn


def _init(c: sqlite3.Connection) -> None:
    c.executescript(
        """
        CREATE TABLE IF NOT EXISTS routers (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          token TEXT NOT NULL,
          did TEXT NOT NULL,
          identity TEXT, model TEXT, version TEXT, uptime TEXT,
          last_seen REAL,
          UNIQUE(token, did)
        );
        CREATE TABLE IF NOT EXISTS samples (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          router_id INTEGER NOT NULL,
          ts REAL NOT NULL,
          cpu_load REAL, mem_free REAL, mem_total REAL,
          hdd_free REAL, hdd_total REAL,
          agg_tx REAL, agg_rx REAL,
          counts TEXT, health TEXT
        );
        CREATE INDEX IF NOT EXISTS idx_samples_router_ts
          ON samples(router_id, ts);
        CREATE TABLE IF NOT EXISTS alert_state (
          router_id INTEGER NOT NULL,
          metric TEXT NOT NULL,
          active INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY (router_id, metric)
        );
        """
    )
    c.commit()


def upsert_router(token: str, did: str, identity: str, model: str,
                  version: str, uptime: str) -> int:
    with _lock:
        c = conn()
        c.execute(
            """
            INSERT INTO routers (token, did, identity, model, version,
                                 uptime, last_seen)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(token, did) DO UPDATE SET
              identity=excluded.identity, model=excluded.model,
              version=excluded.version, uptime=excluded.uptime,
              last_seen=excluded.last_seen
            """,
            (token, did, identity, model, version, uptime, time.time()),
        )
        c.commit()
        row = c.execute(
            "SELECT id FROM routers WHERE token=? AND did=?", (token, did)
        ).fetchone()
        return int(row["id"])


def insert_sample(router_id: int, fields: dict) -> None:
    with _lock:
        c = conn()
        c.execute(
            """
            INSERT INTO samples (router_id, ts, cpu_load, mem_free,
              mem_total, hdd_free, hdd_total, agg_tx, agg_rx, counts, health)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                router_id, time.time(),
                fields.get("cpu_load"), fields.get("mem_free"),
                fields.get("mem_total"), fields.get("hdd_free"),
                fields.get("hdd_total"), fields.get("agg_tx"),
                fields.get("agg_rx"),
                json.dumps(fields.get("counts", {})),
                fields.get("health", ""),
            ),
        )
        # чистка старих зразків (недорога — раз на вставку)
        c.execute(
            "DELETE FROM samples WHERE ts < ?",
            (time.time() - KEEP_DAYS * 86400,),
        )
        c.commit()


def _used_pct(free, total) -> float | None:
    if free is None or total in (None, 0):
        return None
    return round((total - free) / total * 100, 1)


def list_routers(token: str, online_minutes: int) -> list[dict]:
    with _lock:
        c = conn()
        routers = c.execute(
            "SELECT * FROM routers WHERE token=? ORDER BY identity", (token,)
        ).fetchall()
        out = []
        for r in routers:
            s = c.execute(
                "SELECT * FROM samples WHERE router_id=? "
                "ORDER BY ts DESC LIMIT 1",
                (r["id"],),
            ).fetchone()
            item = {
                "id": r["id"],
                "did": r["did"],
                "identity": r["identity"],
                "model": r["model"],
                "version": r["version"],
                "uptime": r["uptime"],
                "last_seen": r["last_seen"],
                "online": bool(
                    r["last_seen"]
                    and time.time() - r["last_seen"] < online_minutes * 60
                ),
            }
            if s:
                item.update({
                    "cpu_load": s["cpu_load"],
                    "mem_used_pct": _used_pct(s["mem_free"], s["mem_total"]),
                    "disk_used_pct": _used_pct(s["hdd_free"], s["hdd_total"]),
                    "agg_tx": s["agg_tx"],
                    "agg_rx": s["agg_rx"],
                    "counts": json.loads(s["counts"] or "{}"),
                    "health": s["health"],
                })
            out.append(item)
        return out


def history(token: str, router_id: int, hours: int) -> dict | None:
    with _lock:
        c = conn()
        r = c.execute(
            "SELECT id FROM routers WHERE token=? AND id=?",
            (token, router_id),
        ).fetchone()
        if r is None:
            return None
        rows = c.execute(
            "SELECT * FROM samples WHERE router_id=? AND ts>=? ORDER BY ts",
            (router_id, time.time() - hours * 3600),
        ).fetchall()
        return {
            "ts": [row["ts"] for row in rows],
            "cpu": [row["cpu_load"] or 0 for row in rows],
            "mem_pct": [
                _used_pct(row["mem_free"], row["mem_total"]) or 0
                for row in rows
            ],
            "disk_pct": [
                _used_pct(row["hdd_free"], row["hdd_total"]) or 0
                for row in rows
            ],
            "tx_mbps": [round((row["agg_tx"] or 0) / 1e6, 3) for row in rows],
            "rx_mbps": [round((row["agg_rx"] or 0) / 1e6, 3) for row in rows],
        }


def all_routers() -> list[dict]:
    with _lock:
        c = conn()
        return [dict(r) for r in c.execute("SELECT * FROM routers")]


def get_alert_active(router_id: int, metric: str) -> bool:
    with _lock:
        row = conn().execute(
            "SELECT active FROM alert_state WHERE router_id=? AND metric=?",
            (router_id, metric),
        ).fetchone()
        return bool(row and row["active"])


def set_alert_active(router_id: int, metric: str, active: bool) -> None:
    with _lock:
        c = conn()
        c.execute(
            """
            INSERT INTO alert_state (router_id, metric, active)
            VALUES (?, ?, ?)
            ON CONFLICT(router_id, metric) DO UPDATE SET active=excluded.active
            """,
            (router_id, metric, int(active)),
        )
        c.commit()
