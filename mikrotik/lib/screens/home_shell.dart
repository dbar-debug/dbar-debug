import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import 'account_screen.dart';
import 'connect_screen.dart';
import 'pushstats_screen.dart';
import 'saved_screen.dart';
import 'team_screen.dart';

/// Головна оболонка з 5 вкладками, як у WinboxMobile:
/// Збережені | Підключення | Команда | PushStats | Акаунт
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = <Widget>[
    SavedScreen(),
    ConnectScreen(),
    TeamScreen(),
    PushStatsScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.router_outlined),
            selectedIcon: const Icon(Icons.router),
            label: tr('tab_saved'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.lan_outlined),
            selectedIcon: const Icon(Icons.lan),
            label: tr('tab_connect'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.dns_outlined),
            selectedIcon: const Icon(Icons.dns),
            label: tr('tab_team'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.donut_large_outlined),
            selectedIcon: const Icon(Icons.donut_large),
            label: tr('tab_pushstats'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: tr('tab_account'),
          ),
        ],
      ),
    );
  }
}
