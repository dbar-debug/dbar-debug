import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/court_case.dart';
import '../models/debtor.dart';
import '../models/person_case.dart';

const _defaultBaseUrl = 'https://court-app.duckdns.org';
const _baseUrlPrefKey = 'backend_base_url';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlPrefKey) ?? _defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    // Прибираємо кінцевий слеш, щоб не дублювати його при побудові шляхів
    final trimmed = url.trim().replaceAll(RegExp(r'/+$'), '');
    await prefs.setString(_baseUrlPrefKey, trimmed);
  }

  Future<List<CourtCase>> searchByName(String name, {int pages = 1}) async {
    final base = await getBaseUrl();
    final uri = Uri.parse('$base/search').replace(queryParameters: {
      'name': name,
      'pages': '$pages',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    final body = _decodeOrThrow(response);

    final cases = (body['cases'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(CourtCase.fromSearchJson)
        .toList();
    return cases;
  }

  Future<List<CourtCase>> getMyCases() async {
    final base = await getBaseUrl();
    final uri = Uri.parse('$base/cabinet/cases');

    final response = await http.get(uri).timeout(const Duration(seconds: 60));
    final body = _decodeOrThrow(response);

    final cases = (body['cases'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(CourtCase.fromCabinetJson)
        .toList();
    return cases;
  }

  Future<List<CaseDocument>> getCaseDocuments(String caseId) async {
    final base = await getBaseUrl();
    final uri = Uri.parse('$base/cabinet/cases/$caseId/documents');

    final response = await http.get(uri).timeout(const Duration(seconds: 60));
    final body = _decodeOrThrow(response);

    final docs = (body['documents'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(CaseDocument.fromJson)
        .toList();
    return docs;
  }

  /// URL файлу документа (HTML рішення / PDF). Бекенд проксіює його з
  /// авторизацією, тож цей URL можна відкрити прямо в браузері.
  /// [download] додає ?download=1 — сервер віддасть файл із заголовком
  /// Content-Disposition: attachment (для збереження).
  Future<Uri> documentFileUrl(String docId, {bool download = false}) async {
    final base = await getBaseUrl();
    final suffix = download ? '?download=1' : '';
    return Uri.parse('$base/cabinet/documents/$docId/file$suffix');
  }

  Future<List<CalendarEvent>> getCalendarEvents() async {
    final base = await getBaseUrl();
    final uri = Uri.parse('$base/cabinet/calendar');

    final response = await http.get(uri).timeout(const Duration(seconds: 120));
    final body = _decodeOrThrow(response);

    final events = (body['events'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(CalendarEvent.fromJson)
        .toList();
    return events;
  }

  Future<List<Hearing>> getHearings() async {
    final base = await getBaseUrl();
    final uri = Uri.parse('$base/cabinet/hearings');

    final response = await http.get(uri).timeout(const Duration(seconds: 120));
    final body = _decodeOrThrow(response);

    final hearings = (body['hearings'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(Hearing.fromJson)
        .toList();
    return hearings;
  }

  /// Пошук засідань за ПІБ у відкритих даних (без КЕП) — /hearings/by-name.
  Future<List<Hearing>> getHearingsByName(String name) async {
    final base = await getBaseUrl();
    final uri = Uri.parse('$base/hearings/by-name')
        .replace(queryParameters: {'name': name});

    final response = await http.get(uri).timeout(const Duration(seconds: 60));
    final body = _decodeOrThrow(response);

    final hearings = (body['hearings'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(Hearing.fromJson)
        .toList();
    return hearings;
  }

  /// Обʼєднаний перелік справ людини за ПІБ (стан + засідання) — /person/cases.
  Future<List<PersonCase>> getPersonCases(String name) async {
    final base = await getBaseUrl();
    final uri = Uri.parse('$base/person/cases').replace(queryParameters: {'name': name});

    final response = await http.get(uri).timeout(const Duration(seconds: 60));
    final body = _decodeOrThrow(response);

    return (body['cases'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(PersonCase.fromJson)
        .toList();
  }

  /// URL проксі тексту рішення (бекенд конвертує .rtf у HTML).
  /// [download] додає ?download=1 — віддає оригінальний .rtf.
  Future<Uri> decisionFileUrl(String docId, {bool download = false}) async {
    final base = await getBaseUrl();
    final suffix = download ? '?download=1' : '';
    return Uri.parse('$base/decisions/$docId/file$suffix');
  }

  /// Рішення ЄДРСР за номером справи — /decisions/by-case.
  Future<List<Decision>> getDecisionsByCase(String caseNumber) async {
    final base = await getBaseUrl();
    final uri = Uri.parse('$base/decisions/by-case')
        .replace(queryParameters: {'number': caseNumber});

    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    final body = _decodeOrThrow(response);

    return (body['decisions'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(Decision.fromJson)
        .toList();
  }

  /// Пошук у Єдиному реєстрі боржників за ПІБ або кодом — /debtors/search.
  Future<List<Debtor>> searchDebtors(String q) async {
    final base = await getBaseUrl();
    final uri = Uri.parse('$base/debtors/search').replace(queryParameters: {'q': q});

    final response = await http.get(uri).timeout(const Duration(seconds: 30));
    final body = _decodeOrThrow(response);

    return (body['debtors'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(Debtor.fromJson)
        .toList();
  }

  Map<String, dynamic> _decodeOrThrow(http.Response response) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Сервер повернув невірну відповідь (${response.statusCode})');
    }

    if (response.statusCode >= 400) {
      final detail = body['detail'];
      throw ApiException(detail is String ? detail : 'Помилка сервера (${response.statusCode})');
    }

    return body;
  }
}
