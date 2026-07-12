// Веб-реалізація перегляду документа: показуємо його в <iframe> усередині
// додатку (щоб був наш хрестик і кнопка «Зберегти», а не зовнішня вкладка).
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

// Уже зареєстровані viewType, щоб не реєструвати ту саму фабрику двічі
// (повторна реєстрація кидає помилку).
final Set<String> _registered = {};

/// Вбудований перегляд документа за URL (HTML-рішення або PDF).
Widget buildDocumentView(String url) {
  final viewType = 'doc-iframe-${url.hashCode}';
  if (_registered.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      return html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allowFullscreen = true;
    });
  }
  return HtmlElementView(viewType: viewType);
}

/// Зберігає документ (браузер завантажить файл). URL має віддавати
/// Content-Disposition: attachment (параметр download=1 на бекенді).
void saveDocument(String url) {
  final anchor = html.AnchorElement(href: url)
    ..download = ''
    ..target = '_blank';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
