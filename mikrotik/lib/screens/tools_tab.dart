import 'package:flutter/material.dart';

import '../services/metrics_collector.dart';
import '../services/routeros_client.dart';
import 'scan_screen.dart';

/// Вкладка Tools: Ping, Traceroute, IP Scan, Bandwidth Test, Profile —
/// інструменти виконуються на роутері через API.
class ToolsTab extends StatelessWidget {
  final RouterOSClient client;
  const ToolsTab({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    void push(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.network_ping),
          title: const Text('Ping'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => push(PingScreen(client: client)),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.route),
          title: const Text('Traceroute'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => push(TracerouteScreen(client: client)),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.radar),
          title: const Text('IP Scan (з телефона)'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => push(const ScanScreen()),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.speed),
          title: const Text('Bandwidth Test'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => push(BandwidthTestScreen(client: client)),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.pie_chart),
          title: const Text('Profile (навантаження CPU)'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => push(ProfileScreen(client: client)),
        ),
      ],
    );
  }
}

/// Ping з роутера: живий список відповідей і підсумок.
class PingScreen extends StatefulWidget {
  final RouterOSClient client;
  const PingScreen({super.key, required this.client});

  @override
  State<PingScreen> createState() => _PingScreenState();
}

class _PingScreenState extends State<PingScreen> {
  final _address = TextEditingController(text: '8.8.8.8');
  final _count = TextEditingController(text: '4');
  final List<Map<String, String>> _replies = [];
  bool _running = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _count.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final address = _address.text.trim();
    if (address.isEmpty || _running) return;
    setState(() {
      _running = true;
      _error = null;
      _replies.clear();
    });
    try {
      await widget.client.talk(
        [
          '/ping',
          '=address=$address',
          '=count=${int.tryParse(_count.text.trim()) ?? 4}',
        ],
        onReply: (reply) {
          if (mounted) setState(() => _replies.add(reply));
        },
      );
    } on Object catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _replies.isNotEmpty ? _replies.last : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Ping')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _address,
            decoration:
                const InputDecoration(labelText: 'Адреса або домен'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _count,
            decoration: const InputDecoration(labelText: 'Кількість пакетів'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _running ? null : _run,
            child: Text(_running ? 'Виконується…' : 'Ping'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Помилка: $_error',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 12),
          for (final r in _replies)
            ListTile(
              dense: true,
              leading: Text(r['seq'] ?? ''),
              title: Text(r['host'] ?? r['status'] ?? ''),
              trailing: Text(
                r['time'] ?? r['status'] ?? '',
                style: TextStyle(
                  color: (r['status'] ?? '').contains('timeout')
                      ? Theme.of(context).colorScheme.error
                      : null,
                ),
              ),
            ),
          if (!_running && last != null && last.containsKey('sent'))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Надіслано: ${last['sent']}  •  '
                  'Отримано: ${last['received']}  •  '
                  'Втрати: ${last['packet-loss']}%\n'
                  'RTT min/avg/max: ${last['min-rtt'] ?? '-'} / '
                  '${last['avg-rtt'] ?? '-'} / ${last['max-rtt'] ?? '-'}',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Traceroute з роутера. Раунди приходять секціями — показуємо останню.
class TracerouteScreen extends StatefulWidget {
  final RouterOSClient client;
  const TracerouteScreen({super.key, required this.client});

  @override
  State<TracerouteScreen> createState() => _TracerouteScreenState();
}

class _TracerouteScreenState extends State<TracerouteScreen> {
  final _address = TextEditingController(text: '8.8.8.8');
  final List<Map<String, String>> _hops = [];
  String? _section;
  bool _running = false;
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final address = _address.text.trim();
    if (address.isEmpty || _running) return;
    setState(() {
      _running = true;
      _error = null;
      _hops.clear();
      _section = null;
    });
    try {
      await widget.client.talk(
        ['/tool/traceroute', '=address=$address', '=count=1'],
        onReply: (reply) {
          if (!mounted) return;
          setState(() {
            final section = reply['.section'];
            if (section != null && section != _section) {
              _section = section;
              _hops.clear();
            }
            _hops.add(reply);
          });
        },
      );
    } on Object catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Traceroute')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _address,
            decoration:
                const InputDecoration(labelText: 'Адреса або домен'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _running ? null : _run,
            child: Text(_running ? 'Виконується…' : 'Traceroute'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Помилка: $_error',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 12),
          for (var i = 0; i < _hops.length; i++)
            ListTile(
              dense: true,
              leading: Text('${i + 1}'),
              title: Text(
                  (_hops[i]['address']?.isNotEmpty ?? false)
                      ? _hops[i]['address']!
                      : '*'),
              subtitle: Text('loss: ${_hops[i]['loss'] ?? '-'}%  •  '
                  'last: ${_hops[i]['last'] ?? '-'}'),
              trailing: Text(_hops[i]['status'] ?? ''),
            ),
        ],
      ),
    );
  }
}

/// Bandwidth Test до іншого пристрою MikroTik (btest-сервера).
class BandwidthTestScreen extends StatefulWidget {
  final RouterOSClient client;
  const BandwidthTestScreen({super.key, required this.client});

  @override
  State<BandwidthTestScreen> createState() => _BandwidthTestScreenState();
}

class _BandwidthTestScreenState extends State<BandwidthTestScreen> {
  final _address = TextEditingController();
  final _user = TextEditingController(text: 'admin');
  final _password = TextEditingController();
  final _duration = TextEditingController(text: '10');
  String _direction = 'both';
  Map<String, String> _current = {};
  bool _running = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_address, _user, _password, _duration]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run() async {
    final address = _address.text.trim();
    if (address.isEmpty || _running) return;
    setState(() {
      _running = true;
      _error = null;
      _current = {};
    });
    try {
      await widget.client.talk(
        [
          '/tool/bandwidth-test',
          '=address=$address',
          '=direction=$_direction',
          '=duration=${int.tryParse(_duration.text.trim()) ?? 10}s',
          if (_user.text.trim().isNotEmpty) '=user=${_user.text.trim()}',
          if (_password.text.isNotEmpty) '=password=${_password.text}',
        ],
        onReply: (reply) {
          if (mounted) setState(() => _current = reply);
        },
      );
    } on Object catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  String _fmt(String? bits) {
    final v = double.tryParse(bits ?? '');
    return v == null ? '-' : formatBps(v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bandwidth Test')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _address,
            decoration: const InputDecoration(
              labelText: 'Адреса btest-сервера',
              helperText: 'Інший MikroTik з увімкненим btest server',
            ),
          ),
          TextField(
            controller: _user,
            decoration:
                const InputDecoration(labelText: 'Користувач (віддалений)'),
          ),
          TextField(
            controller: _password,
            decoration: const InputDecoration(labelText: 'Пароль'),
            obscureText: true,
          ),
          TextField(
            controller: _duration,
            decoration:
                const InputDecoration(labelText: 'Тривалість, секунд'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'transmit', label: Text('TX')),
              ButtonSegment(value: 'receive', label: Text('RX')),
              ButtonSegment(value: 'both', label: Text('Обидва')),
            ],
            selected: {_direction},
            onSelectionChanged: (s) =>
                setState(() => _direction = s.first),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _running ? null : _run,
            child: Text(_running ? 'Тест триває…' : 'Почати тест'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Помилка: $_error',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 12),
          if (_current.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Статус: ${_current['status'] ?? '-'}'),
                    const SizedBox(height: 8),
                    Text('TX: ${_fmt(_current['tx-current'])}  '
                        '(сер. ${_fmt(_current['tx-total-average'])})'),
                    Text('RX: ${_fmt(_current['rx-current'])}  '
                        '(сер. ${_fmt(_current['rx-total-average'])})'),
                    if ((_current['lost-packets'] ?? '') != '')
                      Text('Втрачені пакети: ${_current['lost-packets']}'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Profile: розподіл навантаження CPU за процесами RouterOS.
class ProfileScreen extends StatefulWidget {
  final RouterOSClient client;
  const ProfileScreen({super.key, required this.client});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Map<String, String>> _rows = [];
  bool _running = false;
  String? _error;

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _error = null;
      _rows = [];
    });
    try {
      final rows =
          await widget.client.talk(['/tool/profile', '=duration=5']);
      rows.sort((a, b) => (double.tryParse(b['usage'] ?? '') ?? 0)
          .compareTo(double.tryParse(a['usage'] ?? '') ?? 0));
      if (mounted) setState(() => _rows = rows);
    } on Object catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton(
            onPressed: _running ? null : _run,
            child: Text(
                _running ? 'Збір даних (5 с)…' : 'Виміряти навантаження'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Помилка: $_error',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 12),
          for (final r in _rows)
            ListTile(
              dense: true,
              title: Text(r['name'] ?? '?'),
              subtitle: r.containsKey('cpu') ? Text('CPU: ${r['cpu']}') : null,
              trailing: Text('${r['usage'] ?? '-'}%',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
