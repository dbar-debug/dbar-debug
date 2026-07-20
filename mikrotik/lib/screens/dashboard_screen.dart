import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/metrics_collector.dart';
import '../services/routeros_client.dart';
import '../widgets/donut_chart.dart';
import 'interfaces_tab.dart';

/// Вкладка Dashboard сесії роутера: ресурси, сукупний трафік,
/// статус Ethernet-портів і діаграма типів інтерфейсів.
class DashboardTab extends StatelessWidget {
  final MetricsCollector collector;
  final RouterOSClient client;

  const DashboardTab(
      {super.key, required this.collector, required this.client});

  static const _typeColors = [
    Colors.blue,
    Colors.lightGreen,
    Colors.yellow,
    Colors.orange,
    Colors.lightBlue,
    Colors.redAccent,
    Colors.purple,
    Colors.teal,
    Colors.brown,
  ];

  double _percentUsed(String? freeStr, String? totalStr) {
    final free = int.tryParse(freeStr ?? '');
    final total = int.tryParse(totalStr ?? '');
    if (free == null || total == null || total == 0) return 0;
    return (total - free) / total;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: collector,
      builder: (context, _) {
        final resource = collector.resource;
        final cpu = int.tryParse(resource['cpu-load'] ?? '') ?? 0;
        final memUsed =
            _percentUsed(resource['free-memory'], resource['total-memory']);
        final diskUsed = _percentUsed(
            resource['free-hdd-space'], resource['total-hdd-space']);

        // Кількість інтерфейсів за типами для кільцевої діаграми.
        final typeCounts = <String, int>{};
        for (final f in collector.interfaces) {
          final type = f['type'] ?? 'інше';
          typeCounts[type] = (typeCounts[type] ?? 0) + 1;
        }
        var colorIndex = 0;
        final segments = [
          for (final entry in typeCounts.entries)
            DonutSegment(entry.key, entry.value.toDouble(),
                _typeColors[colorIndex++ % _typeColors.length]),
        ];

        return RefreshIndicator(
          onRefresh: collector.refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (collector.error != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Помилка: ${collector.error}'),
                  ),
                ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${resource['board-name'] ?? '…'} • '
                        'RouterOS ${resource['version'] ?? '…'}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text('${tr('uptime')}: ${resource['uptime'] ?? '…'}'),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('${tr('traffic')}:  '),
                          Text('↑ ${formatBps(collector.aggregateTxBps)}',
                              style: const TextStyle(color: Colors.blue)),
                          const SizedBox(width: 12),
                          Text('↓ ${formatBps(collector.aggregateRxBps)}',
                              style:
                                  const TextStyle(color: Colors.deepOrange)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _gauge(context, 'CPU', cpu / 100, '$cpu%'),
              _gauge(context, tr('memory'), memUsed,
                  '${(memUsed * 100).toStringAsFixed(0)}%'),
              _gauge(context, tr('disk'), diskUsed,
                  '${(diskUsed * 100).toStringAsFixed(0)}%'),
              if (collector.ethernetStatus.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(tr('ethernet'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      for (final e in collector.ethernetStatus)
                        _ethernetTile(context, e),
                    ],
                  ),
                ),
              ],
              if (segments.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(tr('interface_types'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: DonutChart(segments: segments),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _gauge(
      BuildContext context, String label, double value, String text) {
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

  Widget _ethernetTile(BuildContext context, Map<String, String> e) {
    final name = e['name'] ?? '?';
    final linkOk = e['status'] == 'link-ok';
    return ListTile(
      dense: true,
      leading: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: linkOk ? Colors.green.shade400 : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      title: Text(name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (linkOk && (e['rate'] ?? '').isNotEmpty)
            Text(e['rate']!,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => InterfaceDetailScreen(
          collector: collector,
          client: client,
          name: name,
        ),
      )),
    );
  }
}
