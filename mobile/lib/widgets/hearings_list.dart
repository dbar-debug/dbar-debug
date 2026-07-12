import 'package:flutter/material.dart';

import '../models/court_case.dart';

/// Список засідань зі згортними секціями «Майбутні» / «Минулі»,
/// згрупованими по днях. Використовується і для особистих засідань,
/// і для результатів пошуку за ПІБ.
class HearingsList extends StatelessWidget {
  final List<Hearing> hearings;

  const HearingsList({super.key, required this.hearings});

  static const _weekdays = [
    'ПОНЕДІЛОК', 'ВІВТОРОК', 'СЕРЕДА', 'ЧЕТВЕР', 'ПʼЯТНИЦЯ', 'СУБОТА', 'НЕДІЛЯ',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final future = hearings.where((h) => !h.date.isBefore(today)).toList()
      ..sort((a, b) => _cmp(a, b));
    final past = hearings.where((h) => h.date.isBefore(today)).toList()
      ..sort((a, b) => _cmp(b, a)); // найновіші минулі зверху

    final sections = <Widget>[];

    if (future.isNotEmpty) {
      sections.add(_expansionSection(
        context,
        title: 'Майбутні засідання',
        count: future.length,
        children: _grouped(context, future),
        initiallyExpanded: true,
      ));
    }
    if (past.isNotEmpty) {
      sections.add(_expansionSection(
        context,
        title: 'Минулі засідання',
        count: past.length,
        children: _grouped(context, past, descending: true),
        initiallyExpanded: false,
      ));
    }

    return ListView(padding: const EdgeInsets.only(bottom: 24), children: sections);
  }

  int _cmp(Hearing a, Hearing b) {
    final d = a.date.compareTo(b.date);
    return d != 0 ? d : a.time.compareTo(b.time);
  }

  List<Widget> _grouped(BuildContext context, List<Hearing> items, {bool descending = false}) {
    final byDay = <DateTime, List<Hearing>>{};
    for (final h in items) {
      byDay.putIfAbsent(h.date, () => []).add(h);
    }
    var days = byDay.keys.toList()..sort();
    if (descending) days = days.reversed.toList();

    final out = <Widget>[];
    for (final day in days) {
      out.add(_dayHeader(context, day));
      for (final h in byDay[day]!) {
        out.add(_hearingCard(context, h));
      }
    }
    return out;
  }

  Widget _expansionSection(
    BuildContext context, {
    required String title,
    required int count,
    required List<Widget> children,
    required bool initiallyExpanded,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        title: Row(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: children,
      ),
    );
  }

  Widget _dayHeader(BuildContext context, DateTime day) {
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

  Widget _hearingCard(BuildContext context, Hearing h) {
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
            if (h.judges.isNotEmpty) ...[
              const Divider(height: 20),
              Row(
                children: [
                  Icon(Icons.gavel, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(child: Text(h.judges, style: Theme.of(context).textTheme.bodySmall)),
                ],
              ),
            ],
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
