#!/usr/bin/env bash
#
# Оновлює веб-версію додатку: копіює свіжий Flutter web-build у
# /var/www/court-app з правильними правами для Nginx.
#
# Спершу зберіть web у Windows (PowerShell, у mobile/):
#   flutter build web
# Потім у WSL:
#   ~/court-app/server/deploy-web.sh

set -euo pipefail

SRC="${WEB_BUILD_SRC:-/mnt/c/dev/court-app/mobile/build/web}"
DEST="${WEB_DEST:-/var/www/court-app}"

if [ ! -f "$SRC/index.html" ]; then
    echo "Помилка: не знайдено $SRC/index.html" >&2
    echo "Спершу зберіть веб у Windows: cd C:\\dev\\court-app\\mobile && flutter build web" >&2
    exit 1
fi

echo "[deploy-web] Копіюю $SRC -> $DEST ..."
sudo rm -rf "$DEST"
sudo mkdir -p "$DEST"
sudo cp -r "$SRC/." "$DEST/"
sudo chown -R www-data:www-data "$DEST"
sudo find "$DEST" -type d -exec chmod 755 {} \;
sudo find "$DEST" -type f -exec chmod 644 {} \;

echo "[deploy-web] Готово. Перевірка:"
curl -s -o /dev/null -w "  HTTP %{http_code}\n" http://localhost/
