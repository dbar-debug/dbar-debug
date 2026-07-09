import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/court_case.dart';
import '../services/api_service.dart';
import '../widgets/case_list_tile.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _api = ApiService();
  final _controller = TextEditingController();

  List<CourtCase> _results = [];
  bool _loading = false;
  String? _error;
  bool _searched = false;

  Future<void> _search() async {
    final name = _controller.text.trim();
    if (name.length < 3) {
      setState(() => _error = 'Введіть ПІБ (мінімум 3 символи)');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });

    try {
      final results = await _api.searchByName(name);
      setState(() => _results = results);
    } on Exception catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Пошук у реєстрі')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'ПІБ особи',
                      hintText: 'Іваненко Іван Іванович',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _loading ? null : _search,
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (!_searched) {
      return const Center(
        child: Text('Введіть ПІБ для пошуку в Єдиному реєстрі судових рішень'),
      );
    }
    if (!_loading && _results.isEmpty && _error == null) {
      return const Center(child: Text('Нічого не знайдено'));
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final c = _results[index];
        return CaseListTile(
          courtCase: c,
          onTap: c.url.isEmpty
              ? null
              : () => launchUrl(Uri.parse(c.url), mode: LaunchMode.externalApplication),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
