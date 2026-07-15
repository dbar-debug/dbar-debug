import 'package:flutter/material.dart';

import '../models/router_device.dart';
import '../services/router_store.dart';
import '../services/routeros_client.dart';
import 'connected_shell.dart';
import 'scan_screen.dart';

/// Вкладка "Підключення" — швидке підключення за IP, як у WinboxMobile:
/// IP, користувач, пароль, SSL, порт + сканування локальної мережі.
class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _host = TextEditingController(text: '192.168.88.1');
  final _user = TextEditingController(text: 'admin');
  final _password = TextEditingController();
  final _port = TextEditingController();
  bool _useSsl = false;
  bool _connecting = false;

  @override
  void dispose() {
    for (final c in [_host, _user, _password, _port]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _connectNow() async {
    final host = _host.text.trim();
    if (host.isEmpty || _connecting) return;
    setState(() => _connecting = true);

    final device = RouterDevice(
      id: 'autosaved',
      name: 'Auto saved',
      host: host,
      port: int.tryParse(_port.text.trim()),
      useSsl: _useSsl,
      username: _user.text.trim().isEmpty ? 'admin' : _user.text.trim(),
      password: _password.text,
    );

    final client = RouterOSClient();
    try {
      await client.connect(device.host, device.effectivePort,
          useSsl: device.useSsl);
      await client.login(device.username, device.password);
      // Успішне швидке підключення зберігаємо як "Auto saved".
      await RouterStore.instance.update(device);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ConnectedShell(client: client, device: device),
      ));
    } on Object catch (e) {
      client.close();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не вдалося підключитися: $e')),
      );
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _openScanner() async {
    final ip = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    if (ip != null && ip.isNotEmpty) {
      setState(() => _host.text = ip);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Швидке підключення')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _host,
            decoration:
                const InputDecoration(labelText: 'IP або доменне ім\'я'),
            keyboardType: TextInputType.url,
          ),
          TextField(
            controller: _user,
            decoration: const InputDecoration(
              labelText: 'Ім\'я користувача',
              hintText: 'admin',
            ),
          ),
          TextField(
            controller: _password,
            decoration: const InputDecoration(
              labelText: 'Пароль',
              hintText: 'Необов\'язковий',
            ),
            obscureText: true,
          ),
          SwitchListTile(
            title: const Text('SSL'),
            contentPadding: EdgeInsets.zero,
            value: _useSsl,
            onChanged: (v) => setState(() => _useSsl = v),
          ),
          TextField(
            controller: _port,
            decoration: const InputDecoration(
              labelText: 'Порт',
              hintText: 'Необов\'язковий',
              helperText: 'Порт за замовчуванням: api — 8728, api-ssl — 8729',
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _connecting ? null : _connectNow,
            child: _connecting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Підключитися зараз'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _openScanner,
            child: const Text('Сканування локальної мережі'),
          ),
          const SizedBox(height: 24),
          Text(
            'api / api-ssl має бути ввімкнено на роутері '
            '(IP → Services). Якщо не вдається підключитися, перевірте, '
            'що сервіс api не вимкнений і не обмежений за адресами.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
