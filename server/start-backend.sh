#!/usr/bin/env bash
#
# Запуск бекенду Court App. Використовується як systemd-сервісом, так і
# напряму / через wsl.conf. Ідемпотентний: якщо порт 8000 вже зайнятий
# нашим процесом — нічого не робить.
#
# За потреби змініть шлях BACKEND_DIR під свій.

set -euo pipefail

# Абсолютний шлях до папки backend (підправте, якщо інший)
BACKEND_DIR="${BACKEND_DIR:-$HOME/court-app/backend}"
# Лише localhost: назовні бекенд доступний тільки через nginx (ліміти, лог
# без персональних даних). 0.0.0.0 відкрив би :8000 напряму в обхід nginx.
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8000}"

cd "$BACKEND_DIR"

# Додаємо ~/.local/bin у PATH (там uvicorn після pip install --user)
export PATH="$HOME/.local/bin:$PATH"

# Якщо є .env — uvicorn підхопить через --env-file
ENV_ARG=""
if [ -f "$BACKEND_DIR/.env" ]; then
    ENV_ARG="--env-file $BACKEND_DIR/.env"
fi

echo "[start-backend] Запускаю uvicorn на $HOST:$PORT (dir=$BACKEND_DIR)"
# --no-access-log: access-лог uvicorn пише query string (ПІБ, РНОКПП, токен)
exec python3 -m uvicorn app.main:app --host "$HOST" --port "$PORT" --no-access-log $ENV_ARG
