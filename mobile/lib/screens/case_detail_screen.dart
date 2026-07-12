import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/person_case.dart';
import '../services/api_service.dart';

/// Деталі справи: сторони/суть, найближче засідання, поточна стадія,
/// список засідань і рішення ЄДРСР (з посиланням на текст).
class CaseDetailScreen extends StatefulWidget {
  final PersonCase pcase;
  const CaseDetailScreen({super.key, required this.pcase});

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  final _api = ApiService();
  List<Decision> _decisions = [];
  bool _loadingDecisions = true;

  @override
  void initState() {
    super.initState();
    _loadDecisions();
  }

  Future<void> _loadDecisions() async {
    try {
      final d = await _api.getDecisionsByCase(widget.pcase.caseNumber);
      if (mounted) setState(() => _decisions = d);
    } catch (_) {
      // тихо — блок рішень просто буде порожній
    } finally {
      if (mounted) setState(() => _loadingDecisions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.pcase;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Справа ${c.caseNumber}', overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _headerCard(c, scheme),
          if (c.stageName.isNotEmpty) _stageCard(c, scheme),
          _sectionTitle('Засідання'),
          if (c.hearings.isEmpty)
            _muted('Немає даних про засідання')
          else
            ...c.hearings.reversed.map((h) => _hearingTile(h, scheme)),
          _sectionTitle('Рішення в ЄДРСР'),
          if (_loadingDecisions)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
          else if (_decisions.isEmpty)
            _muted('Рішень по справі не знайдено')
          else
            ..._decisions.map((d) => _decisionTile(d, scheme)),
        ],
      ),
    );
  }

  Widget _headerCard(PersonCase c, ColorScheme scheme) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('№ ${c.caseNumber}',
                  style: TextStyle(color: scheme.error, fontWeight: FontWeight.bold, fontSize: 16)),
              if (c.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(c.description, style: Theme.of(context).textTheme.bodyMedium),
              ],
              if (c.participants.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(c.participants, style: Theme.of(context).textTheme.bodySmall),
              ],
              const Divider(height: 20),
              if (c.judge.isNotEmpty)
                _iconRow(Icons.gavel, c.judge, scheme),
              if (c.courtName.isNotEmpty)
                _iconRow(Icons.account_balance, c.courtName, scheme),
            ],
          ),
        ),
      );

  Widget _stageCard(PersonCase c, ColorScheme scheme) => Card(
        color: scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.timeline, color: scheme.onSecondaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Поточна стадія',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.onSecondaryContainer)),
                    Text(c.stageName,
                        style: TextStyle(
                            color: scheme.onSecondaryContainer, fontWeight: FontWeight.bold)),
                    if (c.stageDate.isNotEmpty)
                      Text(c.stageDate,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSecondaryContainer)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _hearingTile(HearingSlot h, ColorScheme scheme) => Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: Icon(Icons.event, color: scheme.primary),
          title: Text('${h.dateHuman}${h.time.isNotEmpty ? ' о ${h.time}' : ''}'),
          subtitle: h.room.isNotEmpty ? Text('зал ${h.room}') : null,
        ),
      );

  Widget _decisionTile(Decision d, ColorScheme scheme) => Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: Icon(
            d.judgmentForm.toLowerCase().contains('рішення') ? Icons.gavel : Icons.article_outlined,
            color: scheme.primary,
          ),
          title: Text('${d.judgmentForm.isEmpty ? 'Документ' : d.judgmentForm} · ${d.dateHuman}'),
          subtitle: Text([d.justiceKind, if (d.category.isNotEmpty) d.category].join(' · ')),
          trailing: d.fileUrl.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.download_outlined),
                  tooltip: 'Зберегти (.rtf)',
                  onPressed: () => _open(d.fileUrl),
                )
              : null,
          onTap: d.reviewUrl.isEmpty ? null : () => _open(d.reviewUrl),
        ),
      );

  Future<void> _open(String url) async {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не вдалося відкрити посилання')),
      );
    }
  }

  Widget _iconRow(IconData icon, String text, ColorScheme scheme) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
          ],
        ),
      );

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
        child: Text(t, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      );

  Widget _muted(String t) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(t, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}
