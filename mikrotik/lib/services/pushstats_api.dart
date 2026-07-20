import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Конфігурація PushStats: адреса сервера + секретний токен.
class PushStatsConfig {
  final String serverUrl; // без завершального /
  final String token;
  const PushStatsConfig(this.serverUrl, this.token);
}

/// Клієнт API PushStats-сервера (див. mikrotik/pushstats-server).
class PushStatsApi {
  static const _urlKey = 'pushstats_url';
  static const _tokenKey = 'pushstats_token';

  static Future<PushStatsConfig?> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_urlKey);
    final token = prefs.getString(_tokenKey);
    if (url == null || url.isEmpty || token == null || token.isEmpty) {
      return null;
    }
    return PushStatsConfig(url, token);
  }

  static Future<void> saveConfig(String url, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _urlKey, url.trim().replaceAll(RegExp(r'/+$'), ''));
    await prefs.setString(_tokenKey, token.trim());
  }

  static String generateToken() {
    final random = Random.secure();
    return List.generate(
        32, (_) => random.nextInt(16).toRadixString(16)).join();
  }

  static Future<List<Map<String, dynamic>>> routers(
      PushStatsConfig config) async {
    final response = await http
        .get(Uri.parse(
            '${config.serverUrl}/api/routers?token=${config.token}'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Сервер відповів ${response.statusCode}');
    }
    return (jsonDecode(response.body) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> history(
      PushStatsConfig config, int routerId, int hours) async {
    final response = await http
        .get(Uri.parse('${config.serverUrl}/api/routers/$routerId/history'
            '?token=${config.token}&hours=$hours'))
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Сервер відповів ${response.statusCode}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
