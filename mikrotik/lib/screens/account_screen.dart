import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/app_settings.dart';
import '../services/biometric_auth.dart';

/// Вкладка "Акаунт" — налаштування додатка.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => tr('theme_auto'),
        ThemeMode.light => tr('theme_light'),
        ThemeMode.dark => tr('theme_dark'),
      };

  Future<void> _pickTheme() async {
    final selected = await showDialog<ThemeMode>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr('dark_mode')),
        children: [
          for (final m in ThemeMode.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, m),
              child: Text(_themeLabel(m)),
            ),
        ],
      ),
    );
    if (selected != null) await AppSettings.instance.setThemeMode(selected);
  }

  Future<void> _pickLanguage() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr('language')),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'uk'),
            child: Text(tr('lang_uk')),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, 'en'),
            child: Text(tr('lang_en')),
          ),
        ],
      ),
    );
    if (selected != null) await AppSettings.instance.setLanguage(selected);
  }

  Future<void> _toggleBiometric(bool value) async {
    if (value && !await BiometricAuth.instance.isAvailable()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('auth_unavailable'))));
      }
      return;
    }
    await AppSettings.instance.setAuthOnLaunch(value);
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return Scaffold(
      appBar: AppBar(title: Text(tr('account'))),
      body: ListView(
        children: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: settings.themeMode,
            builder: (context, mode, _) => ListTile(
              leading: const Icon(Icons.dark_mode_outlined),
              title: Text(tr('dark_mode')),
              trailing: Text(_themeLabel(mode)),
              onTap: _pickTheme,
            ),
          ),
          ValueListenableBuilder<String>(
            valueListenable: settings.language,
            builder: (context, code, _) => ListTile(
              leading: const Icon(Icons.language),
              title: Text(tr('language')),
              trailing: Text(code == 'en' ? tr('lang_en') : tr('lang_uk')),
              onTap: _pickLanguage,
            ),
          ),
          const Divider(),
          ValueListenableBuilder<bool>(
            valueListenable: settings.authOnLaunch,
            builder: (context, enabled, _) => SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: Text(tr('auth_on_launch')),
              subtitle: Text(tr('auth_on_launch_sub')),
              value: enabled,
              onChanged: _toggleBiometric,
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cloud_upload_outlined),
            title: Text(tr('icloud_backup')),
            subtitle: Text(tr('next_phase')),
          ),
        ],
      ),
    );
  }
}
