# MikroTik Mobile

Власний додаток для iPhone для керування роутерами MikroTik RouterOS —
аналог WinboxMobile. Flutter, без проміжного сервера: додаток спілкується
з роутером напряму через бінарний протокол RouterOS API (api / api-ssl).

## Що вже працює (фаза 1)

- **5 вкладок** як у WinboxMobile: Збережені | Підключення | Команда |
  PushStats | Акаунт
- **Клієнт RouterOS API** (`lib/services/routeros_client.dart`):
  - бінарний протокол api (порт 8728) та api-ssl (8729, самопідписані
    сертифікати приймаються)
  - логін для RouterOS ≥ 6.43 (plain) та < 6.43 (MD5 challenge-response) —
    підтримка версій 5.xx – 7.xx
- **Збережені**: список роутерів з пошуком (назва / IP / мітки),
  перетягуванням, редагуванням, мітками; підключення по тапу
- **Швидке підключення**: IP + користувач + пароль + SSL + порт,
  автозбереження успішного підключення як "Auto saved"
- **Сканування локальної мережі**: пошук роутерів по підмережі
  (відкритий порт 8728)
- **Дашборд**: ідентичність, модель, версія RouterOS, аптайм,
  CPU / пам'ять / диск, список інтерфейсів зі швидкістю ↑/↓ у реальному часі
- **Акаунт**: темний режим (Авто / Світла / Темна)

## Фаза 2 — керування роутером (готово)

- **Бокове меню** на дашборді: Налаштування роутера, Журнали, Port Knocking,
  Вимкнення, Перезавантаження (з підтвердженням)
- **Налаштування роутера** — універсальний браузер конфігурації
  (`lib/config/menu_tree.dart` + генеричні екрани): CAPsMAN, Interfaces,
  Wireless, Bridge, PPP, Switch, Mesh, IP (Addresses, ARP, DHCP, DNS,
  **Firewall: Filter/NAT/Mangle/Raw/Service Ports/Connections/Address
  Lists**, Pool, Routes, Services), IPv6, Routing, System, Queues, Radius,
  Files
- **Список елементів** у стилі карток Winbox: пошук, бейдж
  enabled/disabled, коментарі `;;;`, pull-to-refresh
- **Пакетні дії**: довге натискання → вибір кількох → увімкнути /
  вимкнути / видалити / вибрати все
- **Редактор елемента** з секціями Comment/Disable | General | Advanced |
  Action (для firewall — повний набір полів як у Winbox); для інших таблиць
  — генеричний редактор за атрибутами
- **Журнали роутера** з пошуком і підсвіткою error/warning
- **Port Knocking**: послідовність TCP/UDP-стуків із налаштованою паузою

## Фаза 3 — сесія роутера з вкладками (готово)

- **Оболонка сесії** з нижніми вкладками, як у WinboxMobile:
  Dashboard | Clients | Interfaces | Charts | Tools
  (`lib/screens/connected_shell.dart`); бокове меню перенесено сюди
- **MetricsCollector** (`lib/services/metrics_collector.dart`) — єдине
  опитування resource + interfaces раз на 3 с живить одразу дашборд,
  інтерфейси і графіки; веде історію ~3 хв
- **Clients**: перемикач DHCP | Wireless | PPP | Hotspot, пошук, лічильник
- **Interfaces**: групування за типом, живі швидкості ↑/↓; детальний екран
  інтерфейсу з живим графіком tx/rx, властивостями та
  увімкненням/вимкненням
- **Charts**: власний віджет графіків на CustomPainter (без сторонніх
  бібліотек) — CPU, пам'ять + діаграми вибраних інтерфейсів; вибір
  зберігається окремо для кожного роутера
- **Tools**: Ping (живий вивід, підсумок RTT/втрат), Traceroute,
  Bandwidth Test (напрямок TX/RX/обидва, жива швидкість), Profile
  (навантаження CPU за процесами), IP Scan з телефона
- **Стрімінг у клієнті API**: `talk(..., onReply:)` віддає !re-відповіді
  в міру надходження

## PushStats — як це працює у конкурента

Див. `reference/README.md`: роутер сам надсилає статистику POST-ом через
`/tool fetch` за скриптом у scheduler; потрібен бекенд збору + APNs.
Скрипти конкурента збережені в `reference/` для аналізу.

## Запуск

```bash
cd mikrotik
flutter create . --platforms=ios,android   # згенерувати платформні папки
flutter pub get
flutter run
```

> **iOS, локальна мережа:** для сканування та підключення по локальній
> мережі додайте в `ios/Runner/Info.plist` ключ
> `NSLocalNetworkUsageDescription` з поясненням (iOS 14+ питає дозвіл).

## Дорожня карта (наступні фази)

- [x] **Конфігурація**: interfaces, wireless, bridge, IP (addresses, firewall,
      DHCP), queues, system — фаза 2
- [x] **Логи** роутера з пошуком — фаза 2
- [x] **Port Knocking** перед підключенням — фаза 2
- [x] **Клієнти**: DHCP / Wireless / PPP / Hotspot — фаза 3
- [x] **Інтерфейси**: екран з графіками rx/tx — фаза 3
- [x] **Інструменти**: Ping, Traceroute, Bandwidth Test, Profile — фаза 3
- [x] **Графіки**: групи діаграм CPU/пам'ять/інтерфейси — фаза 3
- [ ] **Файли**: backup / restore
- [ ] **Команда**: спільний список роутерів через "командний сервер"
      (роутер MikroTik як сховище файлу зі списком)
- [ ] **PushStats**: пасивний моніторинг + push-сповіщення (потрібен бекенд
      прийому статистики + APNs)
- [ ] Безпека: паролі у Keychain (flutter_secure_storage), Face ID при
      запуску, резервна копія в iCloud
- [ ] Локалізація (укр/англ)

## Структура

```
lib/
├── main.dart                      # запуск, тема
├── models/router_device.dart      # модель збереженого роутера
├── services/
│   ├── routeros_client.dart       # протокол RouterOS API
│   ├── router_store.dart          # сховище збережених роутерів
│   └── app_settings.dart          # налаштування (тема)
└── screens/
    ├── home_shell.dart            # 5 вкладок
    ├── saved_screen.dart          # Збережені
    ├── router_form_screen.dart    # додати/редагувати роутер
    ├── connect_screen.dart        # Швидке підключення
    ├── scan_screen.dart           # сканування підмережі
    ├── dashboard_screen.dart      # дашборд роутера
    ├── team_screen.dart           # Команда (заглушка)
    ├── pushstats_screen.dart      # PushStats (заглушка)
    └── account_screen.dart        # Акаунт / налаштування
```
