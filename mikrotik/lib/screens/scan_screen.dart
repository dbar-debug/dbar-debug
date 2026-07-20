import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';

/// Сканування локальної мережі: перебирає адреси x.x.x.1–254 і шукає
/// відкритий порт RouterOS API (8728). Повертає вибрану IP через pop().
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _subnet = TextEditingController(text: '192.168.88');
  final List<String> _found = [];
  bool _scanning = false;
  int _progress = 0;

  @override
  void dispose() {
    _subnet.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final base = _subnet.text.trim().replaceAll(RegExp(r'\.$'), '');
    if (base.split('.').length != 3 || _scanning) return;
    setState(() {
      _scanning = true;
      _progress = 0;
      _found.clear();
    });

    // Скануємо пачками по 32 хости, щоб не відкривати 254 сокети одразу.
    const batchSize = 32;
    for (var start = 1; start <= 254 && mounted && _scanning; start += batchSize) {
      final end = (start + batchSize - 1).clamp(1, 254);
      await Future.wait([
        for (var i = start; i <= end; i++) _probe('$base.$i'),
      ]);
      if (!mounted) return;
      setState(() => _progress = end);
    }
    if (mounted) setState(() => _scanning = false);
  }

  Future<void> _probe(String ip) async {
    try {
      final socket = await Socket.connect(ip, 8728,
          timeout: const Duration(milliseconds: 500));
      socket.destroy();
      if (mounted) setState(() => _found.add(ip));
    } on Object {
      // порт закритий або хост недоступний — пропускаємо
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('scan_title'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subnet,
                    decoration: InputDecoration(
                      labelText: tr('subnet'),
                      helperText: tr('subnet_hint'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _scanning
                      ? () => setState(() => _scanning = false)
                      : _scan,
                  child: Text(_scanning ? tr('stop') : tr('scan')),
                ),
              ],
            ),
          ),
          if (_scanning) LinearProgressIndicator(value: _progress / 254),
          Expanded(
            child: _found.isEmpty
                ? Center(
                    child: Text(
                        _scanning ? tr('scanning') : tr('scan_none')),
                  )
                : ListView.builder(
                    itemCount: _found.length,
                    itemBuilder: (context, i) => ListTile(
                      leading: const Icon(Icons.router_outlined),
                      title: Text(_found[i]),
                      subtitle: const Text('RouterOS API (8728)'),
                      onTap: () => Navigator.of(context).pop(_found[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
