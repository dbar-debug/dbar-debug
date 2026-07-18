import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Обгортка над біометрією (Face ID / Touch ID) для захисту запуску додатка.
class BiometricAuth {
  BiometricAuth._();
  static final BiometricAuth instance = BiometricAuth._();

  final LocalAuthentication _auth = LocalAuthentication();

  /// Чи доступна біометрія на пристрої взагалі.
  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } on PlatformException {
      return false;
    }
  }

  /// Запит автентифікації. true — успіх (або біометрія недоступна, щоб не
  /// заблокувати користувача назавжди).
  ///
  /// Використовуємо мінімальний виклик `authenticate(localizedReason:)`,
  /// сумісний з усіма версіями local_auth (без обгортки options).
  Future<bool> authenticate(String reason) async {
    try {
      if (!await isAvailable()) return true;
      return await _auth.authenticate(localizedReason: reason);
    } on PlatformException {
      return false;
    }
  }
}
