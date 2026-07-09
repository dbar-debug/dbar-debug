import 'package:flutter/material.dart';

import '../models/court_case.dart';

class CaseListTile extends StatelessWidget {
  final CourtCase courtCase;
  final VoidCallback? onTap;

  const CaseListTile({super.key, required this.courtCase, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        onTap: onTap,
        title: Text(
          courtCase.caseNumber,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(courtCase.courtName),
            Text('${courtCase.date} · ${courtCase.subtitle}'),
            if (courtCase.excerpt.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                courtCase.excerpt,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}
