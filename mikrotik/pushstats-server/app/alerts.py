"""Перевірка порогів і сповіщення.

Сповіщення надсилаються на вебхук (ALERT_WEBHOOK_URL) — це може бути
ntfy.sh, Telegram-бот через проксі або будь-який ваш приймач. Кожен алерт
надсилається один раз при перетині порога і один раз при відновленні.

APNs (нативні push на iPhone) — окрема фаза: потрібен Apple Developer
ключ; поки що push легко отримати через застосунок ntfy.
"""

import json
import logging
import os
import threading
import time
import urllib.request

from . import db

log = logging.getLogger("pushstats.alerts")

CPU_THRESHOLD = float(os.environ.get("ALERT_CPU", "90"))
MEM_THRESHOLD = float(os.environ.get("ALERT_MEM", "90"))
DISK_THRESHOLD = float(os.environ.get("ALERT_DISK", "90"))
OFFLINE_MINUTES = int(os.environ.get("ALERT_OFFLINE_MINUTES", "15"))
WEBHOOK_URL = os.environ.get("ALERT_WEBHOOK_URL", "")


def _notify(router_name: str, message: str) -> None:
    text = f"[{router_name}] {message}"
    log.warning("ALERT: %s", text)
    if not WEBHOOK_URL:
        return

    def _send() -> None:
        try:
            req = urllib.request.Request(
                WEBHOOK_URL,
                data=json.dumps(
                    {"router": router_name, "message": message},
                    ensure_ascii=False,
                ).encode(),
                headers={"Content-Type": "application/json",
                         "Title": router_name},
            )
            urllib.request.urlopen(req, timeout=10)
        except Exception as exc:  # noqa: BLE001 — алерт не має валити прийом
            log.error("Webhook failed: %s", exc)

    threading.Thread(target=_send, daemon=True).start()


def _check_threshold(router_id: int, router_name: str, metric: str,
                     value: float | None, threshold: float,
                     label: str) -> None:
    if value is None:
        return
    was_active = db.get_alert_active(router_id, metric)
    if value >= threshold and not was_active:
        db.set_alert_active(router_id, metric, True)
        _notify(router_name, f"{label}: {value:.0f}% (поріг {threshold:.0f}%)")
    elif value < threshold and was_active:
        db.set_alert_active(router_id, metric, False)
        _notify(router_name, f"{label} повернувся в норму: {value:.0f}%")


def check_sample(router_id: int, router_name: str, fields: dict) -> None:
    """Викликається на кожен прийнятий пуш статистики."""
    def used_pct(free_key: str, total_key: str) -> float | None:
        free, total = fields.get(free_key), fields.get(total_key)
        if free is None or not total:
            return None
        return (total - free) / total * 100

    _check_threshold(router_id, router_name, "cpu",
                     fields.get("cpu_load"), CPU_THRESHOLD, "CPU")
    _check_threshold(router_id, router_name, "mem",
                     used_pct("mem_free", "mem_total"), MEM_THRESHOLD,
                     "Пам'ять")
    _check_threshold(router_id, router_name, "disk",
                     used_pct("hdd_free", "hdd_total"), DISK_THRESHOLD,
                     "Диск")

    # роутер знову на зв'язку
    if db.get_alert_active(router_id, "offline"):
        db.set_alert_active(router_id, "offline", False)
        _notify(router_name, "Роутер знову на зв'язку")


def offline_watchdog_once() -> None:
    """Перевіряє, чи не зникли роутери зі зв'язку (запускається раз на хв)."""
    now = time.time()
    for r in db.all_routers():
        last_seen = r.get("last_seen") or 0
        offline = now - last_seen > OFFLINE_MINUTES * 60
        was_active = db.get_alert_active(r["id"], "offline")
        if offline and not was_active and last_seen:
            db.set_alert_active(r["id"], "offline", True)
            minutes = int((now - last_seen) / 60)
            _notify(r.get("identity") or r["did"],
                    f"Немає даних вже {minutes} хв — роутер офлайн?")
