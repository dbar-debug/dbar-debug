import 'package:flutter/material.dart';

import '../services/routeros_client.dart';

class _ClientSource {
  final String label;
  final String path;
  final List<String> fields; // поля картки
  const _ClientSource(this.label, this.path, this.fields);
}

/// Вкладка Clients: ключові клієнти роутера — DHCP leases,
/// wireless registration, PPP active, hotspot active.
class ClientsTab extends StatefulWidget {
  final RouterOSClient client;
  const ClientsTab({super.key, required this.client});

  @override
  State<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends State<ClientsTab> {
  static const _sources = [
    _ClientSource('DHCP', '/ip/dhcp-server/lease',
        ['address', 'mac-address', 'host-name', 'status', 'last-seen']),
    _ClientSource('Wireless', '/interface/wireless/registration-table',
        ['interface', 'mac-address', 'signal-strength', 'uptime']),
    _ClientSource('PPP', '/ppp/active',
        ['name', 'address', 'service', 'uptime']),
    _ClientSource('Hotspot', '/ip/hotspot/active',
        ['user', 'address', 'mac-address', 'uptime']),
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

  @override
  Widget build(BuildContext context) {
    final source = _sources[_sourceIndex];
    final q = _query.toLowerCase();
    final items = q.isEmpty
        ? _items
        : _items
            .where((i) =>
                i.values.any((v) => v.toLowerCase().contains(q)))
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
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Пошук клієнта…',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Всього: ${items.length}',
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
                          'Помилка: $_error\n\n(Можливо, пакет не '
                          'встановлений на цьому роутері)',
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
                          : ListView.builder(
                              itemCount: items.length,
                              itemBuilder: (context, i) =>
                                  _card(source, items[i]),
                            ),
                    ),
        ),
      ],
    );
  }

  Widget _card(_ClientSource source, Map<String, String> item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (final key in source.fields)
              if ((item[key] ?? '').isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(key,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        )),
                    Flexible(
                      child: Text(item[key]!,
                          textAlign: TextAlign.end,
                          style:
                              const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}
