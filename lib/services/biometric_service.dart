import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Service for handling biometric authentication (Face ID/Fingerprint)
/// Provides secure credential storage and biometric login functionality
class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  // Same recovery behavior as ApiService._storage: reset undecryptable
  // storage (post-restore Keystore mismatch) instead of failing every read.
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
  );

  // Storage keys for biometric data
  static const String _keyBiometricEnabled = 'biometric_enabled';
  static const String _keyBiometricUsername = 'biometric_username';
  static const String _keyBiometricPassword = 'biometric_password';

  /// Check if device supports biometric authentication
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } catch (e) {
      print('❌ Error checking device support: $e');
      return false;
    }
  }

  /// Check if biometrics are available and enrolled
  Future<bool> isBiometricAvailable() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      if (!isSupported) {
        print('🔍 Device does not support biometrics');
        return false;
      }

      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      print('🔍 Can check biometrics: $canCheckBiometrics');

      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      print('🔍 Available biometric types: $availableBiometrics');

      final isAvailable = canCheckBiometrics && availableBiometrics.isNotEmpty;
      print('🔍 Biometric available: $isAvailable');

      return isAvailable;
    } catch (e) {
      print('❌ Error checking biometric availability: $e');
      return false;
    }
  }

  /// Get available biometric types (Face ID, Fingerprint, etc.)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      print('❌ Error getting available biometrics: $e');
      return [];
    }
  }

  /// Authenticate user with biometric (Face ID or Fingerprint)
  Future<bool> authenticate({required String localizedReason}) async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        print('❌ Biometric authentication not available');
        return false;
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      print(didAuthenticate ? '✅ Biometric authentication successful' : '❌ Biometric authentication failed');
      return didAuthenticate;
    } on PlatformException catch (e) {
      print('❌ Biometric authentication error: ${e.message}');
      return false;
    } catch (e) {
      print('❌ Unexpected error during authentication: $e');
      return false;
    }
  }

  /// Enable biometric and save credentials securely
  Future<void> enableBiometric({
    required String username,
    required String password,
  }) async {
    try {
      // Save credentials encrypted in secure storage
      await _secureStorage.write(key: _keyBiometricEnabled, value: 'true');
      await _secureStorage.write(key: _keyBiometricUsername, value: username);
      await _secureStorage.write(key: _keyBiometricPassword, value: password);

      print('✅ Biometric credentials saved successfully');
    } catch (e) {
      print('❌ Failed to save biometric credentials: $e');
      rethrow;
    }
  }

  /// Disable biometric and clear saved credentials
  Future<void> disableBiometric() async {
    try {
      await _secureStorage.delete(key: _keyBiometricEnabled);
      await _secureStorage.delete(key: _keyBiometricUsername);
      await _secureStorage.delete(key: _keyBiometricPassword);

      print('✅ Biometric credentials cleared');
    } catch (e) {
      print('❌ Failed to clear biometric credentials: $e');
      rethrow;
    }
  }

  /// Check if biometric is currently enabled
  Future<bool> isBiometricEnabled() async {
    try {
      final enabled = await _secureStorage.read(key: _keyBiometricEnabled);
      final isEnabled = enabled == 'true';
      print('🔍 Biometric enabled in storage: $isEnabled');
      return isEnabled;
    } catch (e) {
      print('❌ Error checking biometric enabled status: $e');
      return false;
    }
  }

  /// Get saved credentials (after successful biometric authentication)
  Future<Map<String, String?>> getSavedCredentials() async {
    try {
      final username = await _secureStorage.read(key: _keyBiometricUsername);
      final password = await _secureStorage.read(key: _keyBiometricPassword);

      if (username == null || password == null) {
        print('❌ No saved credentials found');
        return {'username': null, 'password': null};
      }

      print('✅ Retrieved saved credentials');
      return {'username': username, 'password': password};
    } catch (e) {
      print('❌ Error retrieving saved credentials: $e');
      return {'username': null, 'password': null};
    }
  }

  /// Get user-friendly biometric type name (Face ID, Fingerprint, etc.)
  String getBiometricTypeName(List<BiometricType> types) {
    if (types.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (types.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (types.contains(BiometricType.iris)) {
      return 'Iris';
    } else if (types.contains(BiometricType.strong)) {
      return 'Biometric';
    } else if (types.contains(BiometricType.weak)) {
      return 'Biometric';
    }
    return 'Biometric';
  }
}