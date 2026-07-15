import 'package:flutter/material.dart';

/// Вкладка "Команда" — спільний список роутерів для команди.
///
/// Ідея (як у WinboxMobile): один із роутерів MikroTik виступає
/// "командним сервером" — maintainer вивантажує туди файл зі списком
/// роутерів, а користувачі завантажують його собі. Реалізується через
/// файлове сховище роутера (upload/download файлу через API).
class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Команда')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.dns_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                'Командна робота',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Спільний список роутерів для команди через '
                '"командний сервер" (роутер MikroTik як сховище). '
                'Буде реалізовано у наступній фазі.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
