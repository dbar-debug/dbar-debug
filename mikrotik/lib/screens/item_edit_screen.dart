import 'package:flutter/material.dart';

import '../config/menu_tree.dart';
import '../services/routeros_client.dart';

/// Універсальний редактор елемента RouterOS (як вікно правила у Winbox):
/// секції Comment/Disable | General | Advanced | Action.
/// Для таблиць без описаних полів — генеричний редактор за атрибутами.
class ItemEditScreen extends StatefulWidget {
  final RouterOSClient client;
  final MenuTable table;
  final Map<String, String>? item; // null — новий елемент

  const ItemEditScreen({
    super.key,
    required this.client,
    required this.table,
    this.item,
  });

  @override
  State<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends State<ItemEditScreen> {
  late final List<FieldSpec> _fields;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _toggles = {};
  bool _saving = false;

  // Атрибути, які не можна редагувати у генеричному режимі.
  static const _readOnlyKeys = {
    'dynamic', 'running', 'invalid', 'default', 'bound', 'active',
    'rx-byte', 'tx-byte', 'rx-packet', 'tx-packet', 'status',
    'last-seen', 'expires-after', 'uptime', 'version', 'build-time',
  };

  @override
  void initState() {
    super.initState();
    _fields = widget.table.fields ?? _genericFields();
    for (final f in _fields) {
      final value = widget.item?[f.key] ?? '';
      if (f.isToggle) {
        _toggles[f.key] = value == 'true' || value == 'yes';
      } else {
        _controllers[f.key] = TextEditingController(text: value);
      }
    }
  }

  /// Будує поля з атрибутів наявного елемента (генеричний режим).
  List<FieldSpec> _genericFields() {
    final item = widget.item;
    if (item == null) return const [];
    return [
      for (final key in item.keys)
        if (!key.startsWith('.') && !_readOnlyKeys.contains(key))
          FieldSpec(
            key,
            key,
            isToggle: item[key] == 'true' || item[key] == 'false',
          ),
    ];
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _valueOf(FieldSpec f) {
    if (f.isToggle) {
      return (_toggles[f.key] ?? false) ? 'yes' : 'no';
    }
    return _controllers[f.key]?.text ?? '';
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final path = widget.table.apiPath;
    final item = widget.item;
    try {
      final words = <String>[];
      if (item == null) {
        // новий елемент — надсилаємо лише заповнені поля
        words.add('$path/add');
        for (final f in _fields) {
          final v = _valueOf(f);
          if (f.isToggle || v.isNotEmpty) words.add('=${f.key}=$v');
        }
      } else {
        // зміна — надсилаємо лише змінені поля
        words.add('$path/set');
        final id = item['.id'];
        if (id != null) words.add('=.id=$id');
        var changed = false;
        for (final f in _fields) {
          final oldRaw = item[f.key] ?? '';
          final oldValue = f.isToggle
              ? ((oldRaw == 'true' || oldRaw == 'yes') ? 'yes' : 'no')
              : oldRaw;
          final v = _valueOf(f);
          if (v != oldValue) {
            words.add('=${f.key}=$v');
            changed = true;
          }
        }
        if (!changed) {
          if (mounted) Navigator.of(context).pop();
          return;
        }
      }
      await widget.client.talk(words);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Помилка: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Групування полів за секціями зі збереженням порядку.
    final sections = <String, List<FieldSpec>>{};
    for (final f in _fields) {
      sections.putIfAbsent(f.section, () => []).add(f);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null
            ? '${widget.table.title}: новий'
            : widget.table.title),
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: _fields.isEmpty
          ? const Center(child: Text('Немає полів для редагування'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final entry in sections.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      entry.key,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.primary),
                    ),
                  ),
                  for (final f in entry.value)
                    f.isToggle
                        ? SwitchListTile(
                            title: Text(f.label),
                            contentPadding: EdgeInsets.zero,
                            value: _toggles[f.key] ?? false,
                            onChanged: (v) =>
                                setState(() => _toggles[f.key] = v),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: TextField(
                              controller: _controllers[f.key],
                              decoration: InputDecoration(
                                labelText: f.label,
                                helperText: f.hint,
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                ],
              ],
            ),
    );
  }
}
