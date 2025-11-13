# Biometric Authentication Implementation

## Overview

The File Bridge mobile app includes persistent biometric authentication (Face ID on iOS, Fingerprint on Android) that allows users to login securely without entering their password each time. The implementation stores encrypted credentials and generates fresh API tokens on each biometric login.

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Security](#security)
- [User Flow](#user-flow)
- [Implementation Details](#implementation-details)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)

---

## Features

### ✅ Core Features

- **Persistent Biometric Status**: Remains enabled across logout sessions
- **Fresh Token Generation**: Generates new API token on each biometric login
- **Cross-Platform Support**: Face ID (iOS), Touch ID (iOS), Fingerprint (Android)
- **Settings Integration**: Manage biometric authentication from Settings screen
- **Auto-Enrollment**: Prompts users to enable biometric after successful password login
- **Secure Storage**: Credentials encrypted using Flutter Secure Storage
- **Graceful Degradation**: Falls back to password login if biometric unavailable

### 🔐 Security Features

- Credentials stored encrypted in device secure storage
- Biometric authentication required before accessing saved credentials
- No token storage - fresh token generated on each login
- Automatic credential clearance when biometric disabled
- Platform-level biometric security (Secure Enclave on iOS, Keystore on Android)

---

## Architecture

### Component Structure

```
mobile_app/
├── lib/
│   ├── services/
│   │   ├── biometric_service.dart     # Biometric operations
│   │   └── api_service.dart           # API authentication
│   └── screens/
│       ├── login_screen.dart          # Login with biometric UI
│       └── settings_screen.dart       # Biometric settings UI
```

### Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Enable Biometric Flow                    │
└─────────────────────────────────────────────────────────────┘

User Login (Password)
    ↓
Successful Authentication
    ↓
Biometric Available? → YES
    ↓
Show Enable Dialog
    ↓
User Taps "Enable"
    ↓
Save Encrypted Credentials
    ├─ biometric_enabled: true
    ├─ biometric_username: encrypted
    └─ biometric_password: encrypted


┌─────────────────────────────────────────────────────────────┐
│                   Biometric Login Flow                      │
└─────────────────────────────────────────────────────────────┘

User Opens App
    ↓
Biometric Enabled? → YES
    ↓
Show Biometric Button
    ↓
User Taps Button
    ↓
Authenticate with Biometric
    ↓
Retrieve Encrypted Credentials
    ↓
Call API Login (username, password)
    ↓
Receive Fresh Token
    ↓
Store Token + Permissions
    ↓
Navigate to Dashboard


┌─────────────────────────────────────────────────────────────┐
│                      Logout Flow                            │
└─────────────────────────────────────────────────────────────┘

User Taps Logout
    ↓
Call API Logout
    ↓
Clear Session Data:
    ├─ auth_token ✓ (cleared)
    └─ user_permissions ✓ (cleared)
    ↓
Keep Biometric Data:
    ├─ biometric_enabled ✓ (kept)
    ├─ biometric_username ✓ (kept)
    └─ biometric_password ✓ (kept)
    ↓
Return to Login Screen
    ↓
Biometric Button Still Available ✓
```

---

## Security

### Encryption & Storage

**Flutter Secure Storage**
- All credentials encrypted at rest
- Platform-specific secure storage:
  - **iOS**: Keychain (backed by Secure Enclave)
  - **Android**: EncryptedSharedPreferences (backed by Keystore)

**Stored Data**
```dart
// Encrypted and stored in secure storage
{
  'biometric_enabled': 'true',
  'biometric_username': 'encrypted_username',
  'biometric_password': 'encrypted_password'
}
```

**NOT Stored**
- ❌ API tokens (generated fresh on each login)
- ❌ Plaintext passwords
- ❌ Session data

### Biometric Authentication

**Platform Security**
- **iOS Face ID/Touch ID**: Uses LocalAuthentication framework with Secure Enclave
- **Android Fingerprint**: Uses BiometricPrompt API with Keystore
- Biometric data never leaves the device
- Authentication happens at OS level

**Authentication Flow**
1. User triggers biometric login
2. OS prompts for biometric (Face ID/Fingerprint)
3. OS validates biometric (app doesn't handle this)
4. On success, app retrieves encrypted credentials
5. Credentials decrypted by secure storage
6. API login called with credentials
7. Fresh token returned and stored

### Token Management

**Token Lifecycle**
```
Password Login → Token Generated → Token Stored
    ↓
Logout → Token Deleted
    ↓
Biometric Login → New Token Generated → Token Stored
    ↓
Logout → Token Deleted (Cycle repeats)
```

**Why No Token Storage?**
- Prevents expired token issues
- Ensures fresh session on each login
- Reduces attack surface (no stale tokens)
- Simplifies logout (just delete current token)

---

## User Flow

### First Time Setup

1. **User downloads app**
2. **Login with username/password**
   - Enter credentials
   - Tap "LOGIN"
   - Successful authentication
3. **Enable Biometric Prompt**
   - Dialog appears: "Enable Biometric Login?"
   - Shows biometric type (Face ID/Fingerprint)
   - User taps "Enable" or "Not Now"
4. **If Enabled**
   - Credentials saved securely
   - User navigates to dashboard
   - Biometric ready for next login

### Daily Usage

1. **User opens app**
2. **Biometric button visible**
   - "Login with Face ID" or "Login with Fingerprint"
3. **User taps biometric button**
   - OS biometric prompt appears
   - User authenticates (face scan/fingerprint)
4. **Automatic login**
   - Fresh token generated
   - Permissions loaded
   - Navigate to dashboard

### Managing Biometric

**Via Settings Screen**
1. Navigate to Settings from drawer
2. See "SECURITY" section
3. Biometric Login toggle
   - **ON** (green): Currently enabled
   - **OFF** (gray): Currently disabled

**To Disable**
1. Tap toggle switch
2. Confirmation dialog appears
3. Tap "Disable"
4. Credentials cleared
5. Biometric button removed from login

**To Re-Enable**
1. Cannot enable from Settings (need password)
2. Must logout
3. Login with username/password
4. Tap "Enable" on prompt

---

## Implementation Details

### BiometricService (`biometric_service.dart`)

**Key Methods**

```dart
// Check if device supports biometrics
Future<bool> isDeviceSupported()

// Check if biometrics are available and enrolled
Future<bool> isBiometricAvailable()

// Get available biometric types
Future<List<BiometricType>> getAvailableBiometrics()

// Authenticate user with biometric
Future<bool> authenticate({required String localizedReason})

// Enable biometric and save credentials
Future<void> enableBiometric({
  required String username,
  required String password,
})

// Disable biometric and clear credentials
Future<void> disableBiometric()

// Check if biometric is currently enabled
Future<bool> isBiometricEnabled()

// Get saved credentials (after biometric auth)
Future<Map<String, String?>> getSavedCredentials()

// Get user-friendly biometric type name
String getBiometricTypeName(List<BiometricType> types)
```

**Storage Keys**
```dart
static const String _keyBiometricEnabled = 'biometric_enabled';
static const String _keyBiometricUsername = 'biometric_username';
static const String _keyBiometricPassword = 'biometric_password';
```

### Login Screen (`login_screen.dart`)

**Biometric Initialization**
```dart
@override
void initState() {
  super.initState();
  _initializeScreen();
}

Future<void> _initializeScreen() async {
  await _loadSavedUsername();
  await _checkBiometricAvailability();  // Check hardware
  await _checkIfBiometricEnabled();     // Check if user enabled
}
```

**Biometric Login Logic**
```dart
Future<void> _loginWithBiometric() async {
  // 1. Authenticate with biometric
  final authenticated = await _biometricService.authenticate(
    localizedReason: 'Authenticate to login to File Bridge',
  );

  // 2. Get saved credentials
  final credentials = await _biometricService.getSavedCredentials();
  final username = credentials['username'];
  final password = credentials['password'];

  // 3. Login with API (generates fresh token)
  await _apiService.login(username, password);

  // 4. Fetch permissions
  final permissions = await _apiService.getUserPermissions();

  // 5. Navigate to dashboard
  Navigator.pushReplacement(...);
}
```

**Enrollment Prompt**
```dart
Future<void> _offerBiometricEnrollment() async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Enable Biometric Login?'),
      content: Text('Would you like to use $_biometricType...'),
      actions: [
        TextButton('Not Now'),
        ElevatedButton('Enable'),
      ],
    ),
  );

  if (result == true) {
    await _biometricService.enableBiometric(
      username: _usernameController.text,
      password: _passwordController.text,
    );
  }
}
```

### Settings Screen (`settings_screen.dart`)

**Biometric Status Display**
```dart
ListTile(
  leading: Icon(_biometricType == 'Face ID' ? Icons.face : Icons.fingerprint),
  title: Text('$_biometricType Login'),
  subtitle: Text(
    _isBiometricAvailable
        ? (_isBiometricEnabled ? 'Enabled' : 'Disabled')
        : 'Not available on this device',
  ),
  trailing: _isBiometricAvailable
      ? Switch(
          value: _isBiometricEnabled,
          onChanged: _toggleBiometric,
        )
      : null,
)
```

**Disable Logic**
```dart
Future<void> _toggleBiometric(bool enable) async {
  if (!enable) {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(...);

    if (confirmed == true) {
      await _biometricService.disableBiometric();
      setState(() => _isBiometricEnabled = false);
    }
  } else {
    // Cannot enable from settings - need password
    ScaffoldMessenger.showSnackBar(
      'To enable, please logout and login with password',
    );
  }
}
```

### API Service (`api_service.dart`)

**Logout Preservation**
```dart
Future<void> logout() async {
  try {
    // Call API logout
    await http.post(Uri.parse('$baseUrl/auth/logout'));
  } finally {
    // Clear only session data
    await storage.delete(key: 'auth_token');
    await storage.delete(key: 'user_permissions');

    // Keep biometric data for next login
    // ✓ biometric_enabled
    // ✓ biometric_username
    // ✓ biometric_password
  }
}
```

---

## Configuration

### iOS Setup

**1. Info.plist**

Add Face ID usage description:

```xml
<key>NSFaceIDUsageDescription</key>
<string>We use Face ID to provide secure and convenient login to your account</string>
```

**2. Capabilities**

Face ID/Touch ID automatically available if device supports it.

### Android Setup

**1. AndroidManifest.xml**

Add biometric permission:

```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
```

**2. MainActivity.kt**

Use FragmentActivity for biometric dialogs:

```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity: FlutterFragmentActivity() {
    // Biometric authentication requires FragmentActivity
}
```

**3. build.gradle**

Ensure minimum SDK version:

```gradle
android {
    defaultConfig {
        minSdkVersion 23  // Required for BiometricPrompt API
    }
}
```

### Dependencies

**pubspec.yaml**

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Biometric authentication
  local_auth: ^2.3.0

  # Secure credential storage
  flutter_secure_storage: ^9.2.2
```

**Installation**

```bash
cd mobile_app
flutter pub get
```

---

## Troubleshooting

### Common Issues

#### 1. "Biometric authentication is not available"

**Causes:**
- Device doesn't have biometric hardware
- Biometric not enrolled in device settings
- Permission denied

**Solutions:**
- Check device has Face ID/Touch ID (iOS) or fingerprint sensor (Android)
- Ensure biometric enrolled: Settings → Face ID & Passcode (iOS) or Settings → Security → Fingerprint (Android)
- Grant biometric permission in app settings

#### 2. "No saved credentials found"

**Causes:**
- Biometric was manually disabled
- Secure storage was cleared
- App was uninstalled/reinstalled

**Solutions:**
- Enable biometric again by logging in with password
- After reinstall, biometric must be re-enabled

#### 3. Biometric button not showing

**Debug Steps:**

```dart
// Check logs in console
🔍 Device supported: true/false
🔍 Can check biometrics: true/false
🔍 Available biometric types: [...]
🔍 Biometric available: true/false
🔍 Biometric enabled in storage: true/false
🔍 Should show button: true/false
```

**Solutions:**
- Ensure device supports biometrics
- Check biometric enrolled in device settings
- Verify app has biometric permission
- Enable biometric by logging in with password

#### 4. "Your session has expired" after biometric login

**Causes:**
- Password changed on server
- Account disabled
- Network error during login

**Solutions:**
- Login with current password
- Check account status
- Check network connection
- Re-enable biometric if password changed

### Debug Mode

**Enable Detailed Logging**

Biometric operations include debug logging:

```dart
print('🔍 Device supported: $isSupported');
print('🔍 Can check biometrics: $canCheck');
print('🔍 Available types: $availableTypes');
print('✅ Biometric credentials updated');
print('❌ Failed to update: $e');
```

**View Logs**

```bash
# Flutter logs
flutter logs

# iOS logs
xcrun simctl spawn booted log stream --predicate 'process == "Runner"'

# Android logs
adb logcat -s flutter
```

### Testing

**Test Scenarios**

1. **First Time Enable**
   - Login with password
   - Enable biometric
   - Logout
   - Login with biometric ✓

2. **Persistent After Logout**
   - Enable biometric
   - Logout multiple times
   - Biometric still enabled ✓

3. **Disable from Settings**
   - Go to Settings
   - Toggle biometric off
   - Confirm disable
   - Button removed from login ✓

4. **Re-Enable After Disable**
   - Disable biometric
   - Logout
   - Login with password
   - Enable biometric ✓

5. **Fresh Token Generation**
   - Login with biometric
   - Check auth_token in storage (new)
   - Logout
   - Login with biometric again
   - Check auth_token (different) ✓

**iOS Simulator**

Note: Biometric authentication doesn't work on iOS Simulator. Test on physical device.

**Android Emulator**

Enable fingerprint in emulator:
```bash
# Settings → Security → Fingerprint
# Or use adb
adb -e emu finger touch 1
```

---

## Best Practices

### For Developers

1. **Always check availability** before showing biometric UI
2. **Provide fallback** to password login
3. **Clear error messages** for users
4. **Don't store tokens** - generate fresh on each login
5. **Test on real devices** - simulators/emulators have limitations
6. **Handle OS updates** - biometric APIs may change

### For Users

1. **Keep device biometric enrolled** - required for feature to work
2. **Use strong password** - biometric is convenience, password is backup
3. **Disable if device compromised** - go to Settings
4. **Re-enable after password change** - ensures fresh credentials

### Security Considerations

1. **Never store plaintext passwords** - always use secure storage
2. **Validate biometric at OS level** - don't implement custom biometric
3. **Generate fresh tokens** - don't reuse expired tokens
4. **Clear credentials on disable** - don't leave orphaned data
5. **Use platform security** - Keychain on iOS, Keystore on Android

---

## Future Enhancements

### Potential Features

- [ ] **Biometric for sensitive actions** - Approve file deletions, etc.
- [ ] **Fallback PIN** - Secondary authentication method
- [ ] **Biometric timeout** - Re-authenticate after inactivity
- [ ] **Multiple biometric types** - Support Face + Fingerprint
- [ ] **Biometric for app unlock** - Lock app when backgrounded
- [ ] **Admin policies** - Force/disable biometric via server
- [ ] **Analytics** - Track biometric usage rates

---

## References

### Documentation

- [Flutter local_auth package](https://pub.dev/packages/local_auth)
- [Flutter secure storage](https://pub.dev/packages/flutter_secure_storage)
- [iOS LocalAuthentication](https://developer.apple.com/documentation/localauthentication)
- [Android BiometricPrompt](https://developer.android.com/reference/android/hardware/biometrics/BiometricPrompt)

### Related Files

- `mobile_app/lib/services/biometric_service.dart` - Core biometric logic
- `mobile_app/lib/screens/login_screen.dart` - Login UI and biometric button
- `mobile_app/lib/screens/settings_screen.dart` - Settings management
- `mobile_app/lib/services/api_service.dart` - API authentication
- `mobile_app/android/app/src/main/AndroidManifest.xml` - Android permissions
- `mobile_app/ios/Runner/Info.plist` - iOS permissions

---

## Support

For issues or questions:
1. Check this documentation
2. Review debug logs
3. Test on physical device
4. Check platform-specific settings
5. Report issue with logs attached

---

**Last Updated**: 2025-01-09
**Version**: 1.0.0
**Author**: Claude Code & Development Team
