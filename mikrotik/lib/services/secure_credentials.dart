import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Безпечне сховище паролів роутерів у Keychain (iOS) / Keystore (Android).
///
/// Паролі більше не зберігаються у shared_preferences у відкритому вигляді —
/// у prefs лишаються тільки нечутливі поля роутера, а пароль живе тут під
/// ключем `router_pw_<id>`.
class SecureCredentials {
  SecureCredentials._();
  static final SecureCredentials instance = SecureCredentials._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  String _key(String id) => 'router_pw_$id';

  Future<void> setPassword(String id, String password) async {
    if (password.isEmpty) {
      await _storage.delete(key: _key(id));
    } else {
      await _storage.write(key: _key(id), value: password);
    }
  }

  Future<String> getPassword(String id) async {
    return await _storage.read(key: _key(id)) ?? '';
  }

  Future<void> deletePassword(String id) async {
    await _storage.delete(key: _key(id));
  }
}
