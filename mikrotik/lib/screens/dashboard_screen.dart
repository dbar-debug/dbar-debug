import 'dart:async';

import 'package:flutter/material.dart';

import '../models/router_device.dart';
import '../services/routeros_client.dart';
import 'logs_screen.dart';
import 'port_knock_screen.dart';
import 'router_settings_screen.dart';

/// Дашборд підключеного роутера: ідентичність, версія RouterOS,
/// CPU / пам'ять / диск, аптайм та трафік інтерфейсів у реальному часі.
class DashboardScreen extends StatefulWidget {
  final RouterOSClient client;
  final RouterDevice device;

  const DashboardScreen(
      {super.key, required this.client, required this.device});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _IfaceRate {
  int rxBytes;
  int txBytes;
  DateTime at;
  double rxBps = 0;
  double txBps = 0;
  _IfaceRate(this.rxBytes, this.txBytes, this.at);
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _timer;
  String? _identity;
  Map<String, String> _resource = {};
  List<Map<String, String>> _interfaces = [];
  final Map<String, _IfaceRate> _rates = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadIdentity();
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.client.close();
    super.dispose();
  }

  Future<void> _loadIdentity() async {
    try {
      final res = await widget.client.talk(['/system/identity/print']);
      if (mounted && res.isNotEmpty) {
        setState(() => _identity = res.first['name']);
      }
    } on Object {
      // не критично
    }
  }

  Future<void> _poll() async {
    try {
      final resource = await widget.client.talk(['/system/resource/print']);
      final ifaces = await widget.client.talk(['/interface/print']);
      final now = DateTime.now();
      for (final f in ifaces) {
        final name = f['name'];
        if (name == null) continue;
        final rx = int.tryParse(f['rx-byte'] ?? '') ?? 0;
        final tx = int.tryParse(f['tx-byte'] ?? '') ?? 0;
        final prev = _rates[name];
        if (prev != null) {
          final dt = now.difference(prev.at).inMilliseconds / 1000.0;
          if (dt > 0) {
            prev.rxBps = ((rx - prev.rxBytes) * 8 / dt).clamp(0, double.infinity);
            prev.txBps = ((tx - prev.txBytes) * 8 / dt).clamp(0, double.infinity);
          }
          prev.rxBytes = rx;
          prev.txBytes = tx;
          prev.at = now;
        } else {
          _rates[name] = _IfaceRate(rx, tx, now);
        }
      }
      if (!mounted) return;
      setState(() {
        _resource = resource.isNotEmpty ? resource.first : {};
        _interfaces = ifaces;
        _error = null;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  double _percentUsed(String? freeStr, String? totalStr) {
    final free = int.tryParse(freeStr ?? '');
    final total = int.tryParse(totalStr ?? '');
    if (free == null || total == null || total == 0) return 0;
    return (total - free) / total;
  }

  static String _formatBps(double bps) {
    if (bps >= 1e9) return '${(bps / 1e9).toStringAsFixed(1)} Gbps';
    if (bps >= 1e6) return '${(bps / 1e6).toStringAsFixed(1)} Mbps';
    if (bps >= 1e3) return '${(bps / 1e3).toStringAsFixed(1)} kbps';
    return '${bps.toStringAsFixed(0)} bps';
  }

  @override
  Widget build(BuildContext context) {
    final cpu = int.tryParse(_resource['cpu-load'] ?? '') ?? 0;
    final memUsed =
        _percentUsed(_resource['free-memory'], _resource['total-memory']);
    final diskUsed =
        _percentUsed(_resource['free-hdd-space'], _resource['total-hdd-space']);

    return Scaffold(
      appBar: AppBar(
        title: Text(_identity ?? widget.device.name),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _poll),
        ],
      ),
      endDrawer: _buildDrawer(context),
      body: RefreshIndicator(
        onRefresh: _poll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('Помилка: $_error'),
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_resource['board-name'] ?? '…'} • '
                      'RouterOS ${_resource['version'] ?? '…'}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text('Аптайм: ${_resource['uptime'] ?? '…'}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _gauge('CPU', cpu / 100, '$cpu%'),
            _gauge('Пам\'ять', memUsed,
                '${(memUsed * 100).toStringAsFixed(0)}%'),
            _gauge('Диск', diskUsed,
                '${(diskUsed * 100).toStringAsFixed(0)}%'),
            const SizedBox(height: 16),
            Text('Інтерфейси',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final f in _interfaces) _interfaceTile(f),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              title: Text(_identity ?? widget.device.name,
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

  Future<void> _confirmPower(BuildContext context,
      {required bool shutdown}) async {
    Navigator.pop(context); // закрити drawer
    final action = shutdown ? 'вимкнути' : 'перезавантажити';
    final confirmed = await showDialog<bool>(
      context: this.context,
      builder: (context) => AlertDialog(
        title: Text(shutdown ? 'Вимкнення' : 'Перезавантаження'),
        content: Text(
            'Точно $action роутер ${_identity ?? widget.device.host}?'),
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
    if (mounted) {
      Navigator.of(this.context).pop(); // вийти з дашборда
    }
  }

  Widget _gauge(String label, double value, String text) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(width: 80, child: Text(label)),
            Expanded(
              child: LinearProgressIndicator(
                value: value.clamp(0.0, 1.0),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(width: 48, child: Text(text, textAlign: TextAlign.end)),
          ],
        ),
      ),
    );
  }

  Widget _interfaceTile(Map<String, String> f) {
    final name = f['name'] ?? '?';
    final running = f['running'] == 'true';
    final disabled = f['disabled'] == 'true';
    final rate = _rates[name];
    return ListTile(
      dense: true,
      leading: Icon(
        Icons.circle,
        size: 12,
        color: disabled
            ? Colors.grey
            : running
                ? Colors.green
                : Colors.red,
      ),
      title: Text(name),
      subtitle: Text(f['type'] ?? ''),
      trailing: rate == null
          ? null
          : Text(
              '↑ ${_formatBps(rate.txBps)}\n↓ ${_formatBps(rate.rxBps)}',
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12),
            ),
    );
  }
}
