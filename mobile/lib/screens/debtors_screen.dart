import 'package:flutter/material.dart';

import '../models/debtor.dart';
import '../services/api_service.dart';
import '../widgets/state_views.dart';

/// Пошук у Єдиному реєстрі боржників за ПІБ або кодом (ІПН/ЄДРПОУ).
class DebtorsScreen extends StatefulWidget {
  const DebtorsScreen({super.key});

  @override
  State<DebtorsScreen> createState() => _DebtorsScreenState();
}

class _DebtorsScreenState extends State<DebtorsScreen> {
  final _api = ApiService();
  final _controller = TextEditingController();

  List<Debtor> _results = [];
  bool _loading = false;
  String? _error;
  bool _searched = false;

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.length < 4) {
      setState(() {
        _error = 'Введіть ПІБ (мін. 4 символи) або код ІПН/ЄДРПОУ';
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
      final r = await _api.searchDebtors(q);
      setState(() => _results = r);
    } on Exception catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Реєстр боржників')),
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
                      labelText: 'ПІБ або ІПН/ЄДРПОУ',
                      hintText: 'Прізвище Ім\'я або код',
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
        icon: Icons.account_balance_wallet_outlined,
        message: 'Введіть ПІБ або код, щоб перевірити наявність\nвиконавчих проваджень',
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_results.isEmpty) {
      return const EmptyStateView(
        icon: Icons.check_circle_outline,
        message: 'У реєстрі боржників нічого не знайдено',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _results.length,
      itemBuilder: (context, i) => _debtorCard(_results[i]),
    );
  }

  Widget _debtorCard(Debtor d) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Wrap(spacing: 12, children: [
              if (d.birthdate.isNotEmpty)
                Text('нар. ${d.birthdate}', style: Theme.of(context).textTheme.bodySmall),
              if (d.code.isNotEmpty)
                Text('код ${d.code}', style: Theme.of(context).textTheme.bodySmall),
            ]),
            const Divider(height: 18),
            if (d.category.isNotEmpty)
              _row(Icons.gavel, d.category, scheme.error),
            if (d.orgName.isNotEmpty)
              _row(Icons.account_balance, d.orgName, scheme.onSurfaceVariant),
            if (d.executor.isNotEmpty)
              _row(Icons.person, 'Виконавець: ${d.executor}', scheme.onSurfaceVariant),
            if (d.vpNum.isNotEmpty)
              _row(Icons.tag, 'ВП № ${d.vpNum}', scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text, Color color) => Padding(
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
