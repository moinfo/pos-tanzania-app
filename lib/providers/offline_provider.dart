import 'package:flutter/foundation.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../services/api_service.dart';
import 'connectivity_provider.dart';

/// Provider to manage offline functionality and data synchronization
class OfflineProvider extends ChangeNotifier {
  final ConnectivityProvider _connectivityProvider;
  final ApiService _apiService;

  DatabaseService? _databaseService;
  SyncService? _syncService;

  // State
  bool _isInitialized = false;
  bool _isSyncing = false;
  int _pendingSyncCount = 0;
  int _failedSyncCount = 0;
  String? _currentClientId;
  String? _lastSyncError;
  DateTime? _lastSyncTime;

  // Master data sync state
  bool _isSyncingMasterData = false;
  double _masterDataSyncProgress = 0.0;
  String? _masterDataSyncStatus;

  /// Whether offline mode is initialized
  bool get isInitialized => _isInitialized;

  /// Whether currently syncing
  bool get isSyncing => _isSyncing;

  /// Number of pending sync items
  int get pendingSyncCount => _pendingSyncCount;

  /// Number of failed sync items
  int get failedSyncCount => _failedSyncCount;

  /// Current client ID
  String? get currentClientId => _currentClientId;

  /// Last sync error message
  String? get lastSyncError => _lastSyncError;

  /// Last successful sync time
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Whether syncing master data
  bool get isSyncingMasterData => _isSyncingMasterData;

  /// Master data sync progress (0.0 - 1.0)
  double get masterDataSyncProgress => _masterDataSyncProgress;

  /// Current master data sync status message
  String? get masterDataSyncStatus => _masterDataSyncStatus;

  /// Whether there are pending items to sync
  bool get hasPendingSync => _pendingSyncCount > 0;

  /// Whether there are failed sync items
  bool get hasFailedSync => _failedSyncCount > 0;

  /// Get database service
  DatabaseService? get database => _databaseService;

  /// Get sync service
  SyncService? get syncService => _syncService;

  /// Whether the app is in offline mode
  bool get isOfflineMode => _connectivityProvider.isOffline;

  /// Whether the app is online
  bool get isOnline => _connectivityProvider.isOnline;

  OfflineProvider({
    required ConnectivityProvider connectivityProvider,
    required ApiService apiService,
  })  : _connectivityProvider = connectivityProvider,
        _apiService = apiService {
    // Listen to connectivity changes
    _connectivityProvider.addListener(_onConnectivityChanged);
  }

  /// Initialize offline mode for a client
  Future<void> initialize(String clientId) async {
    if (_isInitialized && _currentClientId == clientId) {
      debugPrint('OfflineProvider: Already initialized for client $clientId');
      return;
    }

    debugPrint('OfflineProvider: Initializing for client $clientId...');

    // Close existing database if switching clients
    if (_currentClientId != null && _currentClientId != clientId) {
      await _databaseService?.closeDatabase();
      _syncService?.dispose();
    }

    _currentClientId = clientId;

    // Initialize database
    _databaseService = DatabaseService.instance;
    await _databaseService!.initDatabase(clientId);

    // Initialize sync service
    _syncService = SyncService.getInstance(
      dbService: _databaseService!,
      apiService: _apiService,
    );

    // Set up sync callbacks
    _syncService!.onSyncStatusChanged = _onSyncStatusChanged;
    _syncService!.onSyncCountChanged = _onSyncCountChanged;
    _syncService!.onItemSynced = _onItemSynced;

    await _syncService!.initialize();

    // Update counts
    await _updateSyncCounts();

    _isInitialized = true;
    notifyListeners();

    debugPrint('OfflineProvider: Initialized successfully');

    // Only sync master data if online AND data is stale (older than 24 hours) or first time
    if (_connectivityProvider.isOnline) {
      final shouldSync = await _shouldSyncMasterData();
      if (shouldSync) {
        await syncMasterData();
      } else {
        debugPrint('OfflineProvider: Master data is fresh, skipping sync');
      }
    }
  }

  /// Check if master data needs syncing (older than 24 hours or never synced)
  Future<bool> _shouldSyncMasterData() async {
    if (_databaseService == null) return true;

    try {
      final lastSync = await _databaseService!.getLastSyncTimestamp('items');
      if (lastSync == null) {
        debugPrint('OfflineProvider: No previous sync found, will sync');
        return true; // Never synced
      }

      final lastSyncTime = DateTime.parse(lastSync);
      final hoursSinceSync = DateTime.now().difference(lastSyncTime).inHours;
      debugPrint('OfflineProvider: Last sync was $hoursSinceSync hours ago');

      // Sync if older than 24 hours
      return hoursSinceSync >= 24;
    } catch (e) {
      debugPrint('OfflineProvider: Error checking sync time - $e');
      return true; // Sync on error
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged() {
    debugPrint('OfflineProvider: Connectivity changed - Online: ${_connectivityProvider.isOnline}');

    if (_connectivityProvider.isOnline && _isInitialized) {
      // Trigger sync when coming back online
      _syncService?.syncAll();
    }

    notifyListeners();
  }

  /// Handle sync status changes
  void _onSyncStatusChanged(SyncStatus status) {
    _isSyncing = status == SyncStatus.syncing;

    if (status == SyncStatus.completed) {
      _lastSyncTime = DateTime.now();
      _lastSyncError = null;
    } else if (status == SyncStatus.failed) {
      _lastSyncError = 'Sync failed';
    }

    notifyListeners();
  }

  /// Handle sync count changes
  void _onSyncCountChanged(int pending, int failed) {
    _pendingSyncCount = pending;
    _failedSyncCount = failed;
    notifyListeners();
  }

  /// Handle individual item sync
  void _onItemSynced(SyncResult result) {
    debugPrint('OfflineProvider: Item synced - ${result.entityType} ${result.entityId}: ${result.success}');
    _updateSyncCounts();
  }

  /// Update sync counts
  Future<void> _updateSyncCounts() async {
    if (_databaseService != null) {
      final counts = await _databaseService!.getSyncQueueCounts();
      _pendingSyncCount = counts['pending'] ?? 0;
      _failedSyncCount = counts['failed'] ?? 0;
      notifyListeners();
    }
  }

  /// Sync master data from server (items, customers, etc.)
  Future<void> syncMasterData({bool force = false}) async {
    if (!_isInitialized || _databaseService == null) {
      debugPrint('OfflineProvider: Cannot sync master data - not initialized');
      return;
    }

    if (!_connectivityProvider.isOnline) {
      debugPrint('OfflineProvider: Cannot sync master data - offline');
      return;
    }

    if (_isSyncingMasterData && !force) {
      debugPrint('OfflineProvider: Already syncing master data');
      return;
    }

    _isSyncingMasterData = true;
    _masterDataSyncProgress = 0.0;
    _masterDataSyncStatus = 'Starting sync...';
    notifyListeners();

    try {
      debugPrint('OfflineProvider: Starting master data sync...');

      // Sync stock locations
      _masterDataSyncStatus = 'Syncing stock locations...';
      _masterDataSyncProgress = 0.1;
      notifyListeners();
      await _syncStockLocations();

      // Sync items
      _masterDataSyncStatus = 'Syncing items...';
      _masterDataSyncProgress = 0.3;
      notifyListeners();
      await _syncItems();

      // Sync customers
      _masterDataSyncStatus = 'Syncing customers...';
      _masterDataSyncProgress = 0.5;
      notifyListeners();
      await _syncCustomers();

      // Sync suppliers
      _masterDataSyncStatus = 'Syncing suppliers...';
      _masterDataSyncProgress = 0.6;
      notifyListeners();
      await _syncSuppliers();

      // Sync expense categories
      _masterDataSyncStatus = 'Syncing expense categories...';
      _masterDataSyncProgress = 0.7;
      notifyListeners();
      await _syncExpenseCategories();

      // Sync one-time discounts
      _masterDataSyncStatus = 'Syncing discounts...';
      _masterDataSyncProgress = 0.8;
      notifyListeners();
      await _syncOneTimeDiscounts();

      // Sync quantity offers
      _masterDataSyncStatus = 'Syncing offers...';
      _masterDataSyncProgress = 0.9;
      notifyListeners();
      await _syncQuantityOffers();

      _masterDataSyncStatus = 'Sync complete';
      _masterDataSyncProgress = 1.0;
      _lastSyncTime = DateTime.now();

      debugPrint('OfflineProvider: Master data sync completed');
    } catch (e) {
      debugPrint('OfflineProvider: Master data sync failed - $e');
      _masterDataSyncStatus = 'Sync failed: $e';
      _lastSyncError = e.toString();
    } finally {
      _isSyncingMasterData = false;
      notifyListeners();
    }
  }

  /// Sync stock locations
  Future<void> _syncStockLocations() async {
    try {
      final response = await _apiService.getAllStockLocations();
      if (response.isSuccess && response.data != null) {
        final locations = response.data!.map((l) => {
          'location_id': l.locationId,
          'location_name': l.locationName,
          'deleted': l.deleted ? 1 : 0,
        }).toList();

        await _databaseService!.saveStockLocations(locations);
        await _databaseService!.updateLastSyncTimestamp('stock_locations');
      }
    } catch (e) {
      debugPrint('OfflineProvider: Failed to sync stock locations - $e');
    }
  }

  /// Sync items
  Future<void> _syncItems() async {
    try {
      // Get items in batches
      int offset = 0;
      const limit = 100;
      bool hasMore = true;

      while (hasMore) {
        final response = await _apiService.getItems(
          limit: limit,
          offset: offset,
        );

        if (response.isSuccess && response.data != null && response.data!.isNotEmpty) {
          final items = response.data!.map((item) => {
            'item_id': item.itemId,
            'name': item.name,
            'category': item.category,
            'supplier_id': item.supplierId,
            'item_number': item.itemNumber,
            'description': item.description,
            'cost_price': item.costPrice,
            'unit_price': item.unitPrice,
            'reorder_level': item.reorderLevel,
            'stock_type': item.stockType,
            'item_type': item.itemType,
            'is_serialized': item.isSerialized ? 1 : 0,
            'discount_limit': item.discountLimit,
            'tax1_name': item.tax1Name,
            'tax1_percent': item.tax1Percent,
            'tax2_name': item.tax2Name,
            'tax2_percent': item.tax2Percent,
            'dormant': 0,
            'is_deleted': 0,
          }).toList();

          await _databaseService!.saveItems(items);

          // Save quantities
          final quantities = <Map<String, dynamic>>[];
          for (final item in response.data!) {
            if (item.quantityByLocation != null) {
              for (final entry in item.quantityByLocation!.entries) {
                quantities.add({
                  'item_id': item.itemId,
                  'location_id': entry.key,
                  'quantity': entry.value,
                });
              }
            }
          }

          if (quantities.isNotEmpty) {
            await _databaseService!.saveItemQuantities(quantities);
          }

          offset += limit;
          hasMore = response.data!.length >= limit;
        } else {
          hasMore = false;
        }
      }

      await _databaseService!.updateLastSyncTimestamp('items');
    } catch (e) {
      debugPrint('OfflineProvider: Failed to sync items - $e');
    }
  }

  /// Sync customers
  Future<void> _syncCustomers() async {
    try {
      int offset = 0;
      const limit = 100;
      bool hasMore = true;

      while (hasMore) {
        final response = await _apiService.getCustomers(
          limit: limit,
          offset: offset,
        );

        if (response.isSuccess && response.data != null && response.data!.isNotEmpty) {
          final customers = response.data!.map((c) => {
            'person_id': c.personId,
            'first_name': c.firstName,
            'last_name': c.lastName,
            'phone_number': c.phoneNumber,
            'email': c.email,
            'address1': c.address1,
            'address2': c.address2,
            'city': c.city,
            'company_name': c.companyName,
            'discount_percent': c.discount,
            'discount_type': c.discountType,
            'is_allowed_credit': c.isAllowedCredit ? 1 : 0,
            'credit_limit': c.creditLimit,
            'balance': c.balance,
            'taxable': c.taxable ? 1 : 0,
            'dormant': c.dormant == 'DORMANT' ? 1 : 0,
          }).toList();

          await _databaseService!.saveCustomers(customers);

          offset += limit;
          hasMore = response.data!.length >= limit;
        } else {
          hasMore = false;
        }
      }

      await _databaseService!.updateLastSyncTimestamp('customers');
    } catch (e) {
      debugPrint('OfflineProvider: Failed to sync customers - $e');
    }
  }

  /// Sync suppliers
  Future<void> _syncSuppliers() async {
    try {
      final response = await _apiService.getSuppliers();
      if (response.isSuccess && response.data != null) {
        final suppliers = response.data!.map((s) => {
          'person_id': s.supplierId,
          'first_name': s.firstName,
          'last_name': s.lastName,
          'phone_number': s.phoneNumber,
          'email': s.email,
          'company_name': s.companyName,
          'agency_name': s.agencyName,
          'account_number': s.accountNumber,
          'deleted': 0,
        }).toList();

        await _databaseService!.saveSuppliers(suppliers);
        await _databaseService!.updateLastSyncTimestamp('suppliers');
      }
    } catch (e) {
      debugPrint('OfflineProvider: Failed to sync suppliers - $e');
    }
  }

  /// Sync expense categories
  Future<void> _syncExpenseCategories() async {
    try {
      final response = await _apiService.getExpenseCategories();
      if (response.isSuccess && response.data != null) {
        final categories = response.data!.map((c) => {
          'expense_category_id': c.id,
          'category_name': c.name,
          'category_description': c.description ?? '',
          'deleted': 0,
        }).toList();

        await _databaseService!.saveExpenseCategories(categories);
        await _databaseService!.updateLastSyncTimestamp('expense_categories');
      }
    } catch (e) {
      debugPrint('OfflineProvider: Failed to sync expense categories - $e');
    }
  }

  /// Sync one-time discounts
  Future<void> _syncOneTimeDiscounts() async {
    // One-time discounts are fetched on-demand per customer/item
    // This is just updating the timestamp
    await _databaseService!.updateLastSyncTimestamp('one_time_discounts');
  }

  /// Sync quantity offers
  Future<void> _syncQuantityOffers() async {
    try {
      // Get stock locations first to sync offers for all locations
      final locationsResponse = await _apiService.getAllStockLocations();
      if (!locationsResponse.isSuccess || locationsResponse.data == null) {
        debugPrint('OfflineProvider: No stock locations available for syncing offers');
        return;
      }

      final allOffers = <Map<String, dynamic>>[];

      for (final location in locationsResponse.data!) {
        final response = await _apiService.getActiveOffers(locationId: location.locationId);
        if (response.isSuccess && response.data != null) {
          for (final o in response.data!.offers) {
            allOffers.add({
              'offer_id': o.offerId,
              'item_id': o.itemId,
              'stock_location_id': o.stockLocationId ?? location.locationId,
              'buy_quantity': o.purchaseQuantity,
              'reward_type': 'free', // Default type for quantity offers
              'reward_item_id': null,
              'reward_quantity': o.rewardQuantity,
              'reward_discount_percent': null,
              'valid_from': o.startDate,
              'valid_to': o.endDate,
              'is_active': 1,
            });
          }
        }
      }

      if (allOffers.isNotEmpty) {
        await _databaseService!.saveItemQuantityOffers(allOffers);
      }
      await _databaseService!.updateLastSyncTimestamp('item_quantity_offers');
    } catch (e) {
      debugPrint('OfflineProvider: Failed to sync quantity offers - $e');
    }
  }

  /// Trigger manual sync
  Future<bool> triggerSync() async {
    if (!_isInitialized || _syncService == null) {
      return false;
    }

    return await _syncService!.triggerSync();
  }

  /// Retry failed sync items
  Future<void> retryFailedSync() async {
    if (!_isInitialized || _syncService == null) {
      return;
    }

    await _syncService!.retryFailedItems();
  }

  /// Get database statistics
  Future<Map<String, dynamic>> getStats() async {
    if (!_isInitialized || _databaseService == null) {
      return {};
    }

    final dbStats = await _databaseService!.getDatabaseStats();
    final syncStats = await _syncService?.getSyncStats() ?? {};

    return {
      'is_online': _connectivityProvider.isOnline,
      'connection_type': _connectivityProvider.connectionTypeString,
      'pending_sync': _pendingSyncCount,
      'failed_sync': _failedSyncCount,
      'last_sync': _lastSyncTime?.toIso8601String(),
      'database': dbStats,
      'sync': syncStats,
    };
  }

  // =====================================================
  // OFFLINE DATA RETRIEVAL METHODS
  // =====================================================

  /// Get items from local database (for offline use)
  Future<List<Map<String, dynamic>>> getOfflineItems({
    int? locationId,
    String? search,
    int limit = 50,
  }) async {
    if (_databaseService == null) {
      debugPrint('OfflineProvider: Database not initialized');
      return [];
    }

    try {
      final items = await _databaseService!.getItemsWithQuantities(
        locationId: locationId,
        search: search,
        limit: limit,
      );
      debugPrint('📦 Loaded ${items.length} items from offline database');
      return items;
    } catch (e) {
      debugPrint('OfflineProvider: Error getting offline items - $e');
      return [];
    }
  }

  /// Get customers from local database (for offline use)
  Future<List<Map<String, dynamic>>> getOfflineCustomers({
    String? search,
    int limit = 50,
  }) async {
    if (_databaseService == null) {
      debugPrint('OfflineProvider: Database not initialized');
      return [];
    }

    try {
      final customers = await _databaseService!.getCustomers(
        search: search,
        limit: limit,
      );
      debugPrint('👥 Loaded ${customers.length} customers from offline database');
      return customers;
    } catch (e) {
      debugPrint('OfflineProvider: Error getting offline customers - $e');
      return [];
    }
  }

  /// Create a sale offline (saves to local database for later sync)
  Future<int?> createOfflineSale(Map<String, dynamic> sale, List<Map<String, dynamic>> items, List<Map<String, dynamic>> payments) async {
    if (_databaseService == null) {
      debugPrint('OfflineProvider: Database not initialized');
      return null;
    }

    try {
      final saleId = await _databaseService!.createLocalSale(sale, items, payments);
      debugPrint('💾 Sale saved offline with local ID: $saleId');
      await _updateSyncCounts();
      notifyListeners();
      return saleId;
    } catch (e) {
      debugPrint('OfflineProvider: Error creating offline sale - $e');
      return null;
    }
  }

  /// Check if offline database has data
  Future<bool> hasOfflineData() async {
    if (_databaseService == null) return false;

    try {
      final items = await _databaseService!.getItemsWithQuantities(limit: 1);
      return items.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Clear all offline data
  Future<void> clearOfflineData() async {
    if (_databaseService != null) {
      await _databaseService!.clearSyncedData();
      await _updateSyncCounts();
    }
  }

  /// Close and cleanup
  Future<void> close() async {
    debugPrint('OfflineProvider: Closing...');

    _syncService?.dispose();
    await _databaseService?.closeDatabase();

    _isInitialized = false;
    _currentClientId = null;
    _databaseService = null;
    _syncService = null;

    notifyListeners();
  }

  @override
  void dispose() {
    _connectivityProvider.removeListener(_onConnectivityChanged);
    close();
    super.dispose();
  }
}
