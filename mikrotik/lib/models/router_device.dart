/// Збережений роутер у списку "Збережені".
class RouterDevice {
  String id;
  String name;
  String host;
  int? port; // null — порт за замовчуванням (8728 / 8729)
  bool useSsl;
  String username;
  String password;
  List<String> labels; // мітки для групування/пошуку

  RouterDevice({
    required this.id,
    required this.name,
    required this.host,
    this.port,
    this.useSsl = false,
    this.username = 'admin',
    this.password = '',
    List<String>? labels,
  }) : labels = labels ?? [];

  int get effectivePort => port ?? (useSsl ? 8729 : 8728);

  /// Пароль НЕ серіалізується у shared_preferences — він зберігається
  /// окремо в Keychain через SecureCredentials (див. RouterStore).
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'useSsl': useSsl,
        'username': username,
        'labels': labels,
      };

  factory RouterDevice.fromJson(Map<String, dynamic> json) => RouterDevice(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        host: json['host'] as String? ?? '',
        port: json['port'] as int?,
        useSsl: json['useSsl'] as bool? ?? false,
        username: json['username'] as String? ?? 'admin',
        password: json['password'] as String? ?? '',
        labels: (json['labels'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
      );

  bool matches(String query) {
    final q = query.toLowerCase();
    return name.toLowerCase().contains(q) ||
        host.toLowerCase().contains(q) ||
        labels.any((l) => l.toLowerCase().contains(q));
  }
}
