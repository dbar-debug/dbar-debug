"""PushStats-сервер для MikroTik Mobile.

Приймає статистику від RouterOS-скрипта (POST /push, form-urlencoded,
надсилається роутером через /tool fetch) і віддає її додатку
(GET /api/routers, GET /api/routers/{id}/history).

Запуск: uvicorn app.main:app --host 0.0.0.0 --port 8080
"""

import asyncio
import contextlib
import logging
import os
import urllib.parse

from fastapi import FastAPI, HTTPException, Query, Request

from . import alerts, db

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("pushstats")

ONLINE_MINUTES = int(os.environ.get("PUSHSTATS_ONLINE_MINUTES", "15"))

# Лічильники клієнтів, які зберігаємо як counts.
_COUNT_KEYS = [
    "dhcp_lease_count", "wireless_reg_count", "capsman_reg_count",
    "ppp_active_count", "hotspot_active_count", "fw_connection_count",
    "user_active_count",
]


@contextlib.asynccontextmanager
async def lifespan(_: FastAPI):
    task = asyncio.create_task(_watchdog_loop())
    yield
    task.cancel()


async def _watchdog_loop() -> None:
    while True:
        try:
            await asyncio.to_thread(alerts.offline_watchdog_once)
        except Exception as exc:  # noqa: BLE001
            log.error("watchdog: %s", exc)
        await asyncio.sleep(60)


app = FastAPI(title="MikroTik Mobile PushStats", lifespan=lifespan)


def _float(value: str | None) -> float | None:
    if value is None:
        return None
    try:
        return float(value)
    except ValueError:
        return None


@app.post("/push")
async def push(request: Request) -> dict:
    # Розбираємо тіло самостійно: RouterOS fetch не завжди ставить
    # коректний Content-Type.
    body = (await request.body()).decode("utf-8", errors="replace")
    parsed = urllib.parse.parse_qs(body, keep_blank_values=True)
    data = {k: v[0] for k, v in parsed.items()}

    token = data.get("token", "").strip()
    did = data.get("did", "").strip()
    if not token or not did:
        raise HTTPException(status_code=400, detail="token і did обов'язкові")

    router_id = db.upsert_router(
        token=token,
        did=did,
        identity=data.get("identity", ""),
        model=data.get("model", ""),
        version=data.get("version", ""),
        uptime=data.get("uptime", ""),
    )

    fields = {
        "cpu_load": _float(data.get("cpu_load")),
        "mem_free": _float(data.get("mem_free")),
        "mem_total": _float(data.get("mem_total")),
        "hdd_free": _float(data.get("hdd_free")),
        "hdd_total": _float(data.get("hdd_total")),
        "agg_tx": _float(data.get("agg_tx")),
        "agg_rx": _float(data.get("agg_rx")),
        "health": data.get("health", ""),
        "counts": {
            k: _float(data.get(k)) for k in _COUNT_KEYS if data.get(k)
        },
    }
    db.insert_sample(router_id, fields)
    alerts.check_sample(router_id, data.get("identity") or did, fields)
    return {"ok": True}


@app.get("/api/routers")
def routers(token: str = Query(min_length=8)) -> list[dict]:
    return db.list_routers(token, ONLINE_MINUTES)


@app.get("/api/routers/{router_id}/history")
def router_history(
    router_id: int,
    token: str = Query(min_length=8),
    hours: int = Query(default=24, ge=1, le=24 * 14),
) -> dict:
    result = db.history(token, router_id, hours)
    if result is None:
        raise HTTPException(status_code=404, detail="Роутер не знайдено")
    return result


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}
