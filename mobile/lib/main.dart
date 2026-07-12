import 'package:flutter/material.dart';

import 'screens/cabinet_screen.dart';
import 'screens/debtors_screen.dart';
import 'screens/hearings_screen.dart';
import 'screens/person_search_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const CourtApp());
}

class CourtApp extends StatelessWidget {
  const CourtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Судові справи',
      themeMode: ThemeMode.system,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.light,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomeTabs(),
    );
  }
}

class HomeTabs extends StatefulWidget {
  const HomeTabs({super.key});

  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  int _index = 0;

  static const _screens = [
    CabinetScreen(),
    HearingsScreen(),
    PersonSearchScreen(),
    DebtorsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        // 5 вкладок — щоб довгі підписи не тіснились, показуємо підпис
        // лише активної вкладки, решта — іконки.
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Справи'),
          NavigationDestination(icon: Icon(Icons.event_outlined), label: 'Засідання'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Пошук'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Борги'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Налаштування'),
        ],
      ),
    );
  }
}
