import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/court_case.dart';

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
