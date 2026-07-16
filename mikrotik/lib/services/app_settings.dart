import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Налаштування додатка (тема, мова, біометрія), доступні глобально.
class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _themeKey = 'theme_mode';
  static const _langKey = 'language_code';
  static const _biometricKey = 'auth_on_launch';

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.system);

  /// Код мови: 'uk' або 'en'.
  final ValueNotifier<String> language = ValueNotifier('uk');

  /// Питати біометрію при запуску.
  final ValueNotifier<bool> authOnLaunch = ValueNotifier(false);

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
    language.value = prefs.getString(_langKey) ?? 'uk';
    authOnLaunch.value = prefs.getBool(_biometricKey) ?? false;
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

  Future<void> setLanguage(String code) async {
    language.value = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_langKey, code);
  }

  Future<void> setAuthOnLaunch(bool value) async {
    authOnLaunch.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, value);
  }
}
