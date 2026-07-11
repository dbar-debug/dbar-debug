# Веб-додаток через Nginx (Варіант 1)

Мета: відкривати додаток у браузері телефону за `http://100.77.97.16`
(через Tailscale), не тримаючи `flutter run` запущеним.

Nginx роздає зібраний Flutter web з `/var/www/court-app`, а API проксіює
на бекенд — усе на одній адресі.

## Крок 1. Зібрати веб (на Windows, у папці mobile)

PowerShell, у `C:\dev\court-app\mobile`:
```powershell
flutter build web
```
Результат: `C:\dev\court-app\mobile\build\web` (WSL бачить це як
`/mnt/c/dev/court-app/mobile/build/web`).

## Крок 2. Розгорнути у /var/www (у WSL)

Nginx-користувач `www-data` НЕ має доступу до `/home/...` і до `/mnt/c`
(звідти 403/500). Тому копіюємо build у `/var/www/court-app` скриптом:

```bash
cd ~/court-app && git pull
chmod +x ~/court-app/server/deploy-web.sh
~/court-app/server/deploy-web.sh        # копіює build + виставляє права + перевіряє
```

Скрипт наприкінці виведе `HTTP 200` — значить усе гаразд.

## Крок 3. Оновити конфіг Nginx (один раз)

```bash
sudo cp ~/court-app/server/nginx-court-app.conf /etc/nginx/sites-available/court-app
sudo nginx -t && sudo systemctl reload nginx
curl -s -o /dev/null -w "%{http_code}\n" http://localhost/     # 200
```

## Крок 4. Відкрити та налаштувати

1. Браузер (ПК або телефон з Tailscale): `http://100.77.97.16/`
2. Вкладка **Налаштування** → адреса сервера: `http://100.77.97.16` → Зберегти
3. Вкладка **Мої справи** — має підтягнути справи

## Оновлення додатку надалі

Після змін у коді додатку:
```powershell
flutter build web                       # Windows, mobile/
```
```bash
~/court-app/server/deploy-web.sh        # WSL — розгорнути нову версію
```
Іноді браузер кешує — оновіть із Ctrl+Shift+R.
