import 'package:flutter/material.dart';

import '../config/menu_tree.dart';
import '../services/routeros_client.dart';
import 'item_edit_screen.dart';

/// Універсальний список елементів таблиці RouterOS (як у Winbox):
/// пошук, картки з ключовими полями, enable/disable/delete,
/// пакетні дії через довге натискання, додавання через "+".
class ItemListScreen extends StatefulWidget {
  final RouterOSClient client;
  final MenuTable table;

  const ItemListScreen({super.key, required this.client, required this.table});

  @override
  State<ItemListScreen> createState() => _ItemListScreenState();
}

class _ItemListScreenState extends State<ItemListScreen> {
  List<Map<String, String>> _items = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  bool _searching = false;
  final Set<String> _selected = {}; // .id вибраних (пакетний режим)

  MenuTable get table => widget.table;

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
      final items = await widget.client.talk(['${table.apiPath}/print']);
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _run(List<String> words) async {
    try {
      await widget.client.talk(words);
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Помилка: $e')));
    }
    await _load();
  }

  Future<void> _setDisabled(Iterable<String> ids, bool disabled) async {
    for (final id in ids) {
      await _run([
        '${table.apiPath}/set',
        '=.id=$id',
        '=disabled=${disabled ? 'yes' : 'no'}',
      ]);
    }
    setState(_selected.clear);
  }

  Future<void> _remove(Iterable<String> ids) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Видалити?'),
        content: Text('Буде видалено елементів: ${ids.length}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Скасувати')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Видалити')),
        ],
      ),
    );
    if (confirmed != true) return;
    for (final id in ids) {
      await _run(['${table.apiPath}/remove', '=.id=$id']);
    }
    setState(_selected.clear);
  }

  Future<void> _openEditor(Map<String, String>? item) async {
    if (table.readOnly) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ItemEditScreen(
        client: widget.client,
        table: table,
        item: item,
      ),
    ));
    await _load();
  }

  bool get _selectionMode => _selected.isNotEmpty;

  List<Map<String, String>> get _filtered => _query.isEmpty
      ? _items
      : _items
          .where((item) => item.values
              .any((v) => v.toLowerCase().contains(_query.toLowerCase())))
          .toList();

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    final canAdd = table.canAdd &&
        (_items.isEmpty || _items.first.containsKey('.id'));

    return Scaffold(
      appBar: _selectionMode ? _selectionAppBar() : _normalAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Помилка: $_error',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                            onPressed: _load,
                            child: const Text('Повторити')),
                      ],
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
                          itemBuilder: (context, i) => _itemCard(items[i]),
                        ),
                ),
      floatingActionButton: canAdd && !_selectionMode
          ? FloatingActionButton(
              onPressed: () => _openEditor(null),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  AppBar _normalAppBar() {
    return AppBar(
      title: _searching
          ? TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Пошук…',
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _query = v),
            )
          : Text(table.title),
      actions: [
        IconButton(
          icon: Icon(_searching ? Icons.close : Icons.search),
          onPressed: () => setState(() {
            _searching = !_searching;
            _query = '';
          }),
        ),
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
      ],
    );
  }

  AppBar _selectionAppBar() {
    final all = _filtered
        .map((e) => e['.id'])
        .whereType<String>()
        .toSet();
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => setState(_selected.clear),
      ),
      title: Text('Вибрано: ${_selected.length}'),
      actions: [
        IconButton(
          tooltip: 'Вибрати все',
          icon: const Icon(Icons.select_all),
          onPressed: () => setState(() => _selected
            ..clear()
            ..addAll(all)),
        ),
        IconButton(
          tooltip: 'Увімкнути',
          icon: const Icon(Icons.play_arrow),
          onPressed: () => _setDisabled(_selected.toList(), false),
        ),
        IconButton(
          tooltip: 'Вимкнути',
          icon: const Icon(Icons.pause),
          onPressed: () => _setDisabled(_selected.toList(), true),
        ),
        IconButton(
          tooltip: 'Видалити',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _remove(_selected.toList()),
        ),
      ],
    );
  }

  Widget _itemCard(Map<String, String> item) {
    final id = item['.id'];
    final disabled = item['disabled'] == 'true';
    final comment = item['comment'];
    final selected = id != null && _selected.contains(id);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: selected
          ? Theme.of(context).colorScheme.secondaryContainer
          : null,
      child: InkWell(
        onTap: _selectionMode && id != null
            ? () => setState(() =>
                selected ? _selected.remove(id) : _selected.add(id))
            : () => _openEditor(item),
        onLongPress: !table.readOnly && id != null
            ? () => setState(() => _selected.add(id))
            : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (comment != null && comment.isNotEmpty)
                Text(
                  ';;; $comment',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              for (final col in table.columns)
                if ((item[col] ?? '').isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(col,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 13,
                          )),
                      Flexible(
                        child: Text(item[col]!,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
              if (item.containsKey('disabled'))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: disabled ? Colors.grey : Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      disabled ? 'disabled' : 'enabled',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
