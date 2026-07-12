import 'package:flutter/material.dart';

import '../models/court_case.dart';
import '../services/api_service.dart';
import '../widgets/hearings_list.dart';
import '../widgets/state_views.dart';
import 'hearings_search_screen.dart';

class HearingsScreen extends StatefulWidget {
  const HearingsScreen({super.key});

  @override
  State<HearingsScreen> createState() => _HearingsScreenState();
}

class _HearingsScreenState extends State<HearingsScreen> {
  final _api = ApiService();

  List<Hearing> _hearings = [];
  bool _loading = true;
  String? _error;

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
      final hearings = await _api.getHearings();
      setState(() => _hearings = hearings);
    } on Exception catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _hearings.isEmpty ? 'Засідання' : 'Засідання — ${_hearings.length} шт.';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search),
            tooltip: 'Пошук за ПІБ',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HearingsSearchScreen()),
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorStateView(message: _error!, onRetry: _load);
    }
    if (_hearings.isEmpty) {
      return const EmptyStateView(
        icon: Icons.event_available,
        message: 'Немає призначених засідань по ваших справах',
      );
    }
    return HearingsList(hearings: _hearings);
  }
}
