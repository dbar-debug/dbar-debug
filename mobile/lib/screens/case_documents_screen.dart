import 'package:flutter/material.dart';

import '../models/court_case.dart';
import '../services/api_service.dart';
import '../widgets/state_views.dart';

class CaseDocumentsScreen extends StatefulWidget {
  final CourtCase courtCase;

  const CaseDocumentsScreen({super.key, required this.courtCase});

  @override
  State<CaseDocumentsScreen> createState() => _CaseDocumentsScreenState();
}

class _CaseDocumentsScreenState extends State<CaseDocumentsScreen> {
  final _api = ApiService();

  List<CaseDocument> _docs = [];
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
      final docs = await _api.getCaseDocuments(widget.courtCase.caseId);
      setState(() => _docs = docs);
    } on Exception catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Документи по справі'),
            Text(
              widget.courtCase.caseNumber,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ],
        ),
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
    if (_docs.isEmpty) {
      return const EmptyStateView(
        icon: Icons.description_outlined,
        message: 'Документів по справі не знайдено',
      );
    }
    return ListView.separated(
      itemCount: _docs.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final d = _docs[index];
        return ListTile(
          leading: Icon(_iconFor(d.description), color: Theme.of(context).colorScheme.primary),
          title: Text(d.description),
          subtitle: Text('№ ${d.number}'),
          trailing: Text(
            d.date,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      },
    );
  }

  IconData _iconFor(String description) {
    final d = description.toLowerCase();
    if (d.contains('рішення')) return Icons.gavel;
    if (d.contains('ухвал')) return Icons.article_outlined;
    if (d.contains('слухан') || d.contains('засідан')) return Icons.event;
    if (d.contains('картка')) return Icons.assignment_outlined;
    return Icons.description_outlined;
  }
}
