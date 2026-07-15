import 'package:flutter/material.dart';

import '../services/app_settings.dart';

/// Вкладка "Акаунт" — налаштування додатка.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  static String _themeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'Авто',
        ThemeMode.light => 'Світла',
        ThemeMode.dark => 'Темна',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Акаунт')),
      body: ValueListenableBuilder<ThemeMode>(
        valueListenable: AppSettings.instance.themeMode,
        builder: (context, mode, _) {
          return ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined),
                title: const Text('Темний режим'),
                trailing: Text(_themeLabel(mode)),
                onTap: () async {
                  final selected = await showDialog<ThemeMode>(
                    context: context,
                    builder: (context) => SimpleDialog(
                      title: const Text('Темний режим'),
                      children: [
                        for (final m in ThemeMode.values)
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(context, m),
                            child: Text(_themeLabel(m)),
                          ),
                      ],
                    ),
                  );
                  if (selected != null) {
                    await AppSettings.instance.setThemeMode(selected);
                  }
                },
              ),
              const Divider(),
              const ListTile(
                leading: Icon(Icons.language),
                title: Text('Мова'),
                subtitle: Text('Українська (локалізація — у наступній фазі)'),
              ),
              const ListTile(
                leading: Icon(Icons.cloud_upload_outlined),
                title: Text('Резервна копія конфігурації в iCloud'),
                subtitle: Text('У наступній фазі'),
              ),
              const ListTile(
                leading: Icon(Icons.fingerprint),
                title: Text('Аутентифікація при запуску (Face ID)'),
                subtitle: Text('У наступній фазі'),
              ),
            ],
          );
        },
      ),
    );
  }
}
