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

- [ ] **Клієнти**: DHCP leases, wireless registration, hotspot, PPP active
- [ ] **Інтерфейси**: окремий екран з графіками rx/tx
- [ ] **Конфігурація**: interfaces, wireless, bridge, IP (addresses, firewall,
      DHCP), queues, system
- [ ] **Логи** роутера з пошуком
- [ ] **Інструменти**: Ping, Traceroute, Bandwidth Test
- [ ] **Файли**: backup / restore
- [ ] **Port Knocking** перед підключенням
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
