#!/usr/bin/env bash
#
# Оновлює IP домену court-app.duckdns.org у DuckDNS.
# Домашній IP зазвичай динамічний, тож цей скрипт треба запускати
# періодично (див. systemd timer нижче або README-https.md).
#
# Токен зберігається окремо у ~/.duckdns/token (НЕ комітиться в git).
# Отримати токен: увійдіть на https://www.duckdns.org — він угорі сторінки.

set -euo pipefail

DOMAIN="${DUCKDNS_DOMAIN:-court-app}"   # без .duckdns.org
TOKEN_FILE="${DUCKDNS_TOKEN_FILE:-$HOME/.duckdns/token}"

if [ ! -f "$TOKEN_FILE" ]; then
    echo "Помилка: немає файлу з токеном $TOKEN_FILE" >&2
    echo "Створіть його: mkdir -p ~/.duckdns && echo 'ВАШ_ТОКЕН' > ~/.duckdns/token" >&2
    exit 1
fi

TOKEN="$(tr -d '[:space:]' < "$TOKEN_FILE")"

# DuckDNS сам визначить зовнішній IP, якщо ip лишити порожнім
RESPONSE="$(curl -s "https://www.duckdns.org/update?domains=${DOMAIN}&token=${TOKEN}&ip=")"

echo "$(date '+%Y-%m-%d %H:%M:%S') DuckDNS: $RESPONSE"

if [ "$RESPONSE" != "OK" ]; then
    echo "УВАГА: DuckDNS повернув '$RESPONSE' (очікувалось OK)" >&2
    exit 1
fi
