import 'package:flutter/material.dart';

import '../models/router_device.dart';
import '../services/metrics_collector.dart';
import '../services/routeros_client.dart';
import '../l10n/strings.dart';
import 'charts_tab.dart';
import 'clients_tab.dart';
import 'dashboard_screen.dart';
import 'files_screen.dart';
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
            destinations: [
              NavigationDestination(
                  icon: const Icon(Icons.speed), label: tr('tab_dashboard')),
              NavigationDestination(
                  icon: const Icon(Icons.devices), label: tr('tab_clients')),
              NavigationDestination(
                  icon: const Icon(Icons.bar_chart),
                  label: tr('tab_interfaces')),
              NavigationDestination(
                  icon: const Icon(Icons.stacked_line_chart),
                  label: tr('tab_charts')),
              NavigationDestination(
                  icon: const Icon(Icons.auto_fix_high),
                  label: tr('tab_tools')),
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
              title: Text(tr('router_settings')),
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
              title: Text(tr('router_logs')),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => LogsScreen(client: widget.client),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(tr('files')),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => FilesScreen(client: widget.client),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: Text(tr('port_knocking')),
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
              title: Text(tr('shutdown')),
              onTap: () => _confirmPower(context, shutdown: true),
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt),
              title: Text(tr('reboot')),
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
    final name = _collector.identity ?? widget.device.host;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(shutdown ? tr('shutdown') : tr('reboot')),
        content: Text(
            '${shutdown ? tr('shutdown_q') : tr('reboot_q')} $name?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(shutdown ? tr('shutdown') : tr('reboot'))),
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
