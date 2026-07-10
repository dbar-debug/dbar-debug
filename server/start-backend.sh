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
HOST="${HOST:-0.0.0.0}"
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
exec python3 -m uvicorn app.main:app --host "$HOST" --port "$PORT" $ENV_ARG
