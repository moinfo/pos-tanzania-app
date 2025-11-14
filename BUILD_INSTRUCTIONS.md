# Build Instructions for Client-Specific APKs

This document explains how to build APK files for specific clients.

## Important: Network Configuration

### Changing IP Address for Development

When your network changes, you only need to update ONE place:

**File:** `lib/config/clients_config.dart`

```dart
// ⚠️ CHANGE THIS IP ADDRESS when your network changes
static const String LOCAL_IP_ADDRESS = '192.168.0.100'; // Your computer's local IP
static const String MAMP_PORT = '8888';
```

This will automatically update the API URLs for all clients in debug mode.

## Quick Start

### Building for a Specific Client

1. **Edit the configuration file:**
   ```bash
   nano lib/config/clients_config.dart
   ```

2. **Change the `PRODUCTION_CLIENT_ID` constant:**
   ```dart
   static const String PRODUCTION_CLIENT_ID = 'come_and_save'; // Change this line
   ```

3. **Build the APK:**
   ```bash
   flutter build apk --release
   ```

4. **Find your APK:**
   ```
   build/app/outputs/flutter-apk/app-release.apk
   ```

## Available Clients

| Client ID | Display Name | Description |
|-----------|--------------|-------------|
| `sada` | SADA | SADA client (default) |
| `come_and_save` | Come & Save | Come & Save client |
| `bonge` | Bonge | Bonge client |
| `iddy` | Iddy | Iddy client |
| `kassim` | Kassim | Kassim client |
| `leruma` | Leruma | Leruma client |
| `mazao` | Mazao | Mazao client |
| `meriwa` | Meriwa | Meriwa client |
| `pingo` | Pingo | Pingo client |
| `plmstore` | PLM Store | PLM Store client |
| `postz` | POSTZ | POSTZ client |
| `qatar` | Qatar | Qatar client |
| `ruge` | Ruge | Ruge client |
| `soko` | Soko | Soko client |
| `tatu` | Tatu | Tatu client |
| `threegroups` | Three Groups | Three Groups client |
| `urafiki` | Urafiki | Urafiki client |
| `vikapu` | Vikapu | Vikapu client |
| `vikas` | Vikas | Vikas client |
| `yahaya` | Yahaya | Yahaya client |
| `zaifood` | Zai Food | Zai Food client |

## Build Examples

### Example 1: Build for SADA
```bash
# 1. Set client ID to 'sada'
sed -i '' 's/PRODUCTION_CLIENT_ID = .*$/PRODUCTION_CLIENT_ID = '\''sada'\'';/' lib/config/clients_config.dart

# 2. Build APK
flutter build apk --release

# 3. Rename APK
mv build/app/outputs/flutter-apk/app-release.apk build/app/outputs/flutter-apk/sada-release.apk
```

### Example 2: Build for Come & Save
```bash
# 1. Set client ID to 'come_and_save'
sed -i '' 's/PRODUCTION_CLIENT_ID = .*$/PRODUCTION_CLIENT_ID = '\''come_and_save'\'';/' lib/config/clients_config.dart

# 2. Build APK
flutter build apk --release

# 3. Rename APK
mv build/app/outputs/flutter-apk/app-release.apk build/app/outputs/flutter-apk/come_and_save-release.apk
```

## Build Script (Automated)

Create a shell script to build for all clients automatically:

```bash
#!/bin/bash

# Array of client IDs
clients=("sada" "come_and_save" "bonge" "iddy" "kassim" "leruma" "mazao" "meriwa" "pingo" "plmstore" "postz" "qatar" "ruge" "soko" "tatu" "threegroups" "urafiki" "vikapu" "vikas" "yahaya" "zaifood")

for client in "${clients[@]}"
do
  echo "Building APK for $client..."

  # Update client ID
  sed -i '' "s/PRODUCTION_CLIENT_ID = .*$/PRODUCTION_CLIENT_ID = '$client';/" lib/config/clients_config.dart

  # Build APK
  flutter build apk --release

  # Rename APK
  mv build/app/outputs/flutter-apk/app-release.apk "build/app/outputs/flutter-apk/${client}-release.apk"

  echo "✅ Built: ${client}-release.apk"
done

echo "🎉 All client APKs built successfully!"
```

## Debug vs Release Behavior

### Debug Mode (Development)
- ✅ Client selector screen available
- ✅ Can switch between all 21 clients
- ✅ "Switch Client" button visible in Settings
- ✅ Uses `devApiUrl` (local development server)

### Release Mode (Production APK)
- ❌ No client selector screen
- ❌ Cannot switch clients
- ❌ "Switch Client" button hidden in Settings
- ✅ Uses `prodApiUrl` (production server)
- ✅ Hardcoded to single client specified in `PRODUCTION_CLIENT_ID`

## Testing

### Test Debug Build
```bash
flutter run --debug
# You should see client selector and switching options
```

### Test Release Build
```bash
flutter build apk --release
flutter install
# You should NOT see client selector or switching options
```

## Important Notes

1. **Always set the correct client** before building for production
2. **Each client connects to a different backend** and database
3. **Stock locations** are automatically fetched from each client's database
4. **Features** can be different per client (e.g., Contracts only in SADA)
5. **Remember to test** the APK on a device before distributing

## Troubleshooting

### Issue: APK connects to wrong backend
**Solution:** Check that `PRODUCTION_CLIENT_ID` is set correctly before building

### Issue: Client selector still shows in release build
**Solution:** Ensure you're building with `--release` flag and not `--debug`

### Issue: Features missing in certain clients
**Solution:** Check `ClientFeatures` configuration in `clients_config.dart`