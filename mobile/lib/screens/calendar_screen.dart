import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/court_case.dart';
import '../services/api_service.dart';
import '../widgets/state_views.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _api = ApiService();

  Map<DateTime, List<CalendarEvent>> _eventsByDay = {};
  bool _loading = true;
  String? _error;

  late DateTime _visibleMonth;
  DateTime? _selectedDay;

  static const _monthNames = [
    'Січень', 'Лютий', 'Березень', 'Квітень', 'Травень', 'Червень',
    'Липень', 'Серпень', 'Вересень', 'Жовтень', 'Листопад', 'Грудень',
  ];
  static const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final events = await _api.getCalendarEvents();
      final map = <DateTime, List<CalendarEvent>>{};
      for (final e in events) {
        map.putIfAbsent(e.date, () => []).add(e);
      }
      setState(() => _eventsByDay = map);
    } on Exception catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  List<CalendarEvent> _eventsFor(DateTime day) =>
      _eventsByDay[DateTime(day.year, day.month, day.day)] ?? [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Календар')),
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
    return ListView(
      children: [
        _buildMonthHeader(),
        _buildWeekdayRow(),
        _buildGrid(),
        const Divider(height: 24),
        _buildSelectedDayEvents(),
      ],
    );
  }

  Widget _buildMonthHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() {
              _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1);
            }),
          ),
          Text(
            '${_monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() {
              _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayRow() {
    return Row(
      children: _weekdays
          .map((d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildGrid() {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leadingBlanks = first.weekday - 1; // Пн = 1
    final today = DateTime.now();

    final cells = <Widget>[];
    for (var i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox());
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
      final events = _eventsFor(date);
      final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
      final isSelected = _selectedDay != null &&
          date.year == _selectedDay!.year &&
          date.month == _selectedDay!.month &&
          date.day == _selectedDay!.day;
      final hasHearing = events.any((e) => e.isHearing);

      cells.add(InkWell(
        onTap: () => setState(() => _selectedDay = date),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : (isToday ? Theme.of(context).colorScheme.surfaceContainerHighest : null),
            borderRadius: BorderRadius.circular(8),
            border: isToday
                ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$day'),
              if (events.isNotEmpty)
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: hasHearing ? Colors.orange.shade700 : Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ));
    }

    // Розбиваємо на тижні по 7
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 7) {
      final week = cells.sublist(i, (i + 7 > cells.length) ? cells.length : i + 7);
      while (week.length < 7) {
        week.add(const SizedBox());
      }
      rows.add(Row(
        children: week.map((c) => Expanded(child: AspectRatio(aspectRatio: 1, child: c))).toList(),
      ));
    }
    return Column(children: rows);
  }

  Widget _buildSelectedDayEvents() {
    if (_selectedDay == null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'Оберіть день, щоб побачити події.\nОранжева крапка — засідання/слухання.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    final events = _eventsFor(_selectedDay!);
    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('Немає подій цього дня')),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Text(
            '${_selectedDay!.day}.${_selectedDay!.month.toString().padLeft(2, '0')}.${_selectedDay!.year}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ...events.map((e) => ListTile(
              leading: Icon(
                e.isHearing ? Icons.event : Icons.description_outlined,
                color: e.isHearing ? Colors.orange.shade700 : Theme.of(context).colorScheme.primary,
              ),
              title: Text(e.description),
              subtitle: Text('Справа ${e.caseNumber}\n${e.courtName}'),
              isThreeLine: true,
              onTap: e.docId.isEmpty ? null : () => _openDocument(e.docId),
            )),
      ],
    );
  }

  Future<void> _openDocument(String docId) async {
    try {
      final uri = await _api.documentFileUrl(docId);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Помилка: $e')));
      }
    }
  }
}
