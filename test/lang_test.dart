import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tanzania_mobile/l10n/lang.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Lang.set(Lang.english);
  });

  test('English leaves strings untouched', () {
    expect(Lang.tr('Save'), 'Save');
    expect('Customers'.tr, 'Customers');
  });

  test('English shows the few strings that were written in Kiswahili', () {
    expect(Lang.tr('Karibu tena'), 'Welcome back');
  });

  test('Kiswahili: exact, case-insensitive and padded strings', () async {
    await Lang.set(Lang.swahili);
    expect(Lang.tr('Save'), 'Hifadhi');
    expect(Lang.tr('SAVE'), 'HIFADHI');
    expect(Lang.tr('Cancel '), 'Ghairi ');
    expect(Lang.tr('Something nobody translated'), 'Something nobody translated');
  });

  test('Kiswahili: templates fill their values back in', () async {
    await Lang.set(Lang.swahili);
    expect(Lang.tr('Total: 1,200'), 'Jumla: 1,200');
    expect(Lang.tr('Login failed: timeout'), 'Kuingia kumeshindwa: timeout');
    expect(Lang.tr('Page 2 of 9'), 'Ukurasa 2 kati ya 9');
    expect(Lang.tr('3 days ago'), 'siku 3 zilizopita');
  });

  test('Kiswahili: a value that is itself a known word is translated too', () async {
    await Lang.set(Lang.swahili);
    expect(Lang.tr('Customer: Cash'), 'Mteja: Taslimu');
  });
}
