# Референс: як влаштований PushStats у WinboxMobile

Файли в цій папці — скрипти конкурента (WinboxMobile), надані для аналізу:

- `winboxmobile-pushstats.rsc` — головний скрипт "push stats v6"
  (читабельний вихідний код RouterOS-скрипта)
- `wm-urlencode-compiled.txt`, `wm-interface-monit-compiled.txt` —
  ті самі функції у скомпільованому/серіалізованому вигляді

## Схема роботи PushStats

1. Додаток встановлює на роутер **скрипт** + глобальні функції
   (`wmUrlEncode`, `wmInterfaceMonit`) і **scheduler**, який запускає
   скрипт кожні N хвилин.
2. Скрипт збирає:
   - ідентифікацію: serial-number, system-id, software-id, identity,
     model, version, uptime, `did` (ідентифікатор пристрою iPhone) та
     `pid`
   - продуктивність: cpu-load, free/total memory, free/total hdd,
     кількість активних користувачів
   - health: `/system health print as-value` (voltage, temperature,
     power-consumption…)
   - лічильники: bridge hosts, ip route/arp/pool-used/firewall
     connections, bgp peers, ospf neighbors, ppp active, ipsec,
     dhcp leases, wireless registration, caps-man (remote-cap,
     registration, radio), hotspot (cookie, active, host)
   - трафік: `/interface monitor-traffic <iface> once` для типів
     ether/wlan/cap + aggregate (tx/rx bits-per-second,
     packets-per-second, link-downs, last-link-down-time)
3. Все кодується як `application/x-www-form-urlencoded` і надсилається
   `POST` через `/tool fetch` на сервер збору
   (`https://septudio.com/mik_push_stats`).
4. Сервер зберігає часові ряди, будує графіки (Health / Resource /
   Count / Client / Traffic) і надсилає push-сповіщення при проблемах.

## Що потрібно для нашого PushStats

- [ ] Бекенд: HTTPS endpoint прийому form-data, зберігання часових
      рядів (напр. SQLite/Postgres), API для читання додатком, APNs
      для push.
- [ ] Наш RouterOS-скрипт (аналогічний, зі своїм URL і токеном
      пристрою) + екран "Сценарій установки" в додатку, який
      автоматично встановлює скрипт і scheduler на роутер через API
      (`/system/script/add`, `/system/scheduler/add`).
- [ ] Екран PushStats: вкладки Health | Resource | Count | Client |
      Traffic з графіками за період (3 год / день / тиждень).
