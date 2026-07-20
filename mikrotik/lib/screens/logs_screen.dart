import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/routeros_client.dart';

/// Журнали роутера (/log) з пошуком і підсвіткою помилок.
class LogsScreen extends StatefulWidget {
  final RouterOSClient client;
  const LogsScreen({super.key, required this.client});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<Map<String, String>> _logs = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  bool _searching = false;

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
      final logs = await widget.client.talk(['/log/print']);
      if (!mounted) return;
      setState(() {
        _logs = logs.reversed.toList(); // найновіші зверху
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

  Color? _topicColor(String topics) {
    if (topics.contains('critical') || topics.contains('error')) {
      return Colors.red;
    }
    if (topics.contains('warning')) return Colors.orange;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final logs = q.isEmpty
        ? _logs
        : _logs
            .where((l) =>
                (l['message'] ?? '').toLowerCase().contains(q) ||
                (l['topics'] ?? '').toLowerCase().contains(q))
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: tr('logs_search'),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : Text(tr('router_logs')),
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
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('${tr('error')}: $_error'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, i) {
                      final log = logs[i];
                      final topics = log['topics'] ?? '';
                      final color = _topicColor(topics);
                      return ListTile(
                        dense: true,
                        title: Text(
                          log['message'] ?? '',
                          style: TextStyle(color: color),
                        ),
                        subtitle: Text('${log['time'] ?? ''}  •  $topics'),
                      );
                    },
                  ),
                ),
    );
  }
}
