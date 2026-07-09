import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/court_case.dart';
import '../screens/case_documents_screen.dart';

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
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
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
                if (courtCase.proceedingNumber.isNotEmpty)
                  _DetailRow(icon: Icons.tag, label: 'Провадження', value: courtCase.proceedingNumber),
                _DetailRow(icon: Icons.calendar_today, label: 'Дата', value: courtCase.date),
                if (courtCase.subtitle.isNotEmpty && courtCase.subtitle != '—')
                  _DetailRow(icon: Icons.person_outline, label: 'Моя роль', value: courtCase.subtitle),
                if (courtCase.status.isNotEmpty)
                  _DetailRow(icon: Icons.info_outline, label: 'Статус', value: courtCase.status),
                if (courtCase.createdAt.isNotEmpty)
                  _DetailRow(icon: Icons.event_available, label: 'Відкрита', value: courtCase.createdAt),
                if (courtCase.updatedAt.isNotEmpty)
                  _DetailRow(icon: Icons.update, label: 'Оновлена', value: courtCase.updatedAt),
                if (courtCase.judges.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionTitle(icon: Icons.gavel, title: 'Суддівська колегія'),
                  for (final j in courtCase.judges) _ParticipantRow(name: j.name, role: j.role),
                ],
                if (courtCase.members.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _SectionTitle(icon: Icons.groups_outlined, title: 'Учасники справи'),
                  for (final m in courtCase.members) _ParticipantRow(name: m.name, role: m.role),
                ],
                const SizedBox(height: 20),
                if (courtCase.caseId.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => CaseDocumentsScreen(courtCase: courtCase),
                      ));
                    },
                    icon: const Icon(Icons.folder_open),
                    label: const Text('Документи по справі'),
                  ),
                if (courtCase.url.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () =>
                        launchUrl(Uri.parse(courtCase.url), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Відкрити на сайті суду'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  final String name;
  final String role;

  const _ParticipantRow({required this.name, required this.role});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 26, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(name, style: Theme.of(context).textTheme.bodyMedium)),
          const SizedBox(width: 8),
          Text(
            role,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
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
