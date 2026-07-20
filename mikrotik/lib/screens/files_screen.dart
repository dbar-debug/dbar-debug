import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/routeros_client.dart';

/// Файли роутера: створення backup/export, перегляд, відновлення, видалення.
///
/// Працює через RouterOS API:
///  - `/system/backup/save`   — бінарний backup (.backup)
///  - `/export`               — текстовий експорт конфігурації (.rsc)
///  - `/system/backup/load`   — відновлення (роутер перезавантажиться)
///  - `/file/print|remove`    — список і видалення
class FilesScreen extends StatefulWidget {
  final RouterOSClient client;
  const FilesScreen({super.key, required this.client});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  List<Map<String, String>> _files = [];
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
      final files = await widget.client.talk(['/file/print']);
      if (!mounted) return;
      setState(() {
        _files = files;
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

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  Future<String?> _askName(String title, String defaultName) async {
    final controller = TextEditingController(text: defaultName);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: tr('backup_name')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('cancel'))),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(context, controller.text.trim()),
              child: Text(tr('save'))),
        ],
      ),
    );
  }

  String _stamp() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}';
  }

  Future<void> _createBackup() async {
    final name = await _askName(tr('create_backup'), 'backup-${_stamp()}');
    if (name == null || name.isEmpty) return;
    try {
      await widget.client.talk(['/system/backup/save', '=name=$name']);
      _snack(tr('backup_created'));
    } on Object catch (e) {
      _snack('${tr('error')}: $e');
    }
    await _load();
  }

  Future<void> _createExport() async {
    final name = await _askName(tr('create_export'), 'export-${_stamp()}');
    if (name == null || name.isEmpty) return;
    try {
      await widget.client.talk(['/export', '=file=$name']);
      _snack(tr('export_created'));
    } on Object catch (e) {
      _snack('${tr('error')}: $e');
    }
    await _load();
  }

  Future<void> _restore(Map<String, String> file) async {
    final name = file['name'] ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('restore_backup')),
        content: Text('$name\n\n${tr('restore_q')}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('restore'))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      // ім'я передаємо без розширення .backup
      final base = name.replaceAll(RegExp(r'\.backup$'), '');
      await widget.client.talk(['/system/backup/load', '=name=$base']);
    } on Object {
      // роутер перезавантажується — обрив з'єднання очікуваний
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _remove(Map<String, String> file) async {
    final id = file['.id'];
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('delete')),
        content: Text(file['name'] ?? ''),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('delete'))),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.client.talk(['/file/remove', '=.id=$id']);
    } on Object catch (e) {
      _snack('${tr('error')}: $e');
    }
    await _load();
  }

  Future<void> _viewContent(Map<String, String> file) async {
    final id = file['.id'];
    if (id == null) return;
    String content = file['contents'] ?? '';
    try {
      final res =
          await widget.client.talk(['/file/print', '=.id=$id', '=detail=']);
      if (res.isNotEmpty) content = res.first['contents'] ?? content;
    } on Object {
      // лишаємо те, що є
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Text(file['name'] ?? '',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SelectableText(
              content.isEmpty ? '—' : content,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  String _size(String? bytes) {
    final v = int.tryParse(bytes ?? '');
    if (v == null) return '';
    if (v >= 1 << 20) return '${(v / (1 << 20)).toStringAsFixed(1)} MB';
    if (v >= 1 << 10) return '${(v / (1 << 10)).toStringAsFixed(1)} KB';
    return '$v B';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('files_title')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _createBackup,
                    icon: const Icon(Icons.save_alt),
                    label: Text(tr('create_backup')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _createExport,
                    icon: const Icon(Icons.description_outlined),
                    label: Text(tr('create_export')),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text('${tr('error')}: $_error'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _files.isEmpty
                            ? ListView(children: [
                                const SizedBox(height: 120),
                                Center(child: Text(tr('empty'))),
                              ])
                            : ListView.separated(
                                itemCount: _files.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, i) =>
                                    _fileTile(_files[i]),
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _fileTile(Map<String, String> file) {
    final name = file['name'] ?? '?';
    final isBackup = name.endsWith('.backup');
    final isText = name.endsWith('.rsc') || name.endsWith('.txt');
    return ListTile(
      leading: Icon(isBackup
          ? Icons.archive_outlined
          : isText
              ? Icons.description_outlined
              : Icons.insert_drive_file_outlined),
      title: Text(name),
      subtitle: Text(
          '${_size(file['size'])}  •  ${file['creation-time'] ?? ''}'),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'restore') _restore(file);
          if (v == 'view') _viewContent(file);
          if (v == 'delete') _remove(file);
        },
        itemBuilder: (_) => [
          if (isBackup)
            PopupMenuItem(value: 'restore', child: Text(tr('restore'))),
          if (isText || (file['contents'] ?? '').isNotEmpty)
            PopupMenuItem(value: 'view', child: Text(tr('view_content'))),
          PopupMenuItem(value: 'delete', child: Text(tr('delete'))),
        ],
      ),
    );
  }
}
