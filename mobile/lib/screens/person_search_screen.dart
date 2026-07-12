import 'package:flutter/material.dart';

import '../models/person_case.dart';
import '../services/api_service.dart';
import '../widgets/state_views.dart';
import 'case_detail_screen.dart';

/// Пошук справ людини за ПІБ (відкриті дані, без КЕП): стан + засідання,
/// а по тапу — деталі з рішеннями. Ядро «додатка для всіх».
class PersonSearchScreen extends StatefulWidget {
  const PersonSearchScreen({super.key});

  @override
  State<PersonSearchScreen> createState() => _PersonSearchScreenState();
}

class _PersonSearchScreenState extends State<PersonSearchScreen> {
  final _api = ApiService();
  final _controller = TextEditingController();

  List<PersonCase> _cases = [];
  bool _loading = false;
  String? _error;
  bool _searched = false;

  static const _months = [
    'січня', 'лютого', 'березня', 'квітня', 'травня', 'червня',
    'липня', 'серпня', 'вересня', 'жовтня', 'листопада', 'грудня',
  ];

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
      final cases = await _api.getPersonCases(name);
      setState(() => _cases = cases);
    } on Exception catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Пошук за ПІБ')),
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
                        builder: (context, value, _) => value.text.isEmpty
                            ? const SizedBox.shrink()
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => setState(() => _controller.clear()),
                              ),
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
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.search),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return ErrorStateView(message: _error!, onRetry: _search);
    }
    if (!_searched) {
      return const EmptyStateView(
        icon: Icons.person_search,
        message: 'Введіть ПІБ, щоб знайти справи, засідання та рішення',
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_cases.isEmpty) {
      return const EmptyStateView(icon: Icons.folder_off, message: 'Справ за цим ПІБ не знайдено');
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _cases.length,
      itemBuilder: (context, i) => _caseCard(_cases[i]),
    );
  }

  Widget _caseCard(PersonCase c) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CaseDetailScreen(pcase: c)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('№ ${c.caseNumber}',
                        style: TextStyle(color: scheme.error, fontWeight: FontWeight.bold)),
                  ),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
              if (c.description.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(c.description, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 8),
              if (c.nextHearing != null)
                _chipRow(Icons.event, 'Засідання: ${_dateLong(c.nextHearing!.date)}'
                    '${c.nextHearing!.time.isNotEmpty ? ' о ${c.nextHearing!.time}' : ''}', scheme.primary),
              if (c.stageName.isNotEmpty)
                _chipRow(Icons.timeline, c.stageName, scheme.tertiary),
              if (c.courtName.isNotEmpty)
                _chipRow(Icons.account_balance, c.courtName, scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipRow(IconData icon, String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      );

  String _dateLong(String iso) {
    final p = iso.split('-');
    if (p.length != 3) return iso;
    final m = int.tryParse(p[1]) ?? 1;
    return '${int.parse(p[2])} ${_months[(m - 1).clamp(0, 11)]} ${p[0]}';
  }
}
