import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Налаштування додатка (тема тощо), доступні глобально.
class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _themeKey = 'theme_mode';

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_themeKey)) {
      case 'light':
        themeMode.value = ThemeMode.light;
      case 'dark':
        themeMode.value = ThemeMode.dark;
      default:
        themeMode.value = ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }
}
