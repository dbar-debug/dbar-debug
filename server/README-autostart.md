# Автозапуск бекенду

Мета: щоб `uvicorn` (бекенд) запускався сам, а не вручну щоразу.

Ваше середовище — **WSL** (Ubuntu на Windows). Тут два сценарії залежно від
того, чи увімкнено systemd. Спершу перевірте:

```bash
ps -p 1 -o comm=
```

- Якщо виводить **`systemd`** → йдіть до **Варіанту A** (найкращий).
- Якщо виводить **`init`** або інше → або увімкніть systemd (крок нижче),
  або йдіть до **Варіанту B**.

---

## Увімкнути systemd у WSL (рекомендовано)

1. Створіть/відредагуйте `/etc/wsl.conf`:
   ```bash
   sudo tee /etc/wsl.conf > /dev/null <<'EOF'
   [boot]
   systemd=true
   EOF
   ```
2. У **PowerShell** (не в WSL) повністю перезапустіть WSL:
   ```powershell
   wsl --shutdown
   ```
3. Знову відкрийте WSL і перевірте: `ps -p 1 -o comm=` → має бути `systemd`.

> Потребує WSL версії 0.67.6+. Оновити: `wsl --update` у PowerShell.

---

## Варіант A — systemd-сервіс (з автоперезапуском і логами)

```bash
# 1. Зробити скрипт запуску виконуваним
chmod +x ~/court-app/server/start-backend.sh

# 2. Встановити сервіс (відредагуйте User= і шляхи під себе, якщо інші)
sudo cp ~/court-app/server/court-app.service /etc/systemd/system/court-app.service
sudo nano /etc/systemd/system/court-app.service   # перевірте User=dbar та шляхи

# 3. Увімкнути та запустити
sudo systemctl daemon-reload
sudo systemctl enable --now court-app

# 4. Перевірити
systemctl status court-app
journalctl -u court-app -f      # живі логи (Ctrl+C щоб вийти)
```

Тепер бекенд стартує автоматично щоразу, коли запускається WSL, і сам
перезапускається при падінні.

---

## Варіант B — без systemd (через wsl.conf boot command)

Якщо systemd увімкнути не вдалося, WSL може запускати команду при старті:

```bash
sudo tee -a /etc/wsl.conf > /dev/null <<'EOF'

[boot]
command = su - dbar -c '/home/dbar/court-app/server/start-backend.sh >> /home/dbar/court-app/backend/backend.log 2>&1 &'
EOF
```

(замініть `dbar` на своє ім'я користувача)

Потім у PowerShell: `wsl --shutdown`, і знову відкрийте WSL. Логи будуть у
`~/court-app/backend/backend.log`.

---

## Щоб WSL (а отже й бекенд) стартував разом із Windows

WSL за замовчуванням запускається лише коли ви відкриваєте термінал. Щоб
бекенд працював одразу після входу в Windows (потрібно для доступу з
телефону поза домом), додайте автозапуск WSL через Планувальник завдань:

1. Win → «Планувальник завдань» (Task Scheduler) → «Створити завдання».
2. **Тригер:** «При вході до системи».
3. **Дія:** запуск програми
   - Програма: `wsl.exe`
   - Аргументи: `-d Ubuntu-22.04 -u dbar /home/dbar/court-app/server/start-backend.sh`
   (підставте свою назву дистрибутива з `wsl -l -v` та ім'я користувача)
4. Позначте «Виконувати незалежно від того, чи ввійшов користувач» — за бажанням.

---

## Швидка перевірка

Після налаштування перезавантажте WSL (`wsl --shutdown` у PowerShell,
потім відкрийте знову) і, **не запускаючи uvicorn вручну**, перевірте:

```bash
curl -s http://localhost:8000/health
```

Має повернути `{"status":"ok"}`.
