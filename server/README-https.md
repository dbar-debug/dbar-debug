# HTTPS та доступ ззовні

Мета: щоб додаток працював не тільки вдома, а з будь-де —
`https://court-app.duckdns.org` → ваш домашній сервер → бекенд.

## Огляд шляху трафіку (важливо для WSL!)

```
iPhone (інтернет)
   → роутер (домашній зовнішній IP, DuckDNS)
   → проброс портів 80/443 → Windows-ПК (локальний IP, напр. 192.168.0.50)
   → netsh portproxy → WSL2 (внутрішній IP WSL)
   → Nginx :80/:443 → uvicorn :8000
```

Через подвійний NAT (роутер + WSL2) кроків більше, ніж на звичайному
сервері. Робимо по черзі й перевіряємо кожен.

---

## Крок 1. Nginx у WSL (локально)

```bash
sudo apt update && sudo apt install -y nginx

# Наш конфіг
sudo cp ~/court-app/server/nginx-court-app.conf /etc/nginx/sites-available/court-app
sudo ln -s /etc/nginx/sites-available/court-app /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default   # прибрати дефолтний сайт
sudo nginx -t && sudo systemctl restart nginx
```

Перевірка (бекенд-сервіс court-app має бути запущений):
```bash
curl -s -H "Host: court-app.duckdns.org" http://localhost/health
```
Має повернути `{"status":"ok"}` — тобто Nginx проксіює на uvicorn.

---

## Крок 2. DuckDNS — автооновлення IP

```bash
# 1. Токен (з https://www.duckdns.org, угорі сторінки)
mkdir -p ~/.duckdns
echo 'ВАШ_ТОКЕН' > ~/.duckdns/token
chmod 600 ~/.duckdns/token

# 2. Перевірити скрипт вручну
chmod +x ~/court-app/server/duckdns-update.sh
~/court-app/server/duckdns-update.sh      # має вивести "DuckDNS: OK"

# 3. Автооновлення кожні 5 хв через systemd timer
sudo cp ~/court-app/server/duckdns.service ~/court-app/server/duckdns.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now duckdns.timer
systemctl list-timers duckdns.timer --no-pager
```

Перевірка: `court-app.duckdns.org` тепер має вказувати на ваш зовнішній IP:
```bash
dig +short court-app.duckdns.org        # або: nslookup court-app.duckdns.org
curl -s https://api.ipify.org           # ваш зовнішній IP — має збігатись
```

---

## Крок 3. Проброс портів: Windows → WSL2

WSL2 має власний внутрішній IP, який **змінюється** при перезапуску WSL.
Тому робимо скрипт, який оновлює portproxy. У **PowerShell від імені
адміністратора**:

```powershell
# IP вашого WSL
$wslIp = (wsl hostname -I).Trim().Split()[0]

# Перенаправити 80 і 443 з Windows у WSL
netsh interface portproxy reset
netsh interface portproxy add v4tov4 listenport=80  listenaddress=0.0.0.0 connectport=80  connectaddress=$wslIp
netsh interface portproxy add v4tov4 listenport=443 listenaddress=0.0.0.0 connectport=443 connectaddress=$wslIp

# Дозволити у брандмауері Windows
New-NetFirewallRule -DisplayName "Court App 80"  -Direction Inbound -LocalPort 80  -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "Court App 443" -Direction Inbound -LocalPort 443 -Protocol TCP -Action Allow

netsh interface portproxy show all      # перевірити
```

> ⚠️ Оскільки WSL IP змінюється, ці `portproxy` правила треба оновлювати
> після кожного `wsl --shutdown`. Нижче — як автоматизувати.

Перевірка з самого Windows (в браузері): `http://localhost/health` через
портпроксі, або з телефону в тій же Wi-Fi мережі на локальний IP ПК.

---

## Крок 4. Проброс портів на роутері

У налаштуваннях роутера (зазвичай `192.168.0.1` або `192.168.1.1`):
- Прокиньте зовнішні порти **80** і **443** на **локальний IP вашого
  Windows-ПК** (напр. `192.168.0.50`), порти 80 і 443.
- Локальний IP ПК подивіться: `ipconfig` у Windows (IPv4 Address).
- Бажано закріпити цей IP за ПК (DHCP reservation), щоб не «плавав».

Перевірка ззовні (з мобільного інтернету, не Wi-Fi):
```
http://court-app.duckdns.org/health
```

---

## Крок 5. HTTPS-сертифікат (Let's Encrypt)

Коли порт 80 доступний ззовні (кроки 3-4 працюють):

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d court-app.duckdns.org
```

Certbot сам додасть 443-блок у конфіг і налаштує автопродовження.

**Якщо порт 80 недоступний ззовні** (напр. провайдер блокує) —
використайте DNS-01 challenge через DuckDNS (не потребує відкритого порту):
```bash
# acme.sh з DuckDNS
curl https://get.acme.sh | sh
export DuckDNS_Token="ВАШ_ТОКЕН"
~/.acme.sh/acme.sh --issue --dns dns_duckdns -d court-app.duckdns.org
# далі встановити сертифікат у Nginx (--install-cert)
```

---

## Крок 6. Автозапуск усього при старті Windows

Щоб WSL, бекенд, Nginx і portproxy піднімались без ручного втручання —
див. `README-autostart.md` (Task Scheduler для WSL). Правила portproxy
можна оновлювати тим самим завданням, додавши PowerShell-скрипт із Кроку 3.

---

## Крок 7. Переключити додаток на HTTPS

У додатку → вкладка **Налаштування** → адреса сервера:
```
https://court-app.duckdns.org
```

Після цього додаток працюватиме з будь-де.

---

## Безпека

Ви відкриваєте домашній сервер в інтернет. Мінімум:
- КЕП-файл і пароль лишаються тільки в `.env` на сервері — у трафіку їх нема.
- Розгляньте обмеження доступу до API (напр. простий токен у заголовку),
  бо зараз `/cabinet/*` доступний будь-кому, хто знає адресу. Це наступний
  крок після того, як HTTPS запрацює.
