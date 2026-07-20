import 'package:flutter/material.dart';

import '../services/pushstats_api.dart';
import '../widgets/line_chart.dart';

/// Детальний екран PushStats: графіки CPU / пам'ять / диск / трафік
/// за період 3 год / 24 год / 7 днів.
class PushStatsDetailScreen extends StatefulWidget {
  final PushStatsConfig config;
  final Map<String, dynamic> router;

  const PushStatsDetailScreen(
      {super.key, required this.config, required this.router});

  @override
  State<PushStatsDetailScreen> createState() =>
      _PushStatsDetailScreenState();
}

class _PushStatsDetailScreenState extends State<PushStatsDetailScreen> {
  int _hours = 24;
  Map<String, dynamic>? _history;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final history = await PushStatsApi.history(
          widget.config, widget.router['id'] as int, _hours);
      if (!mounted) return;
      setState(() {
        _history = history;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<double> _series(String key) =>
      ((_history?[key] as List<dynamic>?) ?? const [])
          .map((v) => (v as num).toDouble())
          .toList();

  @override
  Widget build(BuildContext context) {
    final counts =
        (widget.router['counts'] as Map<String, dynamic>?) ?? const {};
    return Scaffold(
      appBar: AppBar(
          title: Text('${widget.router['identity'] ?? 'Роутер'}')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Center(
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 3, label: Text('3 год')),
                ButtonSegment(value: 24, label: Text('24 год')),
                ButtonSegment(value: 24 * 7, label: Text('7 днів')),
              ],
              selected: {_hours},
              onSelectionChanged: (s) {
                setState(() => _hours = s.first);
                _load();
              },
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Помилка: $_error',
                  textAlign: TextAlign.center),
            )
          else ...[
            _chartCard(
                'Процесор, %',
                SimpleLineChart(
                  series: [
                    ChartSeries('Used', Colors.blue, _series('cpu')),
                  ],
                  maxY: 100,
                )),
            _chartCard(
                'Пам\'ять, %',
                SimpleLineChart(
                  series: [
                    ChartSeries('Used', Colors.blue, _series('mem_pct')),
                  ],
                  maxY: 100,
                )),
            _chartCard(
                'Диск, %',
                SimpleLineChart(
                  series: [
                    ChartSeries('Used', Colors.blue, _series('disk_pct')),
                  ],
                  maxY: 100,
                )),
            _chartCard(
                'Трафік, Mbps',
                SimpleLineChart(
                  series: [
                    ChartSeries('tx', Colors.blue, _series('tx_mbps')),
                    ChartSeries(
                        'rx', Colors.deepOrange, _series('rx_mbps')),
                  ],
                  formatY: (v) => v.toStringAsFixed(1),
                )),
            if (counts.isNotEmpty)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Клієнти та лічильники',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      for (final entry in counts.entries)
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(entry.key),
                              Text('${entry.value}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _chartCard(String title, Widget chart) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            chart,
          ],
        ),
      ),
    );
  }
}
