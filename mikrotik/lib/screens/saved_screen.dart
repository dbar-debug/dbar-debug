import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/router_device.dart';
import '../services/router_store.dart';
import '../services/routeros_client.dart';
import 'connected_shell.dart';
import 'router_form_screen.dart';

/// Вкладка "Збережені" — список збережених роутерів з пошуком,
/// перетягуванням і швидким підключенням по тапу.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  final _store = RouterStore.instance;
  String _query = '';
  bool _searching = false;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() => setState(() {});

  Future<void> _connectTo(RouterDevice device) async {
    if (_connecting) return;
    setState(() => _connecting = true);
    final client = RouterOSClient();
    try {
      await client.connect(device.host, device.effectivePort,
          useSsl: device.useSsl);
      await client.login(device.username, device.password);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ConnectedShell(client: client, device: device),
      ));
    } on Object catch (e) {
      client.close();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('connect_failed')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final routers =
        _store.routers.where((r) => _query.isEmpty || r.matches(_query)).toList();

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: tr('saved_search_hint'),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : Text(tr('tab_saved')),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              _query = '';
            }),
          ),
        ],
      ),
      body: _connecting
          ? const Center(child: CircularProgressIndicator())
          : routers.isEmpty
              ? Center(
                  child: Text(
                    tr('saved_empty'),
                    textAlign: TextAlign.center,
                  ),
                )
              : ReorderableListView.builder(
                  itemCount: routers.length,
                  onReorder: (oldIndex, newIndex) {
                    if (_query.isNotEmpty) return; // порядок лише без фільтра
                    _store.reorder(oldIndex, newIndex);
                  },
                  itemBuilder: (context, i) {
                    final r = routers[i];
                    return ListTile(
                      key: ValueKey(r.id),
                      title: Text(r.name.isEmpty ? r.host : r.name),
                      subtitle: Text(
                          '${r.host}${r.labels.isEmpty ? '' : '  •  ${r.labels.join(', ')}'}'),
                      leading: const Icon(Icons.router_outlined),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Chip(
                            label: Text(r.useSsl ? 'API-SSL' : 'API',
                                style: const TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        RouterFormScreen(device: r),
                                  ),
                                );
                              } else if (v == 'delete') {
                                await _store.remove(r.id);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                  value: 'edit', child: Text(tr('edit'))),
                              PopupMenuItem(
                                  value: 'delete', child: Text(tr('delete'))),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => _connectTo(r),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RouterFormScreen()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
