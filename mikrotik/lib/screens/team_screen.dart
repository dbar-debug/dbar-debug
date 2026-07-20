import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/router_device.dart';
import '../services/router_store.dart';
import '../services/team_service.dart';

/// Вкладка "Команда": спільний список роутерів через "командний роутер".
///
/// Maintainer публікує список (без паролів) на вибраний роутер MikroTik,
/// учасники синхронізують його собі й вводять власні паролі.
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final _store = RouterStore.instance;
  RouterDevice? _teamRouter;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    _store.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    await _store.load();
    final id = await TeamService.teamRouterId();
    if (!mounted) return;
    setState(() {
      _teamRouter = id == null
          ? null
          : _store.routers
              .where((r) => r.id == id)
              .cast<RouterDevice?>()
              .firstWhere((_) => true, orElse: () => null);
    });
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickTeamRouter() async {
    final routers =
        _store.routers.where((r) => r.id != 'autosaved').toList();
    if (routers.isEmpty) {
      _snack(tr('team_need_router'));
      return;
    }
    final device = await showDialog<RouterDevice>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr('team_pick_router')),
        children: [
          for (final r in routers)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, r),
              child: Text('${r.name.isEmpty ? r.host : r.name} (${r.host})'),
            ),
        ],
      ),
    );
    if (device != null) {
      await TeamService.setTeamRouterId(device.id);
      setState(() => _teamRouter = device);
    }
  }

  Future<void> _publish() async {
    final router = _teamRouter;
    if (router == null || _busy) return;
    setState(() => _busy = true);
    try {
      await TeamService.publish(router);
      _snack(tr('team_published'));
    } on Object catch (e) {
      _snack('${tr('error')}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sync() async {
    final router = _teamRouter;
    if (router == null || _busy) return;
    setState(() => _busy = true);
    try {
      final result = await TeamService.sync(router);
      _snack('${tr('team_synced')}: +${result.added} / ~${result.updated}');
    } on Object catch (e) {
      _snack('${tr('error')}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('tab_team'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(tr('team_intro'),
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.dns),
              title: Text(tr('team_router')),
              subtitle: Text(_teamRouter == null
                  ? tr('team_not_selected')
                  : '${_teamRouter!.name.isEmpty ? _teamRouter!.host : _teamRouter!.name} '
                      '(${_teamRouter!.host})'),
              trailing: TextButton(
                onPressed: _busy ? null : _pickTeamRouter,
                child: Text(_teamRouter == null ? tr('choose') : tr('edit')),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: (_teamRouter == null || _busy) ? null : _publish,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(tr('team_publish')),
          ),
          const SizedBox(height: 8),
          Text(tr('team_publish_hint'),
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: (_teamRouter == null || _busy) ? null : _sync,
            icon: const Icon(Icons.cloud_download_outlined),
            label: Text(tr('team_sync')),
          ),
          const SizedBox(height: 8),
          Text(tr('team_sync_hint'),
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(tr('team_security'),
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
