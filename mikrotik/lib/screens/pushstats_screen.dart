import 'package:flutter/material.dart';

/// Вкладка "PushStats" — моніторинг роутерів з push-сповіщеннями.
///
/// Ідея (як у WinboxMobile): роутер сам періодично надсилає статистику
/// (CPU, пам'ять, диск, трафік) на сервер через /tool fetch за скриптом
/// у планувальнику, а додаток показує картки стану і надсилає
/// push-сповіщення про проблеми. Потребує невеликого бекенда
/// (прийом статистики + APNs) — буде реалізовано в окремій фазі.
class PushStatsScreen extends StatelessWidget {
  const PushStatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PushStats')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.donut_large_outlined,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'PushStats',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Пасивний моніторинг: роутери надсилають статистику '
                '(CPU, пам\'ять, диск, трафік) на сервер, а додаток показує '
                'картки стану і push-сповіщення про проблеми. '
                'Буде реалізовано в окремій фазі (потрібен бекенд + APNs).',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
