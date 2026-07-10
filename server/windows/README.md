# Автоматизація на боці Windows

Доступ до бекенду зовні реалізовано через **Tailscale** (приватна
зашифрована mesh-мережа), тож роутер, «білий» IP і HTTPS-сертифікат
НЕ потрібні. Лишається одна проблема: після кожного перезапуску WSL
його внутрішній IP змінюється, і проброс портів Windows→WSL
«відв'язується». `setup-portproxy.ps1` це виправляє.

## Що робить setup-portproxy.ps1

1. Піднімає WSL (через systemd автоматично стартують `court-app` і `nginx`).
2. Дізнається поточний WSL IP.
3. Переналаштовує `netsh portproxy` 80/443 → цей IP.

## Одноразове налаштування брандмауера (виконати раз)

PowerShell від адміністратора:
```powershell
New-NetFirewallRule -DisplayName "Court App 80"  -Direction Inbound -LocalPort 80  -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "Court App 443" -Direction Inbound -LocalPort 443 -Protocol TCP -Action Allow
```

## Автозапуск при вході в Windows (Task Scheduler)

1. Скопіюйте репозиторій (або хоча б `server/windows/`) у стабільне місце,
   напр. `C:\dev\court-app\`.
2. Win → «Планувальник завдань» → «Створити завдання…».
3. Вкладка **Загальні**: імʼя `Court App portproxy`; позначте
   «Виконувати з найвищими правами».
4. Вкладка **Тригери** → «Створити» → «При вході до системи».
5. Вкладка **Дії** → «Створити» → «Запуск програми»:
   - Програма: `powershell.exe`
   - Аргументи:
     `-ExecutionPolicy Bypass -WindowStyle Hidden -File C:\dev\court-app\server\windows\setup-portproxy.ps1`
6. Вкладка **Умови**: зніміть «Запускати лише за живлення від мережі»,
   якщо це ноутбук.
7. OK. Перевірте, запустивши завдання вручну (права кнопка → «Виконати»).

Після цього при кожному вході в Windows: WSL стартує → бекенд і Nginx
піднімаються (systemd) → portproxy оновлюється → сервер доступний через
Tailscale з будь-де.

## Перевірка

```powershell
curl.exe -s http://100.77.97.16/health      # ваш Tailscale IP
```
Має повернути `{"status":"ok"}`.
