import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/router_device.dart';

/// Сховище збережених роутерів (shared_preferences).
///
/// TODO: перед публікацією перенести паролі у flutter_secure_storage /
/// Keychain — зараз вони зберігаються у відкритому вигляді.
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
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      routers
        ..clear()
        ..addAll(list.map(
            (e) => RouterDevice.fromJson(e as Map<String, dynamic>)));
    }
    _loaded = true;
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
    await _save();
  }

  Future<void> update(RouterDevice device) async {
    final idx = routers.indexWhere((r) => r.id == device.id);
    if (idx >= 0) {
      routers[idx] = device;
    } else {
      routers.add(device);
    }
    await _save();
  }

  Future<void> remove(String id) async {
    routers.removeWhere((r) => r.id == id);
    await _save();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final item = routers.removeAt(oldIndex);
    routers.insert(newIndex, item);
    await _save();
  }
}
