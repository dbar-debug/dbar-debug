import 'package:flutter/material.dart';

import '../models/court_case.dart';
import '../services/api_service.dart';
import '../widgets/case_detail_sheet.dart';
import '../widgets/case_list_tile.dart';
import '../widgets/state_views.dart';

class CabinetScreen extends StatefulWidget {
  const CabinetScreen({super.key});

  @override
  State<CabinetScreen> createState() => _CabinetScreenState();
}

class _CabinetScreenState extends State<CabinetScreen> {
  final _api = ApiService();

  List<CourtCase> _cases = [];
  bool _loading = true;
  String? _error;
  String? _statusFilter; // null = усі

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
      final cases = await _api.getMyCases();
      setState(() => _cases = cases);
    } on Exception catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  List<String> get _availableStatuses {
    final statuses = _cases.map((c) => c.status).where((s) => s.isNotEmpty).toSet().toList();
    statuses.sort();
    return statuses;
  }

  List<CourtCase> get _filteredCases {
    if (_statusFilter == null) return _cases;
    return _cases.where((c) => c.status == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final title = _cases.isEmpty ? 'Мої справи' : 'Мої справи · ${_filteredCases.length}';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: Column(
          children: [
            if (!_loading && _error == null && _availableStatuses.length > 1) _buildFilterChips(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: const Text('Усі'),
              selected: _statusFilter == null,
              onSelected: (_) => setState(() => _statusFilter = null),
            ),
            for (final status in _availableStatuses) ...[
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(status),
                selected: _statusFilter == status,
                onSelected: (_) => setState(() => _statusFilter = status),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ErrorStateView(message: _error!, onRetry: _load);
    }
    if (_cases.isEmpty) {
      return const EmptyStateView(icon: Icons.folder_off_outlined, message: 'Справ не знайдено');
    }
    final cases = _filteredCases;
    if (cases.isEmpty) {
      return const EmptyStateView(
        icon: Icons.filter_alt_off_outlined,
        message: 'Немає справ з обраним статусом',
      );
    }
    return ListView.builder(
      itemCount: cases.length,
      itemBuilder: (context, index) {
        final c = cases[index];
        return CaseListTile(
          courtCase: c,
          onTap: () => showCaseDetailSheet(context, c),
        );
      },
    );
  }
}
