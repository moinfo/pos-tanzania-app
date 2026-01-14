import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Service to protect screen content from screenshots and screen recording
class ScreenProtectionService {
  static final ScreenProtectionService _instance = ScreenProtectionService._internal();
  factory ScreenProtectionService() => _instance;
  ScreenProtectionService._internal();

  static const MethodChannel _channel = MethodChannel('com.comeandsave/screen_protection');

  bool _isProtectionEnabled = false;

  bool get isProtectionEnabled => _isProtectionEnabled;

  /// Enable screenshot and screen recording protection
  /// On Android: Uses FLAG_SECURE to prevent screenshots
  /// On iOS: Limited support - screenshots can be detected but not fully prevented
  Future<void> enableProtection() async {
    if (kIsWeb) return; // Not supported on web

    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('enableSecureMode');
        _isProtectionEnabled = true;
        debugPrint('Screen protection enabled (Android FLAG_SECURE)');
      } else if (Platform.isIOS) {
        // iOS doesn't have a direct equivalent to FLAG_SECURE
        _isProtectionEnabled = true;
        debugPrint('Screen protection enabled (iOS - limited)');
      }
    } catch (e) {
      debugPrint('Error enabling screen protection: $e');
    }
  }

  /// Disable screenshot protection
  Future<void> disableProtection() async {
    if (kIsWeb) return;

    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('disableSecureMode');
        _isProtectionEnabled = false;
        debugPrint('Screen protection disabled');
      } else if (Platform.isIOS) {
        _isProtectionEnabled = false;
        debugPrint('Screen protection disabled (iOS)');
      }
    } catch (e) {
      debugPrint('Error disabling screen protection: $e');
    }
  }

  /// Toggle protection state
  Future<void> toggleProtection() async {
    if (_isProtectionEnabled) {
      await disableProtection();
    } else {
      await enableProtection();
    }
  }
}

/// Mixin to add screen protection to a StatefulWidget
mixin ScreenProtectionMixin<T extends StatefulWidget> on State<T> {
  final _protectionService = ScreenProtectionService();

  @override
  void initState() {
    super.initState();
    _protectionService.enableProtection();
  }

  @override
  void dispose() {
    // Don't disable on dispose - keep protection active app-wide
    super.dispose();
  }
}
