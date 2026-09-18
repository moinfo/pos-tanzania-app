import 'package:flutter_test/flutter_test.dart';
import 'package:pos_tanzania_mobile/models/app_version_info.dart';
import 'package:pos_tanzania_mobile/services/force_update.dart';

/// A mandatory update was being put off for days: the prompt people saw
/// ignored the minimum version and always offered "Later".
void main() {
  test('the minimum version is read from the version check', () {
    final info = AppVersionInfo.fromJson({
      'platform': 'android',
      'configured': true,
      'version_code': 61,
      'version_name': '1.0.0',
      'min_version_code': 60,
    });
    expect(info.minVersionCode, 60);
  });

  test('a server that predates the setting reads as no minimum', () {
    final info = AppVersionInfo.fromJson({
      'platform': 'android',
      'configured': true,
      'version_code': 61,
    });
    expect(info.minVersionCode, 0);
  });

  test('requiring an update raises the blocking screen, once', () {
    expect(ForceUpdate.required.value, isNull);
    ForceUpdate.require(minVersionCode: 60, storeUrl: null);
    final first = ForceUpdate.required.value;
    expect(first, isNotNull);
    expect(first!.minVersionCode, 60);

    // A second trigger (a 426 arriving later) must not replace it.
    ForceUpdate.require(minVersionCode: 99, storeUrl: null);
    expect(ForceUpdate.required.value, same(first));
  });
}
