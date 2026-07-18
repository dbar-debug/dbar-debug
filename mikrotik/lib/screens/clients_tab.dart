import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/routeros_client.dart';

class _ClientSource {
  final String label;
  final String path;
  final String titleKey;
  final String? fallbackTitleKey;
  final String subtitleKey;
  final String trailingTopKey;
  final String trailingBottomKey;
  final String? signalKey; // рівень сигналу (wireless)
  final String removeLabelKey; // ключ локалізації дії видалення

  const _ClientSource(
    this.label,
    this.path, {
    required this.titleKey,
    this.fallbackTitleKey,
    required this.subtitleKey,
    required this.trailingTopKey,
    required this.trailingBottomKey,
    this.signalKey,
    required this.removeLabelKey,
  });
}

/// Вкладка Clients: DHCP | Wireless | Hotspot | PPP — як у WinboxMobile.
/// Тап відкриває деталі клієнта з можливістю видалити/роз'єднати.
class ClientsTab extends StatefulWidget {
  final RouterOSClient client;
  const ClientsTab({super.key, required this.client});

  @override
  State<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends State<ClientsTab> {
  static const _sources = [
    _ClientSource('DHCP', '/ip/dhcp-server/lease',
        titleKey: 'address',
        subtitleKey: 'mac-address',
        trailingTopKey: 'server',
        trailingBottomKey: 'host-name',
        removeLabelKey: 'remove_lease'),
    _ClientSource('Wireless', '/interface/wireless/registration-table',
        titleKey: 'last-ip',
        fallbackTitleKey: 'mac-address',
        subtitleKey: 'mac-address',
        trailingTopKey: 'interface',
        trailingBottomKey: 'uptime',
        signalKey: 'signal-strength',
        removeLabelKey: 'disconnect'),
    _ClientSource('Hotspot', '/ip/hotspot/active',
        titleKey: 'user',
        subtitleKey: 'address',
        trailingTopKey: 'server',
        trailingBottomKey: 'uptime',
        removeLabelKey: 'end_session'),
    _ClientSource('PPP', '/ppp/active',
        titleKey: 'name',
        subtitleKey: 'address',
        trailingTopKey: 'service',
        trailingBottomKey: 'uptime',
        removeLabelKey: 'disconnect'),
  ];

  int _sourceIndex = 0;
  List<Map<String, String>> _items = [];
  bool _loading = false;
  String? _error;
  String _query = '';

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
      final items =
          await widget.client.talk(['${_sources[_sourceIndex].path}/print']);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _items = [];
        _loading = false;
      });
    }
  }

  /// Витягує dBm з рядка виду "-65@HT20" або "-65".
  int? _signalDbm(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final match = RegExp(r'-?\d+').firstMatch(raw);
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  Widget _signalIcon(int dbm) {
    final Color color;
    final IconData icon;
    if (dbm >= -60) {
      color = Colors.green;
      icon = Icons.signal_cellular_alt;
    } else if (dbm >= -75) {
      color = Colors.orange;
      icon = Icons.signal_cellular_alt_2_bar;
    } else {
      color = Colors.red;
      icon = Icons.signal_cellular_alt_1_bar;
    }
    return Icon(icon, color: color, size: 22);
  }

  Future<void> _showDetail(
      _ClientSource source, Map<String, String> item) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text('${source.label}: '
                '${item[source.titleKey] ?? item[source.fallbackTitleKey ?? ''] ?? ''}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final entry in item.entries)
              if (!entry.key.startsWith('.') && entry.value.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 140,
                        child: Text(entry.key,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            )),
                      ),
                      Expanded(
                        child: Text(entry.value,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 16),
            if (item['.id'] != null)
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => _remove(source, item),
                child: Text(tr(source.removeLabelKey)),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _remove(_ClientSource source, Map<String, String> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(source.removeLabelKey)),
        content: Text('${item[source.titleKey] ?? ''} '
            '(${item[source.subtitleKey] ?? ''})'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('yes'))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.client
          .talk(['${source.path}/remove', '=.id=${item['.id']}']);
      if (mounted) Navigator.pop(context); // закрити деталі
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Помилка: $e')));
      }
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final source = _sources[_sourceIndex];
    final q = _query.toLowerCase();
    final items = q.isEmpty
        ? _items
        : _items
            .where(
                (i) => i.values.any((v) => v.toLowerCase().contains(q)))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: SegmentedButton<int>(
            segments: [
              for (var i = 0; i < _sources.length; i++)
                ButtonSegment(value: i, label: Text(_sources[i].label)),
            ],
            selected: {_sourceIndex},
            onSelectionChanged: (s) {
              setState(() => _sourceIndex = s.first);
              _load();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: tr('client_search'),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('${tr('total')}: ${items.length}',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          '${tr('error')}: $_error\n\n${tr('pkg_missing')}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: items.isEmpty
                          ? ListView(children: const [
                              SizedBox(height: 120),
                              Center(child: Text('Порожньо')),
                            ])
                          : ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) =>
                                  _tile(source, items[i]),
                            ),
                    ),
        ),
      ],
    );
  }

  Widget _tile(_ClientSource source, Map<String, String> item) {
    final title = item[source.titleKey] ??
        item[source.fallbackTitleKey ?? ''] ??
        '?';
    final dbm = source.signalKey == null
        ? null
        : _signalDbm(item[source.signalKey!]);
    return ListTile(
      leading: dbm == null ? null : _signalIcon(dbm),
      title: Text(title),
      subtitle: Text(item[source.subtitleKey] ?? ''),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item[source.trailingTopKey] ?? '',
                  style: const TextStyle(fontSize: 13)),
              Text(item[source.trailingBottomKey] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
            ],
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => _showDetail(source, item),
    );
  }
}
