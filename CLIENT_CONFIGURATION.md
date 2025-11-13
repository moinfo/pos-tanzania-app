# Client Configuration Guide

## Overview

The POS Tanzania Mobile App supports multiple clients through a dynamic client configuration system. This allows a single app to connect to different backend servers for different clients.

## 📱 How It Works

### Client Selection Flow

```
App Launch → Check Client Selection → Client Selector Screen
                                    ↓
                              Client Selected
                                    ↓
                            Login Screen → Home
```

### Architecture

```
┌─────────────────────────────────────┐
│     Mobile App (Single APK)         │
├─────────────────────────────────────┤
│   Client Selector (21 clients)     │
├─────────────────────────────────────┤
│     API Service (Dynamic URLs)      │
└─────────────────────────────────────┘
              ↓
    ┌─────────────────────┐
    │  Backend Branches   │
    ├─────────────────────┤
    │  • dev-sada         │
    │  • dev-come_and_save│
    │  • dev-pingo        │
    │  • dev-mazao        │
    │  • ... (17 more)    │
    └─────────────────────┘
```

## 🔧 Configuration Files

### 1. Client Configuration Model
**File:** `lib/models/client_config.dart`

Defines the structure for client configuration:
```dart
class ClientConfig {
  final String id;           // Unique identifier (e.g., "sada")
  final String name;         // Branch name (e.g., "dev-sada")
  final String displayName;  // Display name (e.g., "SADA")
  final String devApiUrl;    // Development API URL
  final String prodApiUrl;   // Production API URL
  final String? logoUrl;     // Optional logo
  final bool isActive;       // Active status
}
```

### 2. Clients Configuration
**File:** `lib/config/clients_config.dart`

Contains all available clients and their API endpoints:

```dart
class ClientsConfig {
  static final List<ClientConfig> availableClients = [
    ClientConfig(
      id: 'sada',
      name: 'dev-sada',
      displayName: 'SADA',
      devApiUrl: 'http://172.16.245.29:8888/PointOfSalesTanzania/public/api',
      prodApiUrl: 'https://sada.moinfotech.co.tz/api',
    ),
    // ... 20 more clients
  ];
}
```

### 3. API Service
**File:** `lib/services/api_service.dart`

Handles dynamic API URL switching based on selected client:

```dart
class ApiService {
  // Get current client configuration
  static Future<ClientConfig> getCurrentClient() async { ... }

  // Set current client
  static Future<void> setCurrentClient(String clientId) async { ... }

  // Get base URL (dynamic)
  static Future<String> get baseUrl async { ... }
}
```

## 📋 Available Clients

| ID | Display Name | Branch Name | Status |
|----|--------------|-------------|--------|
| sada | SADA | dev-sada | ✅ Active |
| come_and_save | Come & Save | dev-come_and_save | ✅ Active |
| bonge | Bonge | dev-bonge | Available |
| iddy | Iddy | dev-iddy | Available |
| kassim | Kassim | dev-kassim | Available |
| leruma | Leruma | dev-leruma | Available |
| mazao | Mazao | dev-mazao | Available |
| meriwa | Meriwa | dev-meriwa | Available |
| pingo | Pingo | dev-pingo | Available |
| plmstore | PLM Store | dev-plmstore | Available |
| postz | POSTZ | dev-postz | Available |
| qatar | Qatar | dev-qatar | Available |
| ruge | Ruge | dev-ruge | Available |
| sanira | Sanira | dev-sanira | Available |
| sgs | SGS | dev-sgs | Available |
| shorasho | Shorasho | dev-shorasho | Available |
| shukuma | Shukuma | dev-shukuma | Available |
| trishbake | TrishBake | dev-trishbake | Available |
| whitestar | White Star | dev-whitestar | Available |
| zai | Zai | dev-zai | Available |
| zaifood | Zai Food | dev-zaifood | Available |

## 🚀 Usage

### For End Users

1. **First Launch:**
   - Open the app
   - Select your client from the list
   - Login with your credentials

2. **Switching Clients:**
   - Go to Settings
   - Tap "Switch Client"
   - Select a different client
   - Login again

3. **Search for Client:**
   - On the client selector screen
   - Use the search bar at the top
   - Type client name to filter

### For Developers

#### Adding a New Client

1. **Open:** `lib/config/clients_config.dart`

2. **Add to the list:**
```dart
ClientConfig(
  id: 'new_client',
  name: 'dev-new_client',
  displayName: 'New Client',
  devApiUrl: 'http://172.16.245.29:8888/PointOfSalesTanzania/public/api',
  prodApiUrl: 'https://newclient.moinfotech.co.tz/api',
  isActive: true,
),
```

3. **Test:**
```bash
flutter run
# Select the new client
# Verify API connection
```

#### Updating Production URLs

Edit `lib/config/clients_config.dart`:

```dart
ClientConfig(
  id: 'sada',
  name: 'dev-sada',
  displayName: 'SADA',
  devApiUrl: 'http://172.16.245.29:8888/PointOfSalesTanzania/public/api',
  prodApiUrl: 'https://new-url.moinfotech.co.tz/api', // ← Update here
),
```

#### Removing a Client

Set `isActive: false`:

```dart
ClientConfig(
  id: 'old_client',
  name: 'dev-old_client',
  displayName: 'Old Client',
  devApiUrl: '...',
  prodApiUrl: '...',
  isActive: false, // ← Disable
),
```

## 🔄 API URL Switching

### Development Mode (Debug)

When running with `flutter run`:
```
All clients use: http://172.16.245.29:8888/PointOfSalesTanzania/public/api
```

**Why?** During development, all clients connect to your local backend for testing.

### Production Mode (Release)

When building APK with `flutter build apk`:
```
Each client uses its specific production URL:
- SADA: https://sada.moinfotech.co.tz/api
- Come & Save: https://comeandsave.moinfotech.co.tz/api
- Pingo: https://pingo.moinfotech.co.tz/api
- etc...
```

### How to Change Mode

The app automatically detects the mode using Flutter's `kReleaseMode`:

```dart
// In lib/services/api_service.dart
if (kReleaseMode) {
  return client.prodApiUrl;  // Production
} else {
  return client.devApiUrl;   // Development
}
```

## 🧪 Testing

### Test Different Clients Locally

1. **Start MAMP** with your backend

2. **Update IP Address** (if changed):
   - Edit `lib/config/clients_config.dart`
   - Change `localBaseUrl` to your current IP

3. **Run the app:**
```bash
flutter run
```

4. **Select Client** and test

### Test with Multiple Backends

If you have worktrees set up:

**Backend 1 (SADA):**
```
http://172.16.245.29:8888/PointOfSalesTanzania/public/api
```

**Backend 2 (Come & Save):**
```
http://172.16.245.29:8888/PointOfSalesTanzania-come_and_save/public/api
```

**Update configuration:**
```dart
ClientConfig(
  id: 'come_and_save',
  name: 'dev-come_and_save',
  displayName: 'Come & Save',
  devApiUrl: 'http://172.16.245.29:8888/PointOfSalesTanzania-come_and_save/public/api',
  prodApiUrl: 'https://comeandsave.moinfotech.co.tz/api',
),
```

## 🎨 Client Selector UI

**Location:** `lib/screens/client_selector_screen.dart`

### Features

- **Glassmorphic Design**: Modern, translucent UI
- **Search Functionality**: Filter clients by name
- **Visual Indicator**: Shows currently selected client
- **Smooth Navigation**: Transitions to login after selection

### Customization

To customize the UI, edit `lib/screens/client_selector_screen.dart`:

```dart
// Change colors
Colors.blue.shade800  // Gradient start
Colors.purple.shade600 // Gradient end

// Change icon
Icon(Icons.store)  // Client icon

// Change search behavior
onChanged: (value) {
  setState(() {
    _searchQuery = value;
  });
}
```

## 📱 Settings Integration

**Location:** `lib/screens/settings_screen.dart`

The settings screen includes a "Switch Client" option:

```dart
ListTile(
  title: Text('Switch Client'),
  subtitle: Text('Current: $_currentClientName'),
  trailing: Icon(Icons.arrow_forward_ios),
  onTap: () async {
    // Logout and go to client selector
    await authProvider.logout();
    Navigator.pushReplacement(...);
  },
),
```

## 🔐 Data Storage

Client selection is stored using `SharedPreferences`:

```dart
// Save selected client
final prefs = await SharedPreferences.getInstance();
await prefs.setString('selected_client_id', 'sada');

// Retrieve selected client
final clientId = prefs.getString('selected_client_id');
```

**Storage Key:** `selected_client_id`

## 🐛 Troubleshooting

### Issue: "Cannot connect to API"

**Solution:**
1. Check if MAMP is running
2. Verify IP address in `clients_config.dart`
3. Test URL in browser: `http://172.16.245.29:8888/PointOfSalesTanzania/public/api/auth/login`
4. Check network connectivity

### Issue: "Client not appearing in list"

**Solution:**
1. Check `isActive: true` in `clients_config.dart`
2. Restart the app
3. Clear app data and reinstall

### Issue: "Wrong API URL in production"

**Solution:**
1. Check `prodApiUrl` in `clients_config.dart`
2. Rebuild the APK: `flutter build apk`
3. Reinstall the app

### Issue: "Client selection not persisting"

**Solution:**
```bash
# Clear app data
flutter clean

# Reinstall
flutter run
```

## 📦 Building for Production

### Single APK for All Clients

```bash
# Build release APK
flutter build apk --release

# Output location
build/app/outputs/flutter-apk/app-release.apk
```

### Client-Specific APK (Optional)

If you want separate APKs per client, use Flutter Flavors:

```bash
flutter build apk --release --flavor sada
flutter build apk --release --flavor comeandsave
```

## 🔄 Updating Clients

### Backend Update Required

When backend changes affect the API:

1. Update `pubspec.yaml` version
2. Commit changes
3. Push to repository
4. Build new APK
5. Distribute to clients

### Configuration Update Only

When only URLs change:

1. Edit `lib/config/clients_config.dart`
2. Commit and push
3. Rebuild APK
4. Distribute update

## 📚 Related Documentation

- **Backend Multi-Branch Setup:** `/Applications/MAMP/htdocs/PointOfSalesTanzania/DUAL_BRANCH_WORKFLOW.md`
- **Quick Start Guide:** `/Applications/MAMP/htdocs/PointOfSalesTanzania/QUICK_START.md`
- **Mobile App README:** `README.md`

## 🔗 Repository Links

- **Mobile App:** https://github.com/moinfo/pos-tanzania-app
- **Backend:** https://github.com/moinfo/PointOfSalesTanzania

## 💡 Best Practices

1. **Always test** client configuration changes locally before production
2. **Keep URLs updated** in `clients_config.dart`
3. **Use meaningful client IDs** (lowercase, no spaces)
4. **Document** any custom client configurations
5. **Version control** all configuration changes

## 📞 Support

For issues or questions:
- Check this documentation
- Review backend documentation
- Test API endpoints manually
- Verify client configuration

---

**Last Updated:** November 13, 2025
**Version:** 1.0.0
**Maintained By:** Development Team