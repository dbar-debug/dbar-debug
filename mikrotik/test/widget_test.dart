import 'package:flutter_test/flutter_test.dart';
import 'package:mikrotik_mobile/l10n/strings.dart';

void main() {
  test('локалізація повертає різні рядки для uk/en', () {
    L.code = 'uk';
    expect(tr('tab_saved'), 'Збережені');
    L.code = 'en';
    expect(tr('tab_saved'), 'Saved');
  });

  test('невідомий ключ повертає сам ключ', () {
    expect(tr('no_such_key_123'), 'no_such_key_123');
  });
}
