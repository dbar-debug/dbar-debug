import 'package:flutter/material.dart';

import '../models/court_case.dart';
import '../services/api_service.dart';
import '../widgets/hearings_list.dart';
import '../widgets/state_views.dart';

/// Пошук судових засідань за ПІБ у відкритих даних (без КЕП).
/// Будь-хто вводить прізвище/ім'я — бачить призначені засідання.
class HearingsSearchScreen extends StatefulWidget {
  const HearingsSearchScreen({super.key});

  @override
  State<HearingsSearchScreen> createState() => _HearingsSearchScreenState();
}

class _HearingsSearchScreenState extends State<HearingsSearchScreen> {
  final _api = ApiService();
  final _controller = TextEditingController();

  List<Hearing> _results = [];
  bool _loading = false;
  String? _error;
  bool _searched = false;

  Future<void> _search() async {
    final name = _controller.text.trim();
    if (name.length < 5) {
      setState(() {
        _error = 'Введіть повне ПІБ (мінімум 5 символів)';
        _searched = false;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });
    try {
      final results = await _api.getHearingsByName(name);
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
      appBar: AppBar(title: const Text('Засідання за ПІБ')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      labelText: 'ПІБ особи',
                      hintText: 'Прізвище Ім\'я По батькові',
                      border: const OutlineInputBorder(),
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _controller,
                        builder: (context, value, _) {
                          if (value.text.isEmpty) return const SizedBox.shrink();
                          return IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _controller.clear()),
                          );
                        },
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _loading ? null : _search,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.search),
                ),
              ],
            ),
          ),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_error != null) {
      return ErrorStateView(message: _error!, onRetry: _search);
    }
    if (!_searched) {
      return const EmptyStateView(
        icon: Icons.person_search,
        message: 'Введіть ПІБ, щоб знайти призначені судові засідання',
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return const EmptyStateView(
        icon: Icons.event_busy,
        message: 'Засідань за цим ПІБ не знайдено',
      );
    }
    return HearingsList(hearings: _results);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
