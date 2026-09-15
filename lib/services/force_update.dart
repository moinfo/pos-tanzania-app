import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Why the server refused this build.
class ForceUpdateInfo {
  const ForceUpdateInfo({
    required this.message,
    required this.minVersionCode,
    this.storeUrl,
  });

  final String message;
  final int minVersionCode;
  final String? storeUrl;
}

/// The client half of the minimum-version gate.
///
/// The server decides (API_Controller::enforce_min_app_version); the app only
/// identifies itself on every request and, once refused, blocks the UI. The
/// headers are added in ApiService's shared client, so every authenticated
/// call carries them without each call site having to remember.
class ForceUpdate {
  ForceUpdate._();

  /// Non-null once the server has answered 426. Never cleared: the only way
  /// out is installing a newer build, which starts a fresh process.
  static final ValueNotifier<ForceUpdateInfo?> required =
      ValueNotifier<ForceUpdateInfo?>(null);

  static Future<Map<String, String>>? _headers;

  /// X-App-Platform and X-App-Build for the running binary, read once.
  static Future<Map<String, String>> headers() {
    return _headers ??= PackageInfo.fromPlatform().then(
      (info) => {
        'X-App-Platform': Platform.isIOS ? 'ios' : 'android',
        'X-App-Build': info.buildNumber,
      },
      onError: (Object e) {
        // Without a build number the server reads build 0 and blocks us if a
        // minimum is set -- the safe direction. Don't cache the failure.
        debugPrint('ForceUpdate: could not read build number - $e');
        _headers = null;
        return <String, String>{
          'X-App-Platform': Platform.isIOS ? 'ios' : 'android',
        };
      },
    );
  }

  /// Record a 426 response body.
  static void reportRefusal(List<int> bodyBytes) {
    var message = 'Please update the app to continue.';
    var minVersion = 0;
    String? storeUrl;

    try {
      final body = json.decode(utf8.decode(bodyBytes));
      if (body is Map) {
        final text = body['message']?.toString().trim() ?? '';
        if (text.isNotEmpty) message = text;
        final errors = body['errors'];
        if (errors is Map) {
          minVersion =
              int.tryParse(errors['min_version_code']?.toString() ?? '') ?? 0;
          final url = errors['store_url']?.toString().trim() ?? '';
          if (url.isNotEmpty) storeUrl = url;
        }
      }
    } catch (e) {
      // A 426 blocks regardless of whether its body parsed.
      debugPrint('ForceUpdate: unreadable 426 body - $e');
    }

    if (required.value != null) return;
    required.value = ForceUpdateInfo(
      message: message,
      minVersionCode: minVersion,
      storeUrl: storeUrl,
    );
  }
}
