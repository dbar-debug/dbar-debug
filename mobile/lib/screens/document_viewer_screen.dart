import 'package:flutter/material.dart';

import '../widgets/doc_view/doc_view_stub.dart'
    if (dart.library.html) '../widgets/doc_view/doc_view_web.dart' as docview;

/// Повноекранний перегляд документа справи всередині додатку:
/// хрестик «Закрити» зліва, кнопка «Зберегти» справа, сам документ — у рамці.
class DocumentViewerScreen extends StatelessWidget {
  final String title;
  final String viewUrl;      // інлайн-перегляд (HTML/PDF)
  final String downloadUrl;  // те саме, але зі збереженням у файл

  const DocumentViewerScreen({
    super.key,
    required this.title,
    required this.viewUrl,
    required this.downloadUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Закрити',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Зберегти',
            onPressed: () {
              docview.saveDocument(downloadUrl);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Завантаження документа...')),
              );
            },
          ),
        ],
      ),
      body: docview.buildDocumentView(viewUrl),
    );
  }
}
