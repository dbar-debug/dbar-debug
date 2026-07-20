import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../services/app_settings.dart';
import '../services/biometric_auth.dart';

/// Біометричний замок при запуску: якщо у налаштуваннях увімкнено
/// "Face ID / Touch ID при запуску", показує екран блокування, доки
/// користувач не пройде автентифікацію.
class AuthGate extends StatefulWidget {
  final Widget child;
  const AuthGate({super.key, required this.child});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _unlocked = false;
  bool _inProgress = false;

  @override
  void initState() {
    super.initState();
    if (!AppSettings.instance.authOnLaunch.value) {
      _unlocked = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
    }
  }

  Future<void> _authenticate() async {
    if (_inProgress) return;
    setState(() => _inProgress = true);
    final ok = await BiometricAuth.instance.authenticate(tr('auth_reason'));
    if (!mounted) return;
    setState(() {
      _unlocked = ok;
      _inProgress = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_unlocked) return widget.child;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(tr('auth_locked'),
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _inProgress ? null : _authenticate,
              icon: const Icon(Icons.fingerprint),
              label: Text(tr('auth_unlock')),
            ),
          ],
        ),
      ),
    );
  }
}
