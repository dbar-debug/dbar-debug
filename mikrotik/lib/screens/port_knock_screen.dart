import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/strings.dart';

/// Port Knocking — послідовність "стуків" по портах перед підключенням,
/// щоб роутер тимчасово відкрив доступ (правила firewall з address-list).
class PortKnockScreen extends StatefulWidget {
  final String? host;
  const PortKnockScreen({super.key, this.host});

  @override
  State<PortKnockScreen> createState() => _PortKnockScreenState();
}

class _PortKnockScreenState extends State<PortKnockScreen> {
  late final TextEditingController _host =
      TextEditingController(text: widget.host ?? '');
  final _ports = TextEditingController(text: '1000, 2000, 3000');
  final _delay = TextEditingController(text: '500');
  bool _udp = false;
  bool _knocking = false;
  String? _status;

  @override
  void dispose() {
    for (final c in [_host, _ports, _delay]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _knock() async {
    final host = _host.text.trim();
    final ports = _ports.text
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toList();
    final delayMs = int.tryParse(_delay.text.trim()) ?? 500;
    if (host.isEmpty || ports.isEmpty || _knocking) return;

    setState(() {
      _knocking = true;
      _status = null;
    });
    try {
      for (final port in ports) {
        if (!mounted) return;
        setState(() => _status = 'Стук: $host:$port…');
        if (_udp) {
          final socket =
              await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
          final addresses = await InternetAddress.lookup(host);
          socket.send(const [0], addresses.first, port);
          socket.close();
        } else {
          try {
            final socket = await Socket.connect(host, port,
                timeout: const Duration(milliseconds: 700));
            socket.destroy();
          } on Object {
            // Порт закритий — це нормально: firewall фіксує саму спробу.
          }
        }
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
      if (mounted) {
        setState(() => _status = tr('pk_done'));
      }
    } on Object catch (e) {
      if (mounted) setState(() => _status = '${tr('error')}: $e');
    } finally {
      if (mounted) setState(() => _knocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('port_knocking'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _host,
            decoration: InputDecoration(labelText: tr('field_host')),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _ports,
            decoration: InputDecoration(
              labelText: tr('pk_ports'),
              helperText: tr('pk_ports_hint'),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _delay,
            decoration: InputDecoration(labelText: tr('pk_delay')),
            keyboardType: TextInputType.number,
          ),
          SwitchListTile(
            title: Text(tr('pk_udp')),
            contentPadding: EdgeInsets.zero,
            value: _udp,
            onChanged: (v) => setState(() => _udp = v),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _knocking ? null : _knock,
            child: Text(_knocking ? tr('pk_knocking') : tr('pk_knock')),
          ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(_status!, textAlign: TextAlign.center),
            ),
          const SizedBox(height: 24),
          Text(
            tr('pk_hint'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
