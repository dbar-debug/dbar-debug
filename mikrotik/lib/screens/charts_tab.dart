import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/metrics_collector.dart';
import '../widgets/line_chart.dart';

/// Вкладка Charts: групи графіків — CPU, пам'ять і вибрані користувачем
/// інтерфейси (як "Группа/переключатель" у WinboxMobile).
/// Вибір інтерфейсів зберігається окремо для кожного роутера.
class ChartsTab extends StatefulWidget {
  final MetricsCollector collector;
  final String storageKey; // host роутера

  const ChartsTab(
      {super.key, required this.collector, required this.storageKey});

  @override
  State<ChartsTab> createState() => _ChartsTabState();
}

class _ChartsTabState extends State<ChartsTab> {
  List<String> _selectedIfaces = [];

  String get _prefsKey => 'chart_ifaces_${widget.storageKey}';

  @override
  void initState() {
    super.initState();
    _loadSelection();
  }

  Future<void> _loadSelection() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() =>
        _selectedIfaces = prefs.getStringList(_prefsKey) ?? const []);
  }

  Future<void> _saveSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _selectedIfaces);
  }

  Future<void> _pickInterfaces() async {
    final names = widget.collector.interfaces
        .map((f) => f['name'])
        .whereType<String>()
        .toList();
    final selected = Set<String>.from(_selectedIfaces);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Графіки інтерфейсів'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final name in names)
                  CheckboxListTile(
                    dense: true,
                    title: Text(name),
                    value: selected.contains(name),
                    onChanged: (v) => setDialogState(() {
                      if (v == true) {
                        selected.add(name);
                      } else {
                        selected.remove(name);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Скасувати')),
            FilledButton(
                onPressed: () => Navigator.pop(context, selected),
                child: const Text('Готово')),
          ],
        ),
      ),
    );
    if (result != null) {
      setState(() => _selectedIfaces =
          names.where(result.contains).toList()); // порядок як у роутера
      await _saveSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.collector,
      builder: (context, _) {
        final c = widget.collector;
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _chartCard(
              context,
              'Процесор, %',
              SimpleLineChart(
                series: [
                  ChartSeries('Used', Colors.blue, c.cpuHistory),
                ],
                maxY: 100,
              ),
            ),
            _chartCard(
              context,
              'Пам\'ять, MB',
              SimpleLineChart(
                series: [
                  ChartSeries('Used', Colors.blue, c.memUsedHistory),
                ],
                maxY: c.memTotalMb > 0 ? c.memTotalMb : null,
              ),
            ),
            for (final name in _selectedIfaces)
              _chartCard(
                context,
                'Швидкість інтерфейсу $name, Mbps',
                SimpleLineChart(
                  series: [
                    ChartSeries('tx', Colors.blue,
                        c.txHistory[name] ?? const <double>[]),
                    ChartSeries('rx', Colors.deepOrange,
                        c.rxHistory[name] ?? const <double>[]),
                  ],
                  formatY: (v) => v.toStringAsFixed(1),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _pickInterfaces,
              icon: const Icon(Icons.add),
              label: const Text('Додати діаграму інтерфейсу'),
            ),
          ],
        );
      },
    );
  }

  Widget _chartCard(BuildContext context, String title, Widget chart) {
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
