import 'package:flutter/material.dart';

import '../models/court_case.dart';
import '../services/api_service.dart';
import '../widgets/state_views.dart';

class HearingsScreen extends StatefulWidget {
  const HearingsScreen({super.key});

  @override
  State<HearingsScreen> createState() => _HearingsScreenState();
}

class _HearingsScreenState extends State<HearingsScreen> {
  final _api = ApiService();

  List<Hearing> _hearings = [];
  bool _loading = true;
  String? _error;

  static const _monthGen = [
    'січня', 'лютого', 'березня', 'квітня', 'травня', 'червня',
    'липня', 'серпня', 'вересня', 'жовтня', 'листопада', 'грудня',
  ];
  static const _weekdays = [
    'ПОНЕДІЛОК', 'ВІВТОРОК', 'СЕРЕДА', 'ЧЕТВЕР', 'ПʼЯТНИЦЯ', 'СУБОТА', 'НЕДІЛЯ',
  ];

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
      final hearings = await _api.getHearings();
      hearings.sort((a, b) => a.date.compareTo(b.date));
      setState(() => _hearings = hearings);
    } on Exception catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _hearings.isEmpty ? 'Засідання' : 'Засідання — ${_hearings.length} шт.';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorStateView(message: _error!, onRetry: _load);
    }
    if (_hearings.isEmpty) {
      return const EmptyStateView(
        icon: Icons.event_available,
        message: 'Немає призначених засідань по ваших справах',
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Розділяємо на майбутні (включно з сьогодні) та минулі
    final future = _hearings.where((h) => !h.date.isBefore(today)).toList();
    final past = _hearings.where((h) => h.date.isBefore(today)).toList();

    final children = <Widget>[];

    if (future.isNotEmpty) {
      // Майбутні — за зростанням дати (найближче зверху)
      _appendGrouped(children, future, ascending: true);
    }

    if (past.isNotEmpty) {
      children.add(_sectionHeader('МИНУЛІ'));
      // Минулі — за спаданням дати (найновіше зверху)
      _appendGrouped(children, past, ascending: false);
    }

    return ListView(padding: const EdgeInsets.only(bottom: 24), children: children);
  }

  /// Групує засідання по днях і додає заголовок дня + картки у [out].
  void _appendGrouped(List<Widget> out, List<Hearing> items, {required bool ascending}) {
    final byDay = <DateTime, List<Hearing>>{};
    for (final h in items) {
      byDay.putIfAbsent(h.date, () => []).add(h);
    }
    final days = byDay.keys.toList()..sort();
    if (!ascending) {
      final reversed = days.reversed.toList();
      days
        ..clear()
        ..addAll(reversed);
    }
    for (final day in days) {
      out.add(_dayHeader(day));
      for (final h in byDay[day]!) {
        out.add(_hearingCard(h));
      }
    }
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1,
            ),
      ),
    );
  }

  Widget _dayHeader(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = day.difference(today).inDays;

    String rel;
    if (diff == 0) {
      rel = 'сьогодні';
    } else if (diff == 1) {
      rel = 'завтра';
    } else if (diff > 1) {
      rel = 'через $diff дн.';
    } else if (diff == -1) {
      rel = 'вчора';
    } else {
      rel = '${-diff} дн. тому';
    }

    final weekday = _weekdays[day.weekday - 1];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '$weekday ($rel)',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _hearingCard(Hearing h) {
    final scheme = Theme.of(context).colorScheme;
    final dateStr = '${h.date.day.toString().padLeft(2, '0')}.'
        '${h.date.month.toString().padLeft(2, '0')}.'
        '${(h.date.year % 100).toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Дата + час зліва
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateStr, style: Theme.of(context).textTheme.bodyMedium),
                    if (h.time.isNotEmpty)
                      Text(
                        h.time,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                // Справа + сторони
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium,
                          children: [
                            const TextSpan(text: '№ '),
                            TextSpan(
                              text: h.caseNumber,
                              style: TextStyle(color: scheme.error, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      if (h.involved.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(h.involved, style: Theme.of(context).textTheme.bodySmall),
                      ] else if (h.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(h.description, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            // Суддя + суд знизу
            Row(
              children: [
                Icon(Icons.gavel, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    h.judges,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.account_balance, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    h.courtName + (h.room.isNotEmpty ? ' · зал ${h.room}' : ''),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
