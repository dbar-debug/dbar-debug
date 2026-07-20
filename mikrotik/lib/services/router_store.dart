import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/router_device.dart';
import 'secure_credentials.dart';

/// Сховище збережених роутерів.
///
/// Нечутливі поля — у shared_preferences; паролі — у Keychain через
/// [SecureCredentials]. Старі записи, де пароль лежав у prefs, автоматично
/// мігруються в Keychain при першому завантаженні.
class RouterStore extends ChangeNotifier {
  RouterStore._();
  static final RouterStore instance = RouterStore._();

  static const _key = 'saved_routers_v1';

  final List<RouterDevice> routers = [];
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    var needMigration = false;
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      routers.clear();
      for (final e in list) {
        final map = e as Map<String, dynamic>;
        final device = RouterDevice.fromJson(map);
        // Міграція: якщо пароль лежав у prefs — перенести в Keychain.
        final legacyPw = map['password'] as String?;
        if (legacyPw != null && legacyPw.isNotEmpty) {
          await SecureCredentials.instance.setPassword(device.id, legacyPw);
          device.password = legacyPw;
          needMigration = true;
        } else {
          device.password =
              await SecureCredentials.instance.getPassword(device.id);
        }
        routers.add(device);
      }
    }
    _loaded = true;
    // Перезаписати prefs без паролів, якщо була міграція.
    if (needMigration) await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(routers.map((r) => r.toJson()).toList()));
    notifyListeners();
  }

  Future<void> add(RouterDevice device) async {
    routers.add(device);
    await SecureCredentials.instance.setPassword(device.id, device.password);
    await _save();
  }

  Future<void> update(RouterDevice device) async {
    final idx = routers.indexWhere((r) => r.id == device.id);
    if (idx >= 0) {
      routers[idx] = device;
    } else {
      routers.add(device);
    }
    await SecureCredentials.instance.setPassword(device.id, device.password);
    await _save();
  }

  Future<void> remove(String id) async {
    routers.removeWhere((r) => r.id == id);
    await SecureCredentials.instance.deletePassword(id);
    await _save();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = routers.removeAt(oldIndex);
    routers.insert(newIndex, item);
    await _save();
  }
}
