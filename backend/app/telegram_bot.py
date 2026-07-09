"""
Telegram-бот для сповіщень про зміни у "Моїх справах" cabinet.court.gov.ua.

Команди:
  /start — підписатися на сповіщення
  /stop  — відписатися
  /cases — показати поточний список справ і статуси
  /check — перевірити зміни негайно (не чекаючи розкладу)
"""

import json
import os
from pathlib import Path
from typing import Set

from telegram import Update
from telegram.ext import Application, CommandHandler, ContextTypes

from app.cabinet_auth import get_session
from app.cabinet_scraper import get_my_cases
from app.notifier import check_for_updates

SUBSCRIBERS_FILE = Path("data/telegram_subscribers.json")
SUBSCRIBERS_FILE.parent.mkdir(exist_ok=True)

POLL_MINUTES = int(os.getenv("NOTIFIER_POLL_MINUTES", "30"))


def _load_subscribers() -> Set[int]:
    if not SUBSCRIBERS_FILE.exists():
        return set()
    try:
        return set(json.loads(SUBSCRIBERS_FILE.read_text()))
    except Exception:
        return set()


def _save_subscribers(subscribers: Set[int]):
    SUBSCRIBERS_FILE.write_text(json.dumps(sorted(subscribers)))


async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    subscribers = _load_subscribers()
    subscribers.add(update.effective_chat.id)
    _save_subscribers(subscribers)
    await update.message.reply_text(
        "Підписано! Надсилатиму сповіщення про зміни у ваших справах "
        f"(перевірка кожні {POLL_MINUTES} хв).\n"
        "/stop — відписатися\n"
        "/cases — поточний список справ\n"
        "/check — перевірити зараз"
    )


async def stop(update: Update, context: ContextTypes.DEFAULT_TYPE):
    subscribers = _load_subscribers()
    subscribers.discard(update.effective_chat.id)
    _save_subscribers(subscribers)
    await update.message.reply_text("Відписано від сповіщень.")


async def cases(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("Завантажую список справ...")
    try:
        kep_file = os.getenv("KEP_FILE_PATH", "")
        password = os.getenv("KEP_PASSWORD", "")
        session = await get_session(kep_file, password)
        result = await get_my_cases(session)
    except Exception as e:
        await update.message.reply_text(f"Помилка: {e}")
        return

    if not result.cases:
        await update.message.reply_text("Справ не знайдено.")
        return

    for c in result.cases:
        await update.message.reply_text(
            f"⚖️ {c.case_number} — {c.status}\n{c.court_name}\n{c.url}"
        )


async def check_now(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text("Перевіряю зміни...")
    try:
        messages = await check_for_updates()
    except Exception as e:
        await update.message.reply_text(f"Помилка: {e}")
        return

    if not messages:
        await update.message.reply_text("Змін не знайдено.")
        return

    for msg in messages:
        await update.message.reply_text(msg)


async def poll_job(context: ContextTypes.DEFAULT_TYPE):
    subscribers = _load_subscribers()
    if not subscribers:
        return
    try:
        messages = await check_for_updates()
    except Exception as e:
        print(f"[notifier] Помилка перевірки: {e}")
        return
    for chat_id in subscribers:
        for msg in messages:
            await context.bot.send_message(chat_id=chat_id, text=msg)


def main():
    token = os.getenv("TELEGRAM_BOT_TOKEN")
    if not token:
        raise RuntimeError("Встановіть TELEGRAM_BOT_TOKEN у .env")

    app = Application.builder().token(token).build()
    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("stop", stop))
    app.add_handler(CommandHandler("cases", cases))
    app.add_handler(CommandHandler("check", check_now))

    app.job_queue.run_repeating(poll_job, interval=POLL_MINUTES * 60, first=10)

    print(f"[bot] Запущено. Опитування кожні {POLL_MINUTES} хв.")
    app.run_polling()


if __name__ == "__main__":
    main()
