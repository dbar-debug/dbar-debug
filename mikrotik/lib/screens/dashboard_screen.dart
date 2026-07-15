import 'package:flutter/material.dart';

import '../services/metrics_collector.dart';

/// Вкладка Dashboard сесії роутера: модель, версія, аптайм,
/// CPU / пам'ять / диск і швидкості інтерфейсів у реальному часі.
class DashboardTab extends StatelessWidget {
  final MetricsCollector collector;
  const DashboardTab({super.key, required this.collector});

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
                      Text('Аптайм: ${resource['uptime'] ?? '…'}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _gauge(context, 'CPU', cpu / 100, '$cpu%'),
              _gauge(context, 'Пам\'ять', memUsed,
                  '${(memUsed * 100).toStringAsFixed(0)}%'),
              _gauge(context, 'Диск', diskUsed,
                  '${(diskUsed * 100).toStringAsFixed(0)}%'),
              const SizedBox(height: 16),
              Text('Інтерфейси',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final f in collector.interfaces) _interfaceTile(f),
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

  Widget _interfaceTile(Map<String, String> f) {
    final name = f['name'] ?? '?';
    final running = f['running'] == 'true';
    final disabled = f['disabled'] == 'true';
    final rate = collector.rates[name];
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
              '↑ ${formatBps(rate.txBps)}\n↓ ${formatBps(rate.rxBps)}',
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12),
            ),
    );
  }
}
