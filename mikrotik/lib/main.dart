import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/strings.dart';
import 'screens/auth_gate.dart';
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
    final settings = AppSettings.instance;
    // Перебудовуємо застосунок при зміні теми АБО мови.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: settings.themeMode,
      builder: (context, mode, _) {
        return ValueListenableBuilder<String>(
          valueListenable: settings.language,
          builder: (context, langCode, _) {
            L.code = langCode; // глобальний доступ для tr()
            return MaterialApp(
              title: 'MikroTik Mobile',
              debugShowCheckedModeBanner: false,
              themeMode: mode,
              locale: Locale(langCode),
              supportedLocales: L.supported,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
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
              home: const AuthGate(child: HomeShell()),
            );
          },
        );
      },
    );
  }
}
