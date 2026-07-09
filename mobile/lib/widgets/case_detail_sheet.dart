import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/court_case.dart';

/// Показує деталі справи прямо в додатку. Ми НЕ переходимо одразу на
/// cabinet.court.gov.ua, бо там окрема авторизація в браузері — сесія
/// з бекенду (КЕП) туди не передається, і користувач просто побачить
/// форму входу. Перехід на сайт лишаємо як окрему явну дію.
Future<void> showCaseDetailSheet(BuildContext context, CourtCase courtCase) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => _CaseDetailSheet(courtCase: courtCase),
  );
}

class _CaseDetailSheet extends StatelessWidget {
  final CourtCase courtCase;

  const _CaseDetailSheet({required this.courtCase});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              courtCase.caseNumber,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _DetailRow(icon: Icons.account_balance, label: 'Суд', value: courtCase.courtName),
            _DetailRow(icon: Icons.calendar_today, label: 'Дата', value: courtCase.date),
            if (courtCase.subtitle.isNotEmpty && courtCase.subtitle != '—')
              _DetailRow(icon: Icons.person_outline, label: 'Моя роль', value: courtCase.subtitle),
            if (courtCase.status.isNotEmpty)
              _DetailRow(icon: Icons.info_outline, label: 'Статус', value: courtCase.status),
            if (courtCase.judge.isNotEmpty && courtCase.judge != '—')
              _DetailRow(icon: Icons.gavel, label: 'Суддя', value: courtCase.judge),
            const SizedBox(height: 20),
            if (courtCase.url.isNotEmpty) ...[
              Text(
                'Повні документи та деталі справи доступні лише на сайті суду '
                'після входу власним КЕП/Дія.Підпис у браузері.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () =>
                    launchUrl(Uri.parse(courtCase.url), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Відкрити на сайті суду'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
