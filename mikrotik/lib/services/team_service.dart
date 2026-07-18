import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/router_device.dart';
import 'router_store.dart';
import 'routeros_client.dart';

/// Результат синхронізації списку команди.
class TeamSyncResult {
  final int added;
  final int updated;
  TeamSyncResult(this.added, this.updated);
}

/// Спільний список роутерів для команди через "командний роутер".
///
/// Список зберігається як джерело скрипта `mm-team-list` на вибраному
/// роутері MikroTik (працює на RouterOS 6 і 7). Паролі НЕ передаються —
/// кожен учасник вводить свої. Учасники синхронізують список собі.
class TeamService {
  static const scriptName = 'mm-team-list';
  static const _teamRouterKey = 'team_router_id';

  /// id роутера, обраного "командним сховищем".
  static Future<String?> teamRouterId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_teamRouterKey);
  }

  static Future<void> setTeamRouterId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_teamRouterKey, id);
  }

  static Future<RouterOSClient> _connect(RouterDevice device) async {
    final client = RouterOSClient();
    await client.connect(device.host, device.effectivePort,
        useSsl: device.useSsl);
    await client.login(device.username, device.password);
    return client;
  }

  /// Публікує поточний список роутерів (без паролів) на командний роутер.
  static Future<void> publish(RouterDevice teamRouter) async {
    final devices = RouterStore.instance.routers
        // не публікуємо сам "Auto saved" і, за бажанням, дублікати
        .where((r) => r.id != 'autosaved')
        .map((r) => r.toJson()) // toJson вже без пароля
        .toList();
    final payload = jsonEncode({'version': 1, 'routers': devices});

    final client = await _connect(teamRouter);
    try {
      // прибрати стару версію
      final existing =
          await client.talk(['/system/script/print', '?name=$scriptName']);
      for (final item in existing) {
        final id = item['.id'];
        if (id != null) {
          await client.talk(['/system/script/remove', '=.id=$id']);
        }
      }
      await client.talk([
        '/system/script/add',
        '=name=$scriptName',
        '=comment=MikroTik Mobile team router list',
        '=source=$payload',
      ]);
    } finally {
      client.close();
    }
  }

  /// Завантажує список команди з роутера і зливає у "Збережені".
  /// Наявні роутери (за host) оновлюються без втрати пароля; нові
  /// додаються з порожнім паролем.
  static Future<TeamSyncResult> sync(RouterDevice teamRouter) async {
    final client = await _connect(teamRouter);
    String? source;
    try {
      final res =
          await client.talk(['/system/script/print', '?name=$scriptName']);
      if (res.isEmpty) {
        throw RouterOSException(
            'На цьому роутері немає опублікованого списку команди');
      }
      source = res.first['source'];
    } finally {
      client.close();
    }
    if (source == null || source.isEmpty) {
      throw RouterOSException('Список команди порожній');
    }

    final data = jsonDecode(source) as Map<String, dynamic>;
    final routers = (data['routers'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    var added = 0;
    var updated = 0;
    final store = RouterStore.instance;
    for (final json in routers) {
      final incoming = RouterDevice.fromJson(json);
      final existing = store.routers
          .where((r) => r.host == incoming.host)
          .cast<RouterDevice?>()
          .firstWhere((_) => true, orElse: () => null);
      if (existing != null) {
        // оновити нечутливі поля, зберегти пароль
        existing.name = incoming.name;
        existing.port = incoming.port;
        existing.useSsl = incoming.useSsl;
        existing.username = incoming.username;
        existing.labels = incoming.labels;
        await store.update(existing);
        updated++;
      } else {
        // новий id, щоб не конфліктувати; пароль порожній
        incoming.id = DateTime.now().microsecondsSinceEpoch.toString();
        incoming.password = '';
        await store.add(incoming);
        added++;
      }
    }
    return TeamSyncResult(added, updated);
  }
}
