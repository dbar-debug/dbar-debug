// Заглушка для не-веб платформ (нативний iOS/Android). Наразі додаток
// розгортається як веб-застосунок; тут просто відкриваємо документ у
// зовнішньому переглядачі, щоб збірка компілювалась.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Widget buildDocumentView(String url) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.description_outlined, size: 48),
          const SizedBox(height: 12),
          const Text(
            'Вбудований перегляд доступний у веб-версії.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () =>
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Відкрити документ'),
          ),
        ],
      ),
    ),
  );
}

void saveDocument(String url) {
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
