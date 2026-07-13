import 'package:flutter/material.dart';

import '../models/edr_record.dart';
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
  List<EdrRecord> _edr = [];
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
      // Бізнес-довідка (ЄДР) — допоміжна: не валимо весь пошук, якщо її нема.
      final results = await Future.wait([
        _api.getPersonCases(name),
        _api.searchEdr(name).catchError((_) => <EdrRecord>[]),
      ]);
      setState(() {
        _cases = results[0] as List<PersonCase>;
        _edr = results[1] as List<EdrRecord>;
      });
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
        message: 'Введіть ПІБ, щоб знайти справи, засідання, рішення та бізнес (ФОП)',
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_cases.isEmpty && _edr.isEmpty) {
      return const EmptyStateView(
          icon: Icons.folder_off, message: 'Справ і бізнесу за цим ПІБ не знайдено');
    }
    // Спершу блок «Бізнес» (ЄДР), далі судові справи.
    final hasEdr = _edr.isNotEmpty;
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: (hasEdr ? _edr.length + 1 : 0) +
          (_cases.isNotEmpty ? _cases.length + 1 : 0),
      itemBuilder: (context, i) {
        if (hasEdr) {
          if (i == 0) return _sectionHeader('Бізнес', Icons.storefront);
          if (i <= _edr.length) return _edrCard(_edr[i - 1]);
          final j = i - (_edr.length + 1);
          if (j == 0) return _sectionHeader('Судові справи', Icons.gavel);
          return _caseCard(_cases[j - 1]);
        }
        if (i == 0) return _sectionHeader('Судові справи', Icons.gavel);
        return _caseCard(_cases[i - 1]);
      },
    );
  }

  Widget _sectionHeader(String title, IconData icon) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Row(children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary)),
        ]),
      );

  Widget _edrCard(EdrRecord r) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = r.isActive ? Colors.green : scheme.onSurfaceVariant;
    final typeLabel = r.kind == 'ФОП' ? 'ФОП' : 'Юрособа';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(r.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                _badge(typeLabel, scheme.primary),
              ],
            ),
            if (r.role.isNotEmpty)
              Text(r.role,
                  style: TextStyle(
                      color: scheme.tertiary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            if (r.orgName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(r.orgName, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 6),
            Wrap(spacing: 12, runSpacing: 2, children: [
              if (r.stan.isNotEmpty)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, size: 10, color: statusColor),
                  const SizedBox(width: 4),
                  Text(r.stan,
                      style: TextStyle(color: statusColor, fontSize: 12)),
                ]),
              if (r.code.isNotEmpty)
                Text('ЄДРПОУ ${r.code}',
                    style: Theme.of(context).textTheme.bodySmall),
              if (r.regDate.isNotEmpty)
                Text('з ${r.regDate}',
                    style: Theme.of(context).textTheme.bodySmall),
            ]),
            if (r.extra.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(r.extra, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (r.termination.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.cancel_outlined, size: 14, color: scheme.error),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('Припинено: ${r.termination}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.error)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      );

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
