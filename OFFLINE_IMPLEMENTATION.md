# Offline Mode Implementation - POS Tanzania Mobile App

## Overview

This document describes the offline functionality implementation for the POS Tanzania mobile application. The implementation allows users to work without internet connectivity and automatically synchronizes data when connection is restored.

---

## Implementation Status

| Feature | Status | Notes |
|---------|--------|-------|
| SQLite Database (43 tables) | Done | `lib/services/database_service.dart` |
| Connectivity Monitoring | Done | `lib/providers/connectivity_provider.dart` |
| Offline State Management | Done | `lib/providers/offline_provider.dart` |
| Sync Queue Service | Done | `lib/services/sync_service.dart` |
| Offline Login | Done | Cached credentials with SHA256 hashing |
| Offline Permissions | Done | Cached per client |
| Offline Locations | Done | Cached per client/module |
| Offline Items | Done | Sales screen loads from SQLite |
| Offline Customers | Done | Sales screen loads from SQLite |
| Offline Indicator Widget | Done | `lib/widgets/offline_indicator.dart` |
| Feature Flag per Client | Done | `hasOfflineMode` in `ClientFeatures` |
| Master Data Sync | Done | 24-hour staleness check |
| Offline Sales Creation | Partial | Structure ready, needs testing |

---

## Architecture

### File Structure

```
lib/
├── config/
│   └── clients_config.dart          # hasOfflineMode flag per client
├── models/
│   └── client_config.dart           # ClientFeatures with hasOfflineMode
├── providers/
│   ├── connectivity_provider.dart   # Network monitoring
│   ├── offline_provider.dart        # Offline state & data access
│   ├── auth_provider.dart           # Offline login support
│   ├── location_provider.dart       # Location caching
│   └── permission_provider.dart     # Permission caching
├── services/
│   ├── database_service.dart        # SQLite operations (43 tables)
│   └── sync_service.dart            # Sync queue management
├── widgets/
│   └── offline_indicator.dart       # UI indicator widgets
└── screens/
    ├── login_screen.dart            # Shows offline indicator
    └── sales_screen.dart            # Offline items/customers loading
```

### Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                      OFFLINE MODE FLOW                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. FIRST LOGIN (Online Required)                               │
│     ┌──────────┐     ┌──────────┐     ┌──────────┐             │
│     │  Login   │────►│  Cache   │────►│  Sync    │             │
│     │  Online  │     │  Creds   │     │  Master  │             │
│     └──────────┘     └──────────┘     │  Data    │             │
│                                       └──────────┘             │
│                                                                 │
│  2. SUBSEQUENT LOGINS (Can be Offline)                          │
│     ┌──────────┐     ┌──────────┐     ┌──────────┐             │
│     │  Login   │────►│  Verify  │────►│  Load    │             │
│     │  Offline │     │  Cached  │     │  From    │             │
│     └──────────┘     │  Hash    │     │  SQLite  │             │
│                      └──────────┘     └──────────┘             │
│                                                                 │
│  3. SALES (Offline)                                             │
│     ┌──────────┐     ┌──────────┐     ┌──────────┐             │
│     │  Create  │────►│  Save to │────►│  Queue   │             │
│     │  Sale    │     │  SQLite  │     │  for     │             │
│     └──────────┘     └──────────┘     │  Sync    │             │
│                                       └──────────┘             │
│                                                                 │
│  4. AUTO SYNC (When Online)                                     │
│     ┌──────────┐     ┌──────────┐     ┌──────────┐             │
│     │  Detect  │────►│  Process │────►│  Update  │             │
│     │  Online  │     │  Queue   │     │  Status  │             │
│     └──────────┘     └──────────┘     └──────────┘             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## How to Enable Offline Mode

### 1. Enable for a Client

Edit `lib/config/clients_config.dart`:

```dart
ClientConfig(
  id: 'your_client',
  name: 'dev-your_client',
  displayName: 'Your Client',
  devApiUrl: '...',
  prodApiUrl: '...',
  features: const ClientFeatures(
    // Enable offline mode
    hasOfflineMode: true,
  ),
),
```

### 2. First-Time Setup (User)

1. **Connect to internet**
2. **Login** - credentials and master data will be cached
3. **Wait for sync** - items, customers, locations are downloaded
4. Look for log messages:
   ```
   💾 Credentials cached for offline login
   💾 Permissions saved locally
   💾 Locations cached for module: sales
   📦 Syncing items... (X items)
   👥 Syncing customers... (X customers)
   ```

### 3. Using Offline Mode

1. **Go offline** (Airplane mode or disable WiFi)
2. **Login** - uses cached credentials
3. **Use Sales** - items/customers load from SQLite
4. **Create sales** - saved locally, queued for sync
5. **Go online** - sales auto-sync to server

---

## Key Components

### 1. ConnectivityProvider

Monitors network connectivity status.

```dart
// lib/providers/connectivity_provider.dart

class ConnectivityProvider extends ChangeNotifier {
  bool get isOnline => _isOnline;
  ConnectivityResult get connectionType => _connectionType;
  String get connectionTypeString => ...;

  Future<void> initialize() async { ... }
}
```

**Usage:**
```dart
final connectivity = context.read<ConnectivityProvider>();
if (connectivity.isOnline) {
  // Online - use API
} else {
  // Offline - use local database
}
```

### 2. OfflineProvider

Manages offline state, data access, and sync operations.

```dart
// lib/providers/offline_provider.dart

class OfflineProvider extends ChangeNotifier {
  // State
  bool get isInitialized => _isInitialized;
  bool get isSyncing => _isSyncing;
  int get pendingSyncCount => _pendingSyncCount;
  int get failedSyncCount => _failedSyncCount;

  // Master data sync
  Future<void> syncMasterData() async { ... }

  // Offline data access
  Future<List<Map>> getOfflineItems({locationId, search, limit}) async { ... }
  Future<List<Map>> getOfflineCustomers({search, limit}) async { ... }

  // Offline sale creation
  Future<int?> createOfflineSale(sale, items, payments) async { ... }

  // Manual sync
  Future<bool> triggerSync() async { ... }
  Future<void> retryFailedSync() async { ... }
}
```

### 3. DatabaseService

SQLite database with 43 tables for offline storage.

```dart
// lib/services/database_service.dart

class DatabaseService {
  // Initialization
  Future<void> initDatabase(String clientId) async { ... }

  // Master data operations
  Future<void> saveItems(List<Map> items) async { ... }
  Future<void> saveCustomers(List<Map> customers) async { ... }
  Future<void> saveStockLocations(List<Map> locations) async { ... }

  // Query operations
  Future<List<Map>> getItemsWithQuantities({locationId, search}) async { ... }
  Future<List<Map>> getCustomers({search}) async { ... }

  // Sale operations
  Future<int> createLocalSale(sale, items, payments) async { ... }
  Future<List<Map>> getPendingSales() async { ... }
  Future<void> markSaleSynced(localId, serverId) async { ... }
}
```

### 4. SyncService

Handles sync queue and background synchronization.

```dart
// lib/services/sync_service.dart

class SyncService {
  // Queue management
  Future<void> addToSyncQueue(type, id, action, payload) async { ... }
  Future<List<Map>> getPendingSyncItems() async { ... }

  // Sync operations
  Future<SyncResult> syncPendingSales() async { ... }
  Future<void> processSyncQueue() async { ... }
}
```

### 5. OfflineIndicator Widget

UI widget showing online/offline status.

```dart
// lib/widgets/offline_indicator.dart

// Compact indicator for app bars
OfflineIndicator(compact: true)

// Full-width banner
OfflineBanner()

// Small badge with count
SyncBadge()
```

**States:**
- Green "Online" - Connected to internet
- Grey "Offline" - No connection
- Blue "Syncing..." - Sync in progress
- Orange "Pending" - Has unsynced data
- Orange "Sync Failed" - Sync errors

---

## Offline Login Flow

### Credential Caching

```dart
// On successful online login:
1. Hash password with SHA256 (salted with username + clientId)
2. Store: { username, passwordHash, salt }
3. Store: user data as JSON

// On offline login:
1. Load cached credentials
2. Verify username matches
3. Hash input password with same salt
4. Compare hashes
5. Load cached user data
```

### Security

- Passwords are **never stored in plain text**
- SHA256 hash with unique salt per user/client
- Cached data is client-specific (separate databases)

---

## Data Caching Strategy

### Master Data (Server → Mobile)

| Data | Cached | Refresh |
|------|--------|---------|
| Items + Quantities | Yes | Every 24 hours |
| Customers | Yes | Every 24 hours |
| Stock Locations | Yes | On module change |
| Permissions | Yes | On login |
| Expense Categories | Yes | Every 24 hours |
| Suppliers | Yes | Every 24 hours |

### Transactional Data (Mobile → Server)

| Data | Stored Locally | Sync Priority |
|------|----------------|---------------|
| Sales | Yes | High |
| Expenses | Yes | Medium |
| Receivings | Yes | Medium |
| Customer Deposits | Yes | Medium |

---

## Client Data Isolation

Each client has a separate SQLite database:

```
Application Documents/
├── pos_sada_offline.db
├── pos_comeandsave_offline.db
└── pos_leruma_offline.db
```

This ensures:
- No data mixing between clients
- Independent sync queues
- Separate cached credentials

---

## Dependencies

```yaml
# pubspec.yaml

dependencies:
  # SQLite database
  sqflite: ^2.3.0
  path: ^1.8.3

  # Network monitoring
  connectivity_plus: ^5.0.2

  # Password hashing
  crypto: ^3.0.3
```

---

## Testing Offline Mode

### Manual Testing Steps

1. **Enable offline mode** for client in `clients_config.dart`
2. **Run app** connected to internet
3. **Login** and wait for master data sync
4. **Verify logs:**
   ```
   💾 Credentials cached for offline login
   💾 Permissions saved locally (X permissions)
   💾 Locations cached for module: sales (X locations)
   📦 Loaded X items from offline database
   ```
5. **Logout**
6. **Enable airplane mode**
7. **Login** - should work offline
8. **Go to Sales** - items/customers should load
9. **Create a sale** - should save locally
10. **Disable airplane mode**
11. **Check sync** - sale should sync to server

### Checking Offline Status

Look for these indicators:
- **Login screen**: Small indicator in top-left
- **Sales screen**: Indicator in app bar
- **Console logs**: Emoji-prefixed messages

---

## Troubleshooting

### "No offline credentials found"

- User hasn't logged in online first
- Solution: Connect to internet and login

### "No cached items/customers"

- Master data hasn't been synced
- Solution: Login online, wait for sync to complete

### Offline indicator not showing

- `hasOfflineMode: false` for the client
- Solution: Enable in `clients_config.dart`

### Sync failing

- Check `failedSyncCount` in OfflineProvider
- Use `retryFailedSync()` to retry
- Check server logs for API errors

---

## Future Improvements

| Feature | Priority | Status |
|---------|----------|--------|
| Offline sale creation | High | In Progress |
| Sync conflict resolution | Medium | Planned |
| Background sync | Medium | Planned |
| Sync history screen | Low | Planned |
| Offline receivings | Low | Planned |
| Offline expenses | Low | Planned |

---

## Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2024-12-23 | 1.0.0 | Initial implementation |
| | | - SQLite database (43 tables) |
| | | - Connectivity monitoring |
| | | - Offline login with cached credentials |
| | | - Master data sync (items, customers, locations) |
| | | - Offline indicator widgets |
| | | - Sales screen offline support |
| | | - Feature flag per client |
