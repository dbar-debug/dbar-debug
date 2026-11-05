import 'package:flutter/material.dart';

import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _controller = TextEditingController();
  final _tokenController = TextEditingController();
  bool _tokenVisible = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final url = await ApiService.getBaseUrl();
    _controller.text = url;
    _tokenController.text = await ApiService.getApiToken();
    setState(() {});
  }

  Future<void> _save() async {
    await ApiService.setBaseUrl(_controller.text);
    await ApiService.setApiToken(_tokenController.text);
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Налаштування')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Адреса сервера (бекенду)'),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'https://court-app.duckdns.org',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            const Text('Токен доступу (API_TOKEN із .env на сервері)'),
            const SizedBox(height: 8),
            TextField(
              controller: _tokenController,
              obscureText: !_tokenVisible,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_tokenVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _tokenVisible = !_tokenVisible),
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _save, child: const Text('Зберегти')),
            if (_saved) ...[
              const SizedBox(height: 8),
              const Text('Збережено', style: TextStyle(color: Colors.green)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _tokenController.dispose();
    super.dispose();
  }
}
