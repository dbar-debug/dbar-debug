import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/router_device.dart';
import '../services/pushstats_api.dart';
import '../services/pushstats_installer.dart';
import '../services/router_store.dart';
import 'pushstats_detail_screen.dart';

/// Вкладка PushStats: пасивний моніторинг роутерів.
/// Роутери самі шлють статистику на ваш сервер (див. pushstats-server/).
class PushStatsScreen extends StatefulWidget {
  const PushStatsScreen({super.key});

  @override
  State<PushStatsScreen> createState() => _PushStatsScreenState();
}

class _PushStatsScreenState extends State<PushStatsScreen> {
  PushStatsConfig? _config;
  bool _configLoaded = false;
  List<Map<String, dynamic>> _routers = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _config = await PushStatsApi.loadConfig();
    if (!mounted) return;
    setState(() => _configLoaded = true);
    if (_config != null) await _load();
  }

  Future<void> _load() async {
    final config = _config;
    if (config == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final routers = await PushStatsApi.routers(config);
      if (!mounted) return;
      setState(() {
        _routers = routers;
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

  Future<void> _openSettings() async {
    final urlController =
        TextEditingController(text: _config?.serverUrl ?? '');
    final tokenController =
        TextEditingController(text: _config?.token ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Налаштування PushStats'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL сервера',
                hintText: 'https://ваш-домен:8443',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: tokenController,
              decoration: InputDecoration(
                labelText: 'Токен',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Згенерувати',
                      icon: const Icon(Icons.casino_outlined),
                      onPressed: () => tokenController.text =
                          PushStatsApi.generateToken(),
                    ),
                    IconButton(
                      tooltip: 'Копіювати',
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () => Clipboard.setData(
                          ClipboardData(text: tokenController.text)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Скасувати')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Зберегти')),
        ],
      ),
    );
    if (saved == true) {
      final url = urlController.text.trim();
      final token = tokenController.text.trim();
      if (url.isNotEmpty && token.isNotEmpty) {
        await PushStatsApi.saveConfig(url, token);
        _config = await PushStatsApi.loadConfig();
        setState(() {});
        await _load();
      }
    }
  }

  Future<void> _installOnRouter() async {
    final config = _config;
    if (config == null) return;
    await RouterStore.instance.load();
    final routers = RouterStore.instance.routers;
    if (routers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Спершу додайте роутер у "Збережені"')));
      return;
    }
    final device = await showDialog<RouterDevice>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Встановити моніторинг на роутер'),
        children: [
          for (final r in routers)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, r),
              child: Text('${r.name.isEmpty ? r.host : r.name} (${r.host})'),
            ),
        ],
      ),
    );
    if (device == null || !mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Expanded(child: Text('Встановлення скрипта і scheduler…')),
          ],
        ),
      ),
    );
    String? installError;
    try {
      await PushStatsInstaller.install(
        device: device,
        serverUrl: config.serverUrl,
        token: config.token,
      );
    } on Object catch (e) {
      installError = e.toString();
    }
    if (!mounted) return;
    Navigator.pop(context); // закрити прогрес
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(installError == null
          ? 'Моніторинг встановлено. Дані з\'являться за кілька хвилин.'
          : 'Помилка встановлення: $installError'),
    ));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PushStats'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'settings') _openSettings();
              if (v == 'install') _installOnRouter();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'install',
                  child: Text('Встановити на роутер')),
              const PopupMenuItem(
                  value: 'settings', child: Text('Налаштування')),
            ],
          ),
        ],
      ),
      body: !_configLoaded
          ? const Center(child: CircularProgressIndicator())
          : _config == null
              ? _setupPrompt()
              : _routerList(),
    );
  }

  Widget _setupPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.donut_large_outlined,
                size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('PushStats',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Роутери самі надсилають статистику (CPU, пам\'ять, диск, '
              'трафік, клієнти) на ваш сервер кожні 5 хвилин — і ви бачите '
              'їх стан без підключення, з алертами про проблеми.\n\n'
              '1. Розгорніть сервер: mikrotik/pushstats-server\n'
              '2. Вкажіть його URL і згенеруйте токен\n'
              '3. Встановіть моніторинг на роутери одним тапом',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _openSettings,
              child: const Text('Налаштувати'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _routerList() {
    if (_loading && _routers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _routers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Помилка: $_error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                  onPressed: _load, child: const Text('Повторити')),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: _routers.isEmpty
          ? ListView(children: const [
              SizedBox(height: 120),
              Center(
                  child: Text(
                      'Поки немає даних.\nВстановіть моніторинг на роутер '
                      '(меню ⋮).',
                      textAlign: TextAlign.center)),
            ])
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: _routers.length,
              itemBuilder: (context, i) => _routerCard(_routers[i]),
            ),
    );
  }

  String _lastSeenText(Map<String, dynamic> r) {
    final lastSeen = (r['last_seen'] as num?)?.toDouble();
    if (lastSeen == null) return '—';
    final dt =
        DateTime.fromMillisecondsSinceEpoch((lastSeen * 1000).round());
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }

  String _mb(num? bps) {
    if (bps == null) return '-';
    return '${(bps / 1e6).toStringAsFixed(1)} Mb';
  }

  Widget _routerCard(Map<String, dynamic> r) {
    final online = r['online'] == true;
    final cpu = (r['cpu_load'] as num?)?.toDouble() ?? 0;
    final mem = (r['mem_used_pct'] as num?)?.toDouble() ?? 0;
    final disk = (r['disk_used_pct'] as num?)?.toDouble() ?? 0;
    final config = _config;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: InkWell(
        onTap: config == null
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PushStatsDetailScreen(
                    config: config,
                    router: r,
                  ),
                )),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.circle,
                      size: 10, color: online ? Colors.green : Colors.red),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${r['identity'] ?? '?'}; ${r['model'] ?? ''}',
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text('${r['version'] ?? ''}',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _miniGauge('CPU', cpu),
                  const SizedBox(width: 12),
                  _miniGauge('Mem', mem),
                  const SizedBox(width: 12),
                  _miniGauge('Disk', disk),
                  const Spacer(),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Трафік  '),
                  Text('↑ ${_mb(r['agg_tx'] as num?)}',
                      style: const TextStyle(color: Colors.blue)),
                  const SizedBox(width: 8),
                  Text('↓ ${_mb(r['agg_rx'] as num?)}',
                      style: const TextStyle(color: Colors.deepOrange)),
                  const Spacer(),
                  Text(_lastSeenText(r),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniGauge(String label, double percent) {
    final color = percent >= 90
        ? Colors.red
        : percent >= 70
            ? Colors.orange
            : Colors.green;
    return Column(
      children: [
        SizedBox(
          width: 64,
          child: LinearProgressIndicator(
            value: (percent / 100).clamp(0.0, 1.0),
            minHeight: 8,
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text('$label ${percent.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
