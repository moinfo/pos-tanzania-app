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

## Security: Client-Specific Token Validation

### Overview

The mobile app implements **client-specific token validation** to prevent authentication tokens from being used across different clients. This is important because:

1. Each client (SADA, Come & Save, etc.) has its own separate backend and database
2. The backends share the same JWT encryption key
3. Without validation, a token from one client could theoretically work on another client's API

### How It Works

#### Token Storage
When a user logs in, the app stores:
- **`auth_token`**: The JWT token from the backend
- **`auth_token_client_id`**: The client ID (e.g., 'sada', 'come_and_save')

```dart
// Example: User logs into SADA
await saveToken(token);
// Stores:
// - auth_token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
// - auth_token_client_id: "sada"
```

#### Token Validation
When the app loads a token from storage, it automatically validates:

1. **Does a stored token exist?**
2. **Does the stored client_id match the current client?**
3. **If mismatch detected** → Clear token and force re-login

```dart
// Example: Token validation on app start
getToken() async {
  final storedToken = await _storage.read(key: 'auth_token');
  final storedClientId = await _storage.read(key: 'auth_token_client_id');
  final currentClientId = currentClient?.id ?? 'sada';

  if (storedClientId != currentClientId) {
    print('⚠️ Token client mismatch: stored=$storedClientId, current=$currentClientId');
    await clearToken(); // Clear invalid token
    return null;        // User sent to login
  }

  return storedToken;
}
```

#### Client Switching Flow

When a user switches clients:

1. **Clear client cache**: `ApiService.clearCurrentClient()`
2. **Logout**: `authProvider.logout()`
   - Clears `auth_token`
   - Clears `auth_token_client_id`
   - Clears permissions
3. **Navigate to client selector**
4. **User selects new client** (e.g., Come & Save)
5. **User logs in again** with new client credentials
6. **New token stored** with new client_id

```dart
// User switches from SADA to Come & Save
await ApiService.clearCurrentClient();  // Clear cached client
await authProvider.logout();            // Clear token + client_id
// Navigate to client selector...
// User logs into Come & Save...
// New token stored with client_id: "come_and_save"
```

### Security Benefits

1. **Prevents Cross-Client Token Usage**: A SADA token cannot be used on Come & Save API
2. **Automatic Token Cleanup**: Invalid tokens are automatically cleared
3. **Client Isolation**: Each client has its own authentication session
4. **User Safety**: Users must explicitly log in to each client

### Backend JWT Configuration

Both SADA and Come & Save backends use:

**JWT Library**: `application/libraries/JWT_Lib.php`
- Algorithm: HS256 (HMAC-SHA256)
- Encryption Key: From `config['encryption_key']` + `'_jwt_secret'`
- Token Expiry: 24 hours (86400 seconds)

**Token Structure**:
```json
{
  "iss": "http://192.168.0.100:8888/PointOfSalesTanzania/public",
  "iat": 1673024400,
  "exp": 1673110800,
  "sub": "1",
  "username": "admin",
  "data": {
    "username": "admin",
    "first_name": "Admin",
    "last_name": "User",
    "email": "admin@example.com"
  }
}
```

**Note**: While both backends use the same encryption key, the mobile app enforces client-specific validation at the application layer.

### Implementation Details

**File**: `lib/services/api_service.dart:102-145`

Key methods:
- `getToken()`: Retrieves and validates token against current client
- `saveToken(token)`: Stores token with current client ID
- `clearToken()`: Removes both token and client ID from storage

### Testing Client-Specific Authentication

1. **Test token isolation**:
   ```bash
   # 1. Login to SADA in debug mode
   # 2. Switch to Come & Save
   # 3. Verify you're sent to login screen (token cleared)
   ```

2. **Test token persistence**:
   ```bash
   # 1. Login to Come & Save
   # 2. Close app
   # 3. Reopen app
   # 4. Verify you're still logged into Come & Save (not SADA)
   ```

3. **Test production build**:
   ```bash
   # 1. Build APK for SADA
   # 2. Login to SADA
   # 3. Verify no client switching available (security)
   ```

## Troubleshooting

### Issue: APK connects to wrong backend
**Solution:** Check that `PRODUCTION_CLIENT_ID` is set correctly before building

### Issue: Client selector still shows in release build
**Solution:** Ensure you're building with `--release` flag and not `--debug`

### Issue: Features missing in certain clients
**Solution:** Check `ClientFeatures` configuration in `clients_config.dart`