import 'package:flutter/material.dart';

import '../models/court_case.dart';

class CaseListTile extends StatelessWidget {
  final CourtCase courtCase;
  final VoidCallback? onTap;

  const CaseListTile({super.key, required this.courtCase, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      courtCase.caseNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  if (courtCase.status.isNotEmpty)
                    _Badge(
                      text: courtCase.status,
                      color: _statusColor(courtCase.status, scheme),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(courtCase.courtName, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(courtCase.date, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(width: 12),
                  if (courtCase.subtitle.isNotEmpty && courtCase.subtitle != '—')
                    _Badge(
                      text: courtCase.subtitle,
                      color: _roleColor(courtCase.subtitle, scheme),
                    ),
                ],
              ),
              if (courtCase.excerpt.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  courtCase.excerpt,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _roleColor(String role, ColorScheme scheme) {
    final r = role.toLowerCase();
    if (r.contains('відповідач') || r.contains('боржник') || r.contains('обвинувачен') || r.contains('правопоруш')) {
      return scheme.error;
    }
    if (r.contains('позивач') || r.contains('заявник') || r.contains('стягувач')) {
      return scheme.primary;
    }
    return scheme.tertiary;
  }

  Color _statusColor(String status, ColorScheme scheme) {
    final s = status.toLowerCase();
    if (s.contains('відкрито')) return Colors.green.shade700;
    if (s.contains('очіку')) return Colors.orange.shade800;
    return scheme.outline;
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
