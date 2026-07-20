import 'dart:async';

import 'package:flutter/foundation.dart';

import 'routeros_client.dart';

/// Форматує біти/с у зручний вигляд.
String formatBps(double bps) {
  if (bps >= 1e9) return '${(bps / 1e9).toStringAsFixed(1)} Gbps';
  if (bps >= 1e6) return '${(bps / 1e6).toStringAsFixed(1)} Mbps';
  if (bps >= 1e3) return '${(bps / 1e3).toStringAsFixed(1)} kbps';
  return '${bps.toStringAsFixed(0)} bps';
}

class InterfaceRate {
  double rxBps = 0;
  double txBps = 0;
  int lastRx = 0;
  int lastTx = 0;
  DateTime? at;
}

/// Єдиний збирач метрик для сесії підключеного роутера.
/// Опитує /system/resource і /interface раз на 3 с та веде історію
/// для дашборда, вкладки інтерфейсів і графіків.
class MetricsCollector extends ChangeNotifier {
  final RouterOSClient client;
  MetricsCollector(this.client);

  static const int maxSamples = 60; // ~3 хвилини історії

  Timer? _timer;
  bool _polling = false;

  String? identity;
  Map<String, String> resource = {};
  List<Map<String, String>> interfaces = [];
  final Map<String, InterfaceRate> rates = {};
  final List<double> cpuHistory = []; // %
  final List<double> memUsedHistory = []; // MB
  double memTotalMb = 0;
  final Map<String, List<double>> rxHistory = {}; // Mbps за інтерфейсом
  final Map<String, List<double>> txHistory = {};

  /// Статус Ethernet-портів: name, status (link-ok/no-link), rate (1Gbps…).
  List<Map<String, String>> ethernetStatus = [];

  /// Сукупний трафік роутера (monitor-traffic aggregate), біт/с.
  double aggregateRxBps = 0;
  double aggregateTxBps = 0;

  String? error;

  void start() {
    _loadIdentity();
    refresh();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => refresh());
  }

  Future<void> _loadIdentity() async {
    try {
      final res = await client.talk(['/system/identity/print']);
      if (res.isNotEmpty) {
        identity = res.first['name'];
        notifyListeners();
      }
    } on Object {
      // не критично
    }
  }

  Future<void> refresh() async {
    if (_polling) return;
    _polling = true;
    try {
      final res = await client.talk(['/system/resource/print']);
      final ifaces = await client.talk(['/interface/print']);
      resource = res.isNotEmpty ? res.first : {};
      interfaces = ifaces;

      final now = DateTime.now();
      for (final f in ifaces) {
        final name = f['name'];
        if (name == null) continue;
        final rx = int.tryParse(f['rx-byte'] ?? '') ?? 0;
        final tx = int.tryParse(f['tx-byte'] ?? '') ?? 0;
        final rate = rates.putIfAbsent(name, InterfaceRate.new);
        if (rate.at != null) {
          final dt = now.difference(rate.at!).inMilliseconds / 1000.0;
          if (dt > 0) {
            rate.rxBps =
                ((rx - rate.lastRx) * 8 / dt).clamp(0, double.infinity);
            rate.txBps =
                ((tx - rate.lastTx) * 8 / dt).clamp(0, double.infinity);
          }
        }
        rate.lastRx = rx;
        rate.lastTx = tx;
        rate.at = now;

        _push(rxHistory.putIfAbsent(name, () => []), rate.rxBps / 1e6);
        _push(txHistory.putIfAbsent(name, () => []), rate.txBps / 1e6);
      }

      final cpu = double.tryParse(resource['cpu-load'] ?? '') ?? 0;
      _push(cpuHistory, cpu);

      final totalMem = double.tryParse(resource['total-memory'] ?? '') ?? 0;
      final freeMem = double.tryParse(resource['free-memory'] ?? '') ?? 0;
      memTotalMb = totalMem / (1024 * 1024);
      _push(memUsedHistory, (totalMem - freeMem) / (1024 * 1024));

      // Статус Ethernet-портів (лінк + узгоджена швидкість).
      try {
        final ethers = ifaces
            .where((f) => f['type'] == 'ether')
            .map((f) => f['name'])
            .whereType<String>()
            .toList();
        if (ethers.isNotEmpty) {
          ethernetStatus = await client.talk([
            '/interface/ethernet/monitor',
            '=numbers=${ethers.join(',')}',
            '=once=',
          ]);
        }
      } on Object {
        ethernetStatus = [];
      }

      // Сукупний трафік (як "aggregate" у Winbox).
      try {
        final agg = await client.talk([
          '/interface/monitor-traffic',
          '=interface=aggregate',
          '=once=',
        ]);
        if (agg.isNotEmpty) {
          aggregateRxBps =
              double.tryParse(agg.first['rx-bits-per-second'] ?? '') ?? 0;
          aggregateTxBps =
              double.tryParse(agg.first['tx-bits-per-second'] ?? '') ?? 0;
        }
      } on Object {
        // старі версії RouterOS без aggregate — не критично
      }

      error = null;
    } on Object catch (e) {
      error = e.toString();
    }
    _polling = false;
    notifyListeners();
  }

  void _push(List<double> list, double value) {
    list.add(value);
    if (list.length > maxSamples) list.removeAt(0);
  }

  /// Зупиняє опитування і закриває з'єднання (кінець сесії).
  void stopAndClose() {
    _timer?.cancel();
    _timer = null;
    client.close();
  }
}
