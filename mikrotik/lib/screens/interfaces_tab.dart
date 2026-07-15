import 'package:flutter/material.dart';

import '../services/metrics_collector.dart';
import '../services/routeros_client.dart';
import '../widgets/line_chart.dart';

/// Вкладка Interfaces: інтерфейси, згруповані за типом (як у WinboxMobile),
/// з пошуком і живими швидкостями. Тап — детальний екран з графіком.
class InterfacesTab extends StatefulWidget {
  final MetricsCollector collector;
  final RouterOSClient client;

  const InterfacesTab(
      {super.key, required this.collector, required this.client});

  @override
  State<InterfacesTab> createState() => _InterfacesTabState();
}

class _InterfacesTabState extends State<InterfacesTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.collector,
      builder: (context, _) {
        final q = _query.toLowerCase();
        final filtered = widget.collector.interfaces
            .where((f) =>
                q.isEmpty ||
                (f['name'] ?? '').toLowerCase().contains(q) ||
                (f['type'] ?? '').toLowerCase().contains(q))
            .toList();

        // Групування за типом зі збереженням порядку.
        final groups = <String, List<Map<String, String>>>{};
        for (final f in filtered) {
          groups.putIfAbsent(f['type'] ?? 'інше', () => []).add(f);
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Пошук інтерфейсу…',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: widget.collector.refresh,
                child: ListView(
                  children: [
                    if (q.isEmpty) ...[
                      Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: Text('aggregate',
                            style: Theme.of(context).textTheme.titleSmall),
                      ),
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.functions, size: 18),
                        title: const Text('aggregate'),
                        trailing: Text(
                          '↑ ${formatBps(widget.collector.aggregateTxBps)}\n'
                          '↓ ${formatBps(widget.collector.aggregateRxBps)}',
                          textAlign: TextAlign.end,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                    for (final entry in groups.entries) ...[
                      Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: Text(entry.key,
                            style: Theme.of(context).textTheme.titleSmall),
                      ),
                      for (final f in entry.value) _tile(context, f),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tile(BuildContext context, Map<String, String> f) {
    final name = f['name'] ?? '?';
    final running = f['running'] == 'true';
    final disabled = f['disabled'] == 'true';
    final rate = widget.collector.rates[name];
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
      trailing: rate == null
          ? const Icon(Icons.chevron_right)
          : Text(
              '↑ ${formatBps(rate.txBps)}\n↓ ${formatBps(rate.rxBps)}',
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12),
            ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => InterfaceDetailScreen(
          collector: widget.collector,
          client: widget.client,
          name: name,
        ),
      )),
    );
  }
}

/// Детальний екран інтерфейсу: живий графік tx/rx, властивості,
/// увімкнення/вимкнення.
class InterfaceDetailScreen extends StatelessWidget {
  final MetricsCollector collector;
  final RouterOSClient client;
  final String name;

  const InterfaceDetailScreen({
    super.key,
    required this.collector,
    required this.client,
    required this.name,
  });

  static const _detailKeys = [
    'type', 'mac-address', 'mtu', 'actual-mtu', 'last-link-up-time',
    'last-link-down-time', 'link-downs', 'rx-byte', 'tx-byte', 'comment',
  ];

  Future<void> _setDisabled(BuildContext context, Map<String, String> item,
      bool disabled) async {
    final id = item['.id'];
    if (id == null) return;
    try {
      await client.talk([
        '/interface/set',
        '=.id=$id',
        '=disabled=${disabled ? 'yes' : 'no'}',
      ]);
      await collector.refresh();
    } on Object catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Помилка: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: AnimatedBuilder(
        animation: collector,
        builder: (context, _) {
          final item = collector.interfaces.firstWhere(
            (f) => f['name'] == name,
            orElse: () => const {},
          );
          final disabled = item['disabled'] == 'true';
          final rx = collector.rxHistory[name] ?? const <double>[];
          final tx = collector.txHistory[name] ?? const <double>[];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SimpleLineChart(
                    series: [
                      ChartSeries('tx, Mbps', Colors.blue, tx),
                      ChartSeries('rx, Mbps', Colors.deepOrange, rx),
                    ],
                    formatY: (v) => v.toStringAsFixed(1),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    for (final key in _detailKeys)
                      if ((item[key] ?? '').isNotEmpty)
                        ListTile(
                          dense: true,
                          title: Text(key),
                          trailing: Text(item[key]!,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w500)),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: item.isEmpty
                    ? null
                    : () => _setDisabled(context, item, !disabled),
                child: Text(disabled
                    ? 'Увімкнути інтерфейс'
                    : 'Вимкнути інтерфейс'),
              ),
            ],
          );
        },
      ),
    );
  }
}
