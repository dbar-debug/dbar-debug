import 'package:flutter/material.dart';

import '../models/router_device.dart';
import '../services/metrics_collector.dart';
import '../services/routeros_client.dart';
import 'charts_tab.dart';
import 'clients_tab.dart';
import 'dashboard_screen.dart';
import 'interfaces_tab.dart';
import 'logs_screen.dart';
import 'port_knock_screen.dart';
import 'router_settings_screen.dart';
import 'tools_tab.dart';

/// Оболонка сесії підключеного роутера з вкладками, як у WinboxMobile:
/// Dashboard | Clients | Interfaces | Charts | Tools + бокове меню.
class ConnectedShell extends StatefulWidget {
  final RouterOSClient client;
  final RouterDevice device;

  const ConnectedShell(
      {super.key, required this.client, required this.device});

  @override
  State<ConnectedShell> createState() => _ConnectedShellState();
}

class _ConnectedShellState extends State<ConnectedShell> {
  late final MetricsCollector _collector;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _collector = MetricsCollector(widget.client);
    _collector.start();
  }

  @override
  void dispose() {
    _collector.stopAndClose();
    _collector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _collector,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_collector.identity ?? widget.device.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _collector.refresh,
              ),
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
              ),
            ],
          ),
          endDrawer: _buildDrawer(context),
          body: IndexedStack(
            index: _index,
            children: [
              DashboardTab(collector: _collector, client: widget.client),
              ClientsTab(client: widget.client),
              InterfacesTab(collector: _collector, client: widget.client),
              ChartsTab(collector: _collector, storageKey: widget.device.host),
              ToolsTab(client: widget.client),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.speed), label: 'Dashboard'),
              NavigationDestination(
                  icon: Icon(Icons.devices), label: 'Clients'),
              NavigationDestination(
                  icon: Icon(Icons.bar_chart), label: 'Interfaces'),
              NavigationDestination(
                  icon: Icon(Icons.stacked_line_chart), label: 'Charts'),
              NavigationDestination(
                  icon: Icon(Icons.auto_fix_high), label: 'Tools'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              title: Text(_collector.identity ?? widget.device.name,
                  style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(widget.device.host),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Налаштування роутера'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      RouterSettingsScreen(client: widget.client),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('Журнали роутера'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => LogsScreen(client: widget.client),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Port Knocking'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      PortKnockScreen(host: widget.device.host),
                ));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.power_settings_new),
              title: const Text('Вимкнення'),
              onTap: () => _confirmPower(context, shutdown: true),
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: const Text('Перезавантаження'),
              onTap: () => _confirmPower(context, shutdown: false),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmPower(BuildContext drawerContext,
      {required bool shutdown}) async {
    Navigator.pop(drawerContext); // закрити drawer
    final action = shutdown ? 'вимкнути' : 'перезавантажити';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(shutdown ? 'Вимкнення' : 'Перезавантаження'),
        content: Text('Точно $action роутер '
            '${_collector.identity ?? widget.device.host}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Скасувати')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(shutdown ? 'Вимкнути' : 'Перезавантажити')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.client
          .talk([shutdown ? '/system/shutdown' : '/system/reboot']);
    } on Object {
      // з'єднання розривається одразу після команди — це очікувано
    }
    if (mounted) Navigator.of(context).pop(); // вийти з сесії
  }
}
