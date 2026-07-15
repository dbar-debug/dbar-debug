import 'package:flutter/material.dart';

import '../models/router_device.dart';
import '../services/router_store.dart';

/// Форма додавання / редагування збереженого роутера.
class RouterFormScreen extends StatefulWidget {
  final RouterDevice? device;
  const RouterFormScreen({super.key, this.device});

  @override
  State<RouterFormScreen> createState() => _RouterFormScreenState();
}

class _RouterFormScreenState extends State<RouterFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _user;
  late final TextEditingController _password;
  late final TextEditingController _labels;
  late bool _useSsl;

  @override
  void initState() {
    super.initState();
    final d = widget.device;
    _name = TextEditingController(text: d?.name ?? '');
    _host = TextEditingController(text: d?.host ?? '');
    _port = TextEditingController(text: d?.port?.toString() ?? '');
    _user = TextEditingController(text: d?.username ?? 'admin');
    _password = TextEditingController(text: d?.password ?? '');
    _labels = TextEditingController(text: d?.labels.join(', ') ?? '');
    _useSsl = d?.useSsl ?? false;
  }

  @override
  void dispose() {
    for (final c in [_name, _host, _port, _user, _password, _labels]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final device = RouterDevice(
      id: widget.device?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      host: _host.text.trim(),
      port: int.tryParse(_port.text.trim()),
      useSsl: _useSsl,
      username: _user.text.trim(),
      password: _password.text,
      labels: _labels.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
    );
    if (widget.device == null) {
      await RouterStore.instance.add(device);
    } else {
      await RouterStore.instance.update(device);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device == null
            ? 'Новий роутер'
            : 'Редагувати роутер'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Зберегти')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Назва'),
            ),
            TextFormField(
              controller: _host,
              decoration:
                  const InputDecoration(labelText: 'IP або доменне ім\'я'),
              keyboardType: TextInputType.url,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Вкажіть адресу' : null,
            ),
            TextFormField(
              controller: _user,
              decoration: const InputDecoration(labelText: 'Ім\'я користувача'),
            ),
            TextFormField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Пароль'),
              obscureText: true,
            ),
            SwitchListTile(
              title: const Text('SSL (api-ssl)'),
              contentPadding: EdgeInsets.zero,
              value: _useSsl,
              onChanged: (v) => setState(() => _useSsl = v),
            ),
            TextFormField(
              controller: _port,
              decoration: const InputDecoration(
                labelText: 'Порт',
                helperText: 'За замовчуванням: api — 8728, api-ssl — 8729',
              ),
              keyboardType: TextInputType.number,
            ),
            TextFormField(
              controller: _labels,
              decoration: const InputDecoration(
                labelText: 'Мітки',
                helperText: 'Через кому, напр.: офіс, київ',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
