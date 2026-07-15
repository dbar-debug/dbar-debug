import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'services/app_settings.dart';
import 'services/router_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  await RouterStore.instance.load();
  runApp(const MikrotikApp());
}

class MikrotikApp extends StatelessWidget {
  const MikrotikApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.instance.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'MikroTik Mobile',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: ThemeData(
            colorSchemeSeed: Colors.blue,
            brightness: Brightness.light,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: Colors.blue,
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          home: const HomeShell(),
        );
      },
    );
  }
}
