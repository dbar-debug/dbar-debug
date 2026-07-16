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

    // Item list / edit (генеричні таблиці)
    'selected': {'uk': 'Вибрано', 'en': 'Selected'},
    'select_all': {'uk': 'Вибрати все', 'en': 'Select all'},
    'enable': {'uk': 'Увімкнути', 'en': 'Enable'},
    'disable': {'uk': 'Вимкнути', 'en': 'Disable'},
    'delete_q': {'uk': 'Видалити?', 'en': 'Delete?'},
    'delete_count': {'uk': 'Буде видалено елементів', 'en': 'Items to delete'},
    'no_fields': {'uk': 'Немає полів для редагування', 'en': 'No editable fields'},
    'item_new': {'uk': 'новий', 'en': 'new'},

    // Ping/tools підсумки
    'sent': {'uk': 'Надіслано', 'en': 'Sent'},
    'received': {'uk': 'Отримано', 'en': 'Received'},
    'loss': {'uk': 'Втрати', 'en': 'Loss'},
    'ping_count': {'uk': 'Кількість пакетів', 'en': 'Packet count'},
    'measure_cpu': {'uk': 'Виміряти навантаження', 'en': 'Measure load'},
    'collecting': {'uk': 'Збір даних…', 'en': 'Collecting…'},
    'btest_server': {'uk': 'Адреса btest-сервера', 'en': 'btest server address'},
    'btest_hint': {
      'uk': 'Інший MikroTik з увімкненим btest server',
      'en': 'Another MikroTik with btest server enabled'
    },
    'duration_s': {'uk': 'Тривалість, секунд', 'en': 'Duration, seconds'},
    'start_test': {'uk': 'Почати тест', 'en': 'Start test'},
    'test_running': {'uk': 'Тест триває…', 'en': 'Test running…'},
    'both': {'uk': 'Обидва', 'en': 'Both'},
    'status': {'uk': 'Статус', 'en': 'Status'},

    // Port knocking
    'pk_ports': {'uk': 'Порти (через кому, по черзі)', 'en': 'Ports (comma-separated, in order)'},
    'pk_ports_hint': {'uk': 'Напр.: 1000, 2000, 3000', 'en': 'E.g. 1000, 2000, 3000'},
    'pk_delay': {'uk': 'Пауза між стуками, мс', 'en': 'Delay between knocks, ms'},
    'pk_udp': {'uk': 'UDP (замість TCP)', 'en': 'UDP (instead of TCP)'},
    'pk_knock': {'uk': 'Постукати', 'en': 'Knock'},
    'pk_knocking': {'uk': 'Стукаю…', 'en': 'Knocking…'},
    'pk_done': {
      'uk': 'Готово. Роутер має відкрити доступ — підключайтеся.',
      'en': 'Done. The router should open access — connect now.'
    },
    'pk_hint': {
      'uk': 'На роутері має бути налаштований ланцюжок правил firewall, який після правильної послідовності підключень додає вашу адресу до address-list з дозволом доступу.',
      'en': 'The router must have a firewall rule chain that, after the correct sequence of connections, adds your address to an allow address-list.'
    },

    // Команда
    'choose': {'uk': 'Обрати', 'en': 'Choose'},
    'team_intro': {
      'uk': 'Спільний список роутерів для команди. Один роутер MikroTik виступає сховищем: maintainer публікує список, учасники синхронізують його собі.',
      'en': 'A shared router list for your team. One MikroTik router acts as storage: the maintainer publishes the list, members sync it to themselves.'
    },
    'team_router': {'uk': 'Командний роутер', 'en': 'Team router'},
    'team_not_selected': {'uk': 'Не обрано', 'en': 'Not selected'},
    'team_pick_router': {'uk': 'Оберіть командний роутер', 'en': 'Choose team router'},
    'team_need_router': {
      'uk': 'Спершу додайте роутер у "Збережені"',
      'en': 'First add a router in "Saved"'
    },
    'team_publish': {'uk': 'Опублікувати список', 'en': 'Publish list'},
    'team_publish_hint': {
      'uk': 'Вивантажує ваш список роутерів (без паролів) на командний роутер.',
      'en': 'Uploads your router list (without passwords) to the team router.'
    },
    'team_sync': {'uk': 'Синхронізувати собі', 'en': 'Sync to me'},
    'team_sync_hint': {
      'uk': 'Завантажує список з командного роутера й додає роутери у "Збережені". Наявні паролі зберігаються.',
      'en': 'Downloads the list from the team router and adds routers to "Saved". Existing passwords are kept.'
    },
    'team_published': {'uk': 'Список опубліковано', 'en': 'List published'},
    'team_synced': {'uk': 'Синхронізовано', 'en': 'Synced'},
    'team_security': {
      'uk': 'Паролі ніколи не передаються в спільний список — кожен учасник вводить свої.',
      'en': 'Passwords are never shared — each member enters their own.'
    },
  };

  static String t(String key) {
    final entry = _s[key];
    if (entry == null) return key;
    return entry[code] ?? entry['uk'] ?? key;
  }
}

/// Скорочення для використання у віджетах: `tr('save')`.
String tr(String key) => L.t(key);
