import 'dart:ui';

/// Легка локалізація uk/en без кодогенерації.
///
/// Глобальний `tr('key')` читає поточну мову з [L.code], яку виставляє
/// `MaterialApp` при кожній зміні мови (див. main.dart). Технічні терміни
/// RouterOS (Interfaces, Firewall, chain, action…) навмисно не
/// перекладаються — вони однакові в обох мовах.
class L {
  static String code = 'uk';

  static const supported = [Locale('uk'), Locale('en')];

  static const Map<String, Map<String, String>> _s = {
    // Нижня навігація / вкладки
    'tab_saved': {'uk': 'Збережені', 'en': 'Saved'},
    'tab_connect': {'uk': 'Підключення', 'en': 'Connect'},
    'tab_team': {'uk': 'Команда', 'en': 'Team'},
    'tab_pushstats': {'uk': 'PushStats', 'en': 'PushStats'},
    'tab_account': {'uk': 'Акаунт', 'en': 'Account'},
    'tab_dashboard': {'uk': 'Огляд', 'en': 'Dashboard'},
    'tab_clients': {'uk': 'Клієнти', 'en': 'Clients'},
    'tab_interfaces': {'uk': 'Інтерфейси', 'en': 'Interfaces'},
    'tab_charts': {'uk': 'Графіки', 'en': 'Charts'},
    'tab_tools': {'uk': 'Інструменти', 'en': 'Tools'},

    // Загальні
    'search': {'uk': 'Пошук…', 'en': 'Search…'},
    'cancel': {'uk': 'Скасувати', 'en': 'Cancel'},
    'save': {'uk': 'Зберегти', 'en': 'Save'},
    'delete': {'uk': 'Видалити', 'en': 'Delete'},
    'edit': {'uk': 'Редагувати', 'en': 'Edit'},
    'retry': {'uk': 'Повторити', 'en': 'Retry'},
    'done': {'uk': 'Готово', 'en': 'Done'},
    'empty': {'uk': 'Порожньо', 'en': 'Empty'},
    'error': {'uk': 'Помилка', 'en': 'Error'},
    'total': {'uk': 'Всього', 'en': 'Total'},
    'yes': {'uk': 'Так', 'en': 'Yes'},

    // Saved
    'saved_empty': {
      'uk': 'Немає збережених роутерів.\nДодайте через + або вкладку "Підключення".',
      'en': 'No saved routers.\nAdd one with + or the "Connect" tab.'
    },
    'saved_search_hint': {
      'uk': 'Пошук: назва, IP, мітка…',
      'en': 'Search: name, IP, label…'
    },
    'connect_failed': {'uk': 'Не вдалося підключитися', 'en': 'Connection failed'},

    // Router form
    'router_new': {'uk': 'Новий роутер', 'en': 'New router'},
    'router_edit': {'uk': 'Редагувати роутер', 'en': 'Edit router'},
    'field_name': {'uk': 'Назва', 'en': 'Name'},
    'field_host': {'uk': 'IP або доменне ім\'я', 'en': 'IP or hostname'},
    'field_user': {'uk': 'Ім\'я користувача', 'en': 'Username'},
    'field_password': {'uk': 'Пароль', 'en': 'Password'},
    'field_password_opt': {'uk': 'Необов\'язковий', 'en': 'Optional'},
    'field_port': {'uk': 'Порт', 'en': 'Port'},
    'field_labels': {'uk': 'Мітки', 'en': 'Labels'},
    'labels_hint': {'uk': 'Через кому, напр.: офіс, київ', 'en': 'Comma-separated, e.g. office, kyiv'},
    'port_hint': {
      'uk': 'За замовчуванням: api — 8728, api-ssl — 8729',
      'en': 'Default: api — 8728, api-ssl — 8729'
    },
    'enter_address': {'uk': 'Вкажіть адресу', 'en': 'Enter an address'},

    // Connect
    'quick_connect': {'uk': 'Швидке підключення', 'en': 'Quick connect'},
    'connect_now': {'uk': 'Підключитися зараз', 'en': 'Connect now'},
    'scan_network': {'uk': 'Сканування локальної мережі', 'en': 'Scan local network'},
    'connect_hint': {
      'uk': 'api / api-ssl має бути ввімкнено на роутері (IP → Services). Якщо не вдається підключитися, перевірте, що сервіс api не вимкнений і не обмежений за адресами.',
      'en': 'api / api-ssl must be enabled on the router (IP → Services). If you cannot connect, check that the api service is enabled and not restricted by address.'
    },

    // Scan
    'scan_title': {'uk': 'Сканування мережі', 'en': 'Network scan'},
    'subnet': {'uk': 'Підмережа', 'en': 'Subnet'},
    'subnet_hint': {
      'uk': 'Напр. 192.168.88 (скан .1–.254, порт 8728)',
      'en': 'E.g. 192.168.88 (scan .1–.254, port 8728)'
    },
    'scan': {'uk': 'Сканувати', 'en': 'Scan'},
    'stop': {'uk': 'Стоп', 'en': 'Stop'},
    'scanning': {'uk': 'Сканування…', 'en': 'Scanning…'},
    'scan_none': {
      'uk': 'Роутери не знайдені. Запустіть сканування.',
      'en': 'No routers found. Start a scan.'
    },

    // Account
    'account': {'uk': 'Акаунт', 'en': 'Account'},
    'dark_mode': {'uk': 'Темний режим', 'en': 'Dark mode'},
    'theme_auto': {'uk': 'Авто', 'en': 'Auto'},
    'theme_light': {'uk': 'Світла', 'en': 'Light'},
    'theme_dark': {'uk': 'Темна', 'en': 'Dark'},
    'language': {'uk': 'Мова', 'en': 'Language'},
    'lang_uk': {'uk': 'Українська', 'en': 'Ukrainian'},
    'lang_en': {'uk': 'Англійська', 'en': 'English'},
    'auth_on_launch': {'uk': 'Face ID / Touch ID при запуску', 'en': 'Face ID / Touch ID on launch'},
    'auth_on_launch_sub': {
      'uk': 'Питати біометрію при відкритті додатка',
      'en': 'Require biometrics when opening the app'
    },
    'auth_unavailable': {
      'uk': 'Біометрія недоступна на цьому пристрої',
      'en': 'Biometrics unavailable on this device'
    },
    'icloud_backup': {'uk': 'Резервна копія в iCloud', 'en': 'iCloud backup'},
    'next_phase': {'uk': 'У наступній фазі', 'en': 'In a future phase'},

    // Auth gate
    'auth_reason': {'uk': 'Розблокуйте MikroTik Mobile', 'en': 'Unlock MikroTik Mobile'},
    'auth_locked': {'uk': 'Додаток заблоковано', 'en': 'App locked'},
    'auth_unlock': {'uk': 'Розблокувати', 'en': 'Unlock'},

    // Dashboard
    'uptime': {'uk': 'Аптайм', 'en': 'Uptime'},
    'traffic': {'uk': 'Трафік', 'en': 'Traffic'},
    'ethernet': {'uk': 'Ethernet', 'en': 'Ethernet'},
    'interface_types': {'uk': 'Типи інтерфейсів', 'en': 'Interface types'},
    'memory': {'uk': 'Пам\'ять', 'en': 'Memory'},
    'disk': {'uk': 'Диск', 'en': 'Disk'},

    // Drawer
    'router_settings': {'uk': 'Налаштування роутера', 'en': 'Router settings'},
    'router_logs': {'uk': 'Журнали роутера', 'en': 'Router logs'},
    'files': {'uk': 'Файли (backup/restore)', 'en': 'Files (backup/restore)'},
    'port_knocking': {'uk': 'Port Knocking', 'en': 'Port Knocking'},
    'shutdown': {'uk': 'Вимкнення', 'en': 'Shutdown'},
    'reboot': {'uk': 'Перезавантаження', 'en': 'Reboot'},
    'shutdown_q': {'uk': 'Точно вимкнути роутер', 'en': 'Really shut down router'},
    'reboot_q': {'uk': 'Точно перезавантажити роутер', 'en': 'Really reboot router'},

    // Clients
    'client_search': {'uk': 'Пошук клієнта…', 'en': 'Search client…'},
    'disconnect': {'uk': 'Роз\'єднати', 'en': 'Disconnect'},
    'remove_lease': {'uk': 'Видалити оренду', 'en': 'Remove lease'},
    'end_session': {'uk': 'Завершити сеанс', 'en': 'End session'},
    'pkg_missing': {
      'uk': '(Можливо, пакет не встановлений на цьому роутері)',
      'en': '(The package may not be installed on this router)'
    },

    // Interfaces
    'iface_search': {'uk': 'Пошук інтерфейсу…', 'en': 'Search interface…'},
    'iface_enable': {'uk': 'Увімкнути інтерфейс', 'en': 'Enable interface'},
    'iface_disable': {'uk': 'Вимкнути інтерфейс', 'en': 'Disable interface'},

    // Charts
    'cpu_pct': {'uk': 'Процесор, %', 'en': 'CPU, %'},
    'mem_mb': {'uk': 'Пам\'ять, MB', 'en': 'Memory, MB'},
    'add_iface_chart': {'uk': 'Додати діаграму інтерфейсу', 'en': 'Add interface chart'},
    'iface_charts': {'uk': 'Графіки інтерфейсів', 'en': 'Interface charts'},

    // Tools
    'tool_ping': {'uk': 'Ping', 'en': 'Ping'},
    'tool_traceroute': {'uk': 'Traceroute', 'en': 'Traceroute'},
    'tool_ipscan': {'uk': 'IP Scan (з телефона)', 'en': 'IP Scan (from phone)'},
    'tool_btest': {'uk': 'Bandwidth Test', 'en': 'Bandwidth Test'},
    'tool_profile': {'uk': 'Profile (навантаження CPU)', 'en': 'Profile (CPU load)'},
    'address_or_domain': {'uk': 'Адреса або домен', 'en': 'Address or domain'},
    'packet_count': {'uk': 'Кількість пакетів', 'en': 'Packet count'},
    'running': {'uk': 'Виконується…', 'en': 'Running…'},

    // Logs
    'logs_search': {'uk': 'Пошук у журналі…', 'en': 'Search logs…'},

    // Files
    'files_title': {'uk': 'Файли', 'en': 'Files'},
    'create_backup': {'uk': 'Створити backup', 'en': 'Create backup'},
    'create_export': {'uk': 'Створити export (.rsc)', 'en': 'Create export (.rsc)'},
    'restore_backup': {'uk': 'Відновити з backup', 'en': 'Restore from backup'},
    'restore_q': {
      'uk': 'Відновити конфігурацію з цього файлу? Роутер перезавантажиться.',
      'en': 'Restore configuration from this file? The router will reboot.'
    },
    'restore': {'uk': 'Відновити', 'en': 'Restore'},
    'view_content': {'uk': 'Переглянути вміст', 'en': 'View content'},
    'backup_name': {'uk': 'Назва файлу', 'en': 'File name'},
    'backup_created': {'uk': 'Backup створено', 'en': 'Backup created'},
    'export_created': {'uk': 'Export створено', 'en': 'Export created'},

    // PushStats (короткі)
    'ps_settings': {'uk': 'Налаштування', 'en': 'Settings'},
    'ps_install': {'uk': 'Встановити на роутер', 'en': 'Install on router'},
  };

  static String t(String key) {
    final entry = _s[key];
    if (entry == null) return key;
    return entry[code] ?? entry['uk'] ?? key;
  }
}

/// Скорочення для використання у віджетах: `tr('save')`.
String tr(String key) => L.t(key);
