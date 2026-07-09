import 'package:flutter/material.dart';

import 'screens/cabinet_screen.dart';
import 'screens/search_screen.dart';
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
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
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
    SearchScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.folder_outlined), label: 'Мої справи'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Пошук'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Налаштування'),
        ],
      ),
    );
  }
}
