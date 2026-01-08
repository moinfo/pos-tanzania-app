# Flutter Flavors - Multi-Client Build Guide

This app supports building separate APKs for different clients. Each client gets:
- **Unique Application ID** - Apps install separately on the same device
- **Unique App Name** - Different name displayed on phone
- **Unique Configuration** - Different API endpoints and features

## Available Clients

| Client | Flavor Name | Application ID | App Name |
|--------|-------------|----------------|----------|
| SADA | `sada` | `co.tz.sada.pos` | SADA POS |
| Come & Save | `comeAndSave` | `co.tz.comeandsave.pos` | Come & Save POS |
| Leruma | `leruma` | `co.tz.leruma.pos` | Leruma POS |

## Building APKs

### Option 1: Using Build Script (Recommended)

```bash
# Make script executable (first time only)
chmod +x build_client.sh

# Build specific client
./build_client.sh sada          # Build SADA
./build_client.sh comeAndSave   # Build Come & Save
./build_client.sh leruma        # Build Leruma

# Build all clients at once
./build_client.sh all
```

APKs will be saved to `releases/` folder.

### Option 2: Manual Flutter Commands

```bash
# Build SADA
flutter build apk --flavor sada --dart-define=FLAVOR=sada --release

# Build Come & Save
flutter build apk --flavor comeAndSave --dart-define=FLAVOR=comeAndSave --release

# Build Leruma
flutter build apk --flavor leruma --dart-define=FLAVOR=leruma --release
```

APKs will be in `build/app/outputs/flutter-apk/app-{flavor}-release.apk`

## Running in Debug Mode

```bash
# Run SADA
flutter run --flavor sada --dart-define=FLAVOR=sada

# Run Come & Save
flutter run --flavor comeAndSave --dart-define=FLAVOR=comeAndSave

# Run Leruma
flutter run --flavor leruma --dart-define=FLAVOR=leruma
```

## Adding a New Client

1. **Update `android/app/build.gradle.kts`:**
```kotlin
productFlavors {
    // ... existing flavors ...
    create("newClient") {
        dimension = "client"
        applicationId = "co.tz.newclient.pos"
        resValue("string", "app_name", "New Client POS")
    }
}
```

2. **Update `lib/config/clients_config.dart`:**
```dart
// Add to _flavorToClientId map
static const Map<String, String> _flavorToClientId = {
    // ... existing mappings ...
    'newClient': 'new_client',
};

// Add to availableClients list
ClientConfig(
    id: 'new_client',
    name: 'dev-new_client',
    displayName: 'New Client',
    devApiUrl: 'http://...',
    prodApiUrl: 'https://...',
    features: const ClientFeatures(...),
),
```

3. **Update `build_client.sh`:**
```bash
FLAVORS=("sada" "comeAndSave" "leruma" "newClient")
DISPLAY_NAMES["newClient"]="New Client POS"
APP_IDS["newClient"]="co.tz.newclient.pos"
```

## Important Notes

1. **Different App IDs = Different Apps**
   - Each flavor has a unique `applicationId`
   - You can install SADA, Come & Save, and Leruma on the same phone
   - They will appear as separate apps

2. **Build Flavor Must Match Dart Define**
   - Always use both `--flavor` and `--dart-define=FLAVOR=`
   - Example: `--flavor sada --dart-define=FLAVOR=sada`

3. **Debug vs Release**
   - In DEBUG mode: Client switching is allowed (for testing)
   - In RELEASE mode: Client is locked to the build flavor

4. **iOS Support**
   - iOS requires additional setup with Xcode schemes
   - See iOS section below for details

## iOS Setup (Optional)

For iOS, you need to create separate schemes in Xcode:

1. Open `ios/Runner.xcworkspace` in Xcode
2. Duplicate the "Runner" scheme for each client
3. Rename schemes to: `sada`, `comeAndSave`, `leruma`
4. Update bundle identifiers in each scheme's build settings

Build commands for iOS:
```bash
flutter build ios --flavor sada --dart-define=FLAVOR=sada
flutter build ios --flavor comeAndSave --dart-define=FLAVOR=comeAndSave
flutter build ios --flavor leruma --dart-define=FLAVOR=leruma
```
