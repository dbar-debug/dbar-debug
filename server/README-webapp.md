# Веб-додаток через Nginx (Варіант 1)

Мета: відкривати додаток у браузері телефону за `http://100.77.97.16`
(через Tailscale), не тримаючи `flutter run` запущеним.

Nginx роздає зібраний Flutter web на `/`, а API проксіює на бекенд —
все на одній адресі.

## Крок 1. Зібрати веб (на Windows, у папці mobile)

PowerShell, у `C:\dev\court-app\mobile`:
```powershell
flutter build web
```
Результат: `C:\dev\court-app\mobile\build\web` (WSL бачить це як
`/mnt/c/dev/court-app/mobile/build/web`).

## Крок 2. Оновити Nginx (у WSL)

```bash
cd ~/court-app && git pull
sudo cp ~/court-app/server/nginx-court-app.conf /etc/nginx/sites-available/court-app
sudo nginx -t && sudo systemctl reload nginx
```

## Крок 3. Перевірити

```bash
# API все ще працює
curl -s http://localhost/health
# додаток віддається (має бути HTML з <title> або flutter bootstrap)
curl -s http://localhost/ | head -20
```

Далі відкрийте у браузері (на ПК або на телефоні з Tailscale):
```
http://100.77.97.16/
```

## Крок 4. Налаштувати адресу API в додатку

При першому відкритті: вкладка **Налаштування** → адреса сервера:
```
http://100.77.97.16
```
(зберігається в браузері; API-запити підуть на той самий хост → Nginx → бекенд)

## Оновлення додатку надалі

Після змін у коді додатку:
```powershell
flutter build web          # у Windows, mobile/
```
Nginx одразу віддаватиме нову версію (перезапускати нічого не треба).
Іноді браузер кешує — оновіть із Ctrl+Shift+R.

---

## Якщо /mnt/c не читається Nginx-ом (403/404)

Права доступу WSL до диска Windows іноді заважають www-data. Тоді
копіюйте build у WSL і роздавайте звідти:

```bash
mkdir -p ~/court-app-web
cp -r /mnt/c/dev/court-app/mobile/build/web/* ~/court-app-web/
# у nginx-court-app.conf замініть root на:
#   root /home/dbar/court-app-web;
sudo nginx -t && sudo systemctl reload nginx
```
(і повторюйте `cp` після кожного `flutter build web`)
