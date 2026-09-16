import 'dart:async';

import 'package:flutter/widgets.dart';
import '../models/pending_upload.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';
import '../services/api_service.dart';
import '../services/offline_actions.dart';
import '../services/offline_feature.dart';
import '../services/screen_prefetch.dart';
import 'location_provider.dart';
import 'connectivity_provider.dart';

/// Provider to manage offline functionality and data synchronization
class OfflineProvider extends ChangeNotifier with WidgetsBindingObserver {
  final ConnectivityProvider _connectivityProvider;
  final ApiService _apiService;

  DatabaseService? _databaseService;
  SyncService? _syncService;

  /// Supplied after construction, because the prefetch has to ask with the same
  /// location filter the screens use -- see ScreenPrefetch.
  LocationProvider? _locationProvider;

  // State
  bool _isInitialized = false;
  bool _isSyncing = false;
  int _pendingSyncCount = 0;
  int _failedSyncCount = 0;
  int _pendingSaleCount = 0;
  int _failedSaleCount = 0;
  int _pendingActionCount = 0;
  int _failedActionCount = 0;
  bool _serverReachable = true;
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

  /// Sales specifically, as opposed to every queued entity.
  ///
  /// The seller-facing UI counts these, not the whole queue: telling someone
  /// "3 sales waiting" when two of them are expenses sends them looking for
  /// receipts that were never missing.
  int get pendingSaleCount => _pendingSaleCount;
  int get failedSaleCount => _failedSaleCount;

  /// Everything else a person created while there was no network: expenses,
  /// receivings, banking, submissions, requests, customers, suppliers.
  ///
  /// Counted apart from sales for the same reason sales are counted apart from
  /// the whole queue -- a clerk who queued an expense should not be told two
  /// sales are waiting, and a seller should not go hunting for a receipt that
  /// was really a supplier record.
  int get pendingActionCount => _pendingActionCount;
  int get failedActionCount => _failedActionCount;

  /// Refusals nobody has confirmed reading.
  ///
  /// The single most important number in this provider. A rejected record is
  /// one the server will never accept on a retry, so unless a person actually
  /// sees it, the work behind it is gone -- and the app cannot know they saw
  /// it unless they say so. Persisted per record in SQLite, so this survives
  /// the app being killed; nothing but a human tap clears it.
  int get unreadRejectionCount => _unreadRejectionCount;
  int _unreadRejectionCount = 0;

  /// Every refusal on the device, read or not.
  int get rejectedCount => _failedSaleCount + _failedActionCount;

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

  /// Whether the last upload attempt got an answer from the server.
  ///
  /// Separate from [isOnline] on purpose. connectivity_plus reports the radio;
  /// this reports the server. A phone joined to a shop's wifi whose uplink is
  /// dead is "online" and unreachable at the same time, and that is precisely
  /// the case a seller must be told about -- the alternative is a green icon
  /// over a queue that is not moving.
  bool get serverReachable => _serverReachable;

  /// Whether sales can actually be sent right now.
  bool get canReachServer => _connectivityProvider.isOnline && _serverReachable;

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
    // Reopening the app is a sync trigger in its own right: iOS suspends
    // timers in the background, so the periodic sweep cannot be trusted to
    // have run while the seller was in another app.
    WidgetsBinding.instance.addObserver(this);
  }

  /// The prefetch needs to know which stores this user may see, and which one
  /// they have chosen. Wired from main.dart the same way AuthProvider is.
  ///
  /// Listened to, not just held. initialize() runs at app start -- BEFORE
  /// anyone has signed in -- so the store list is still empty then and the warm
  /// it kicked off did nothing but return "no store assigned". Signing in is
  /// what fills this provider, so that is the moment to warm, and this is how
  /// we hear about it.
  void setLocationProvider(LocationProvider provider) {
    if (identical(_locationProvider, provider)) return;
    _locationProvider?.removeListener(_onLocationsChanged);
    _locationProvider = provider;
    provider.addListener(_onLocationsChanged);
    _onLocationsChanged();
  }

  /// Whether this session has already warmed since the stores appeared.
  ///
  /// Guards the forced warm below so it happens once per sign-in, not on every
  /// notification LocationProvider emits.
  bool _warmedThisSession = false;

  /// Stores resolved (or changed). Warm, if there is now something to warm with.
  ///
  /// FORCED, deliberately. Signing in is the clearest signal anyone gives that
  /// they are about to work, and it is usually done in town with signal. The
  /// three-hour pace exists to stop background runs burning a bundle; applying
  /// it here meant somebody who had downloaded earlier in the day signed in,
  /// saw nothing happen, and reasonably concluded it was broken.
  void _onLocationsChanged() {
    final locations = _locationProvider;
    if (locations == null) return;
    if (locations.allowedLocations.isEmpty) {
      // Signing out empties this, so the next sign-in warms again.
      _warmedThisSession = false;
      return;
    }
    if (!_isInitialized || !_connectivityProvider.isOnline) return;
    if (_warmedThisSession) return;
    _warmedThisSession = true;
    unawaited(prefetchScreens(force: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!_isInitialized) return;
    _syncService?.onAppResumed();
    // Coming back is the best moment to warm the cache: the seller is usually
    // still in range when they reopen the app, and about to leave.
    unawaited(prefetchScreens());
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
    _syncService!.onReachabilityChanged = (reachable) {
      _serverReachable = reachable;
      notifyListeners();
    };

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
      // Opening the app is the other reliable moment there is signal.
      unawaited(prefetchScreens());
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
      // Uploads first, then top the cache up -- the queue is somebody's
      // work and matters more than a fresh list.
      unawaited(prefetchScreens());
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
    // The sale-specific figures come from a different table, so refresh them
    // together rather than letting the badge and the strip disagree.
    _updateSyncCounts();
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

      final saleCounts = await _databaseService!.getUnsyncedSaleCounts();
      _pendingSaleCount = saleCounts['pending'] ?? 0;
      _failedSaleCount = saleCounts['failed'] ?? 0;

      final actionCounts = await _databaseService!.getUnsyncedActionCounts();
      _pendingActionCount = actionCounts['pending'] ?? 0;
      _failedActionCount = actionCounts['failed'] ?? 0;

      _unreadRejectionCount = await _databaseService!.countUnreadRejections();

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
      // Deliberately does NOT touch _lastSyncTime: that is shown to the seller
      // as "Last upload", and this method downloads items and customers. A
      // master-data refresh stamping it made the sheet report a recent upload
      // while sales sat in the queue unsent.

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

  /// Warm the read cache for the screens people open away from signal.
  ///
  /// syncMasterData above pulls the reference tables -- items, customers,
  /// suppliers -- into SQLite once a day. That is the catalogue. This is the
  /// other half: the working lists each screen shows, which live in the read
  /// cache rather than in SQLite, and which until now were saved only if
  /// somebody happened to open that screen while there was signal. That is what
  /// made "connect once to set up this device" necessary.
  ///
  /// Deliberately quiet. Nobody asked for it, so it never raises an error and
  /// never blocks anything: a failed warm just leaves the screen behaving as it
  /// did before.
  Future<PrefetchReport> prefetchScreens({bool force = false}) async {
    if (!_isInitialized) return PrefetchReport.skipped('not initialized');
    if (!_connectivityProvider.isOnline) {
      return PrefetchReport.skipped('offline');
    }

    final locations = _locationProvider;
    if (locations == null) {
      return PrefetchReport.skipped('no location context');
    }

    _prefetchDone = 0;
    _prefetchTotal = 0;
    _prefetchLabel = null;

    final outcome = await ScreenPrefetch.run(
      api: _apiService,
      allowedLocationIds:
          locations.allowedLocations.map((l) => l.locationId).toList(),
      selectedLocationId: locations.selectedLocation?.locationId,
      force: force,
      onProgress: (done, total, label) {
        _prefetchDone = done;
        _prefetchTotal = total;
        _prefetchLabel = label;
        notifyListeners();
      },
    );

    _prefetchTotal = 0;
    _prefetchLabel = null;
    if (outcome.didRun) _lastPrefetch = outcome;
    notifyListeners();
    return outcome;
  }

  int _prefetchDone = 0;
  int _prefetchTotal = 0;
  String? _prefetchLabel;

  /// Whether a warm is running right now, so the card can show a bar instead
  /// of a button.
  bool get isPrefetching => _prefetchTotal > 0;

  /// 0..1, for the progress bar. Zero when nothing is running.
  double get prefetchProgress =>
      _prefetchTotal == 0 ? 0 : _prefetchDone / _prefetchTotal;

  /// What is being fetched at this moment, by a name people recognise.
  String? get prefetchLabel => _prefetchLabel;

  int get prefetchDone => _prefetchDone;
  int get prefetchTotal => _prefetchTotal;

  /// The last warm that actually ran this session, for the Settings sheet.
  PrefetchReport? _lastPrefetch;
  PrefetchReport? get lastPrefetch => _lastPrefetch;

  /// When the cache was last warmed on this device, surviving restarts.
  Future<DateTime?> lastPrefetchAt() => ScreenPrefetch.lastRun();

  /// What that warm actually fetched, so Settings can name it.
  Future<PrefetchReport?> lastPrefetchReport() => ScreenPrefetch.lastReport();

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

      // Only claim the cache is fresh if something actually landed in it.
      //
      // Stamping unconditionally is how the offline cache ended up empty in
      // practice: this runs at startup, which on a cold launch is BEFORE the
      // user has signed in, so every request 401s and saves nothing -- and the
      // stamp then told _shouldSyncMasterData to skip for the next 24 hours.
      // The seller went offline with no items to sell and no way to know why.
      if (offset > 0) {
        await _databaseService!.updateLastSyncTimestamp('items');
      } else {
        debugPrint('OfflineProvider: No items fetched, leaving cache stale so it retries');
      }
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

      // See _syncItems: a stamp with nothing behind it suppresses the retry.
      if (offset > 0) {
        await _databaseService!.updateLastSyncTimestamp('customers');
      }
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

  /// Upload everything queued, now, because a person asked.
  ///
  /// Returns what the run actually did so the caller can say it out loud.
  /// Pressing this twice is harmless -- every queued record carries the
  /// request_id it was first written under, so a second push replays the
  /// server's stored answer rather than writing a second record -- but a
  /// second run is still pointless while the first is going, and the report
  /// says so through [SyncRunReport.alreadyRunning] rather than pretending
  /// something happened.
  Future<SyncRunReport> triggerSync() async {
    if (!_isInitialized || _syncService == null) {
      // No local database means nothing was ever queued here.
      return const SyncRunReport();
    }

    final report = await _syncService!.triggerSync();
    await _updateSyncCounts();
    return report;
  }

  /// Retry every refused record at once.
  Future<SyncRunReport> retryFailedSync() async {
    if (!_isInitialized || _syncService == null) {
      return const SyncRunReport();
    }

    final report = await _syncService!.retryFailedItems();
    await _updateSyncCounts();
    return report;
  }

  // =====================================================
  // WHAT HAS NOT GONE UP, AND WHAT TO DO ABOUT IT
  // =====================================================

  /// Everything still owed to the server -- sales and every other create --
  /// as one list, newest first, each carrying which of the three states it is
  /// in and the server's own words when it is stuck.
  Future<List<PendingUpload>> loadPendingUploads() async {
    if (_databaseService == null) return const [];

    final sales = await _databaseService!.getUnsyncedSales();
    final actions = await _databaseService!.getUnsyncedActions();
    return PendingUpload.merge(sales: sales, actions: actions);
  }

  /// Record that a person has seen one refusal.
  Future<void> acknowledgeRejection(PendingUpload item) async {
    if (_databaseService == null) return;

    await _databaseService!.acknowledgeRejection(
      entityType: item.entityType,
      id: item.localId,
    );
    await _updateSyncCounts();
  }

  /// Record that a person has seen all of them.
  Future<void> acknowledgeAllRejections() async {
    if (_databaseService == null) return;

    await _databaseService!.acknowledgeAllRejections();
    await _updateSyncCounts();
  }

  /// Try one refused record again, by hand.
  ///
  /// Returns how that ONE record stands afterwards: null when it is no longer
  /// owed at all (it went up), otherwise the record with its new state and,
  /// if it was refused again, the server's newest words. Reporting the whole
  /// run here would answer a question nobody asked -- the person tapped one
  /// row.
  Future<PendingUpload?> retryRejected(PendingUpload item) async {
    if (!_isInitialized || _syncService == null) return item;

    await _syncService!.retryOne(
      entityType: item.entityType,
      entityId: item.localId,
    );
    await _updateSyncCounts();

    final after = await loadPendingUploads();
    for (final candidate in after) {
      if (candidate.entityType == item.entityType &&
          candidate.localId == item.localId) {
        return candidate;
      }
    }
    return null;
  }

  /// Stop trying to upload one refused record, deliberately.
  ///
  /// The row is not deleted -- see [DatabaseService.discardRejected]. It stops
  /// being queued, stops being counted, and keeps its payload so the same
  /// question can still be answered next week.
  Future<bool> discardRejected(PendingUpload item) async {
    if (_databaseService == null) return false;

    final discarded = await _databaseService!.discardRejected(
      entityType: item.entityType,
      id: item.localId,
    );
    if (discarded) await _updateSyncCounts();
    return discarded;
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
      // Expected for clients with hasOfflineMode: false -- there is no local
      // database by design, so this is not an error.
      debugPrint('OfflineProvider: offline mode not enabled, skipping local items read');
      return [];
    }

    try {
      final items = await _databaseService!.getItemsWithQuantities(
        locationId: locationId,
        search: search,
        limit: limit,
      );
      debugPrint('📦 Loaded ${items.length} items from offline database');
      return items.map(_itemRowToApiShape).toList();
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
      // Expected for clients with hasOfflineMode: false -- see getOfflineItems.
      debugPrint('OfflineProvider: offline mode not enabled, skipping local customers read');
      return [];
    }

    try {
      final customers = await _databaseService!.getCustomers(
        search: search,
        limit: limit,
      );
      debugPrint('👥 Loaded ${customers.length} customers from offline database');
      return customers.map(_customerRowToApiShape).toList();
    } catch (e) {
      debugPrint('OfflineProvider: Error getting offline customers - $e');
      return [];
    }
  }


  // =====================================================
  // LOCAL ROW -> API SHAPE
  //
  // The SQLite tables are not a mirror of the API's JSON; they were designed
  // separately and they disagree in ways the model classes cannot absorb.
  // Callers parse these rows with Item.fromJson / Customer.fromJson, so the
  // translation has to happen here, once, rather than by loosening every
  // model to accept both shapes.
  //
  // These are not cosmetic differences. Before this adapter, opening the till
  // with no connection threw
  //   type 'int' is not a subtype of type 'String'
  // out of Item.fromJson and left the seller on an empty item list -- the
  // offline read had evidently never been run.
  // =====================================================

  /// One cached item row, in the shape Item.fromJson expects.
  Map<String, dynamic> _itemRowToApiShape(Map<String, dynamic> row) {
    final item = Map<String, dynamic>.from(row);

    // Stored as 0/1; the model holds a String and the app compares it to
    // 'DORMANT'. Handing over the raw int is what threw.
    item['dormant'] = _isTrue(row['dormant']) ? 'DORMANT' : 'ACTIVE';

    // The local columns are tax1_*; the API sends tax_1_*. Left untranslated
    // the tax name and rate silently arrive null on every offline line.
    item['tax_1_name'] = row['tax1_name'];
    item['tax_1_percent'] = row['tax1_percent'];
    item['tax_2_name'] = row['tax2_name'];
    item['tax_2_percent'] = row['tax2_percent'];

    item['deleted'] = row['is_deleted'] ?? 0;

    // getItemsWithQuantities joins the quantity for the requested location.
    // Presenting it as quantity_by_location too keeps the stock lookups in the
    // sales screen working the same way they do online.
    final locationId = row['location_id'];
    if (locationId != null && row['quantity'] != null) {
      item['quantity_by_location'] = {locationId.toString(): row['quantity']};
    }

    return item;
  }

  /// One cached customer row, in the shape Customer.fromJson expects.
  Map<String, dynamic> _customerRowToApiShape(Map<String, dynamic> row) {
    final customer = Map<String, dynamic>.from(row);

    customer['dormant'] = _isTrue(row['dormant']) ? 'DORMANT' : 'ACTIVE';

    // Stored as discount_percent, read as discount. Without this every
    // offline customer looks like a customer with no agreed discount.
    customer['discount'] = row['discount_percent'];

    return customer;
  }

  /// SQLite has no boolean; these columns arrive as 0/1, and older rows or a
  /// hand-edited database can hold the string forms too.
  static bool _isTrue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final v = value.toLowerCase();
      return v == '1' || v == 'true' || v == 'dormant';
    }
    return false;
  }

  /// Create a sale offline (saves to local database for later sync)
  Future<int?> createOfflineSale(Map<String, dynamic> sale, List<Map<String, dynamic>> items, List<Map<String, dynamic>> payments) async {
    if (_databaseService == null) {
      // Unlike the read paths, reaching here means a sale had nowhere to go.
      // Callers must check isInitialized before routing a sale offline.
      debugPrint('OfflineProvider: cannot save sale offline - offline mode is not enabled');
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

  /// Re-read the queue counts from SQLite and notify.
  ///
  /// Needed by callers that write to the database through [database] directly
  /// rather than through this provider -- the sales screen's offline fallback
  /// does, and without this the badge and the "N sales are waiting" line in
  /// its own confirmation still read zero right after a sale was queued.
  Future<void> refreshCounts() => _updateSyncCounts();

  /// Sales that have not reached the server, with the reason each is stuck.
  Future<List<Map<String, dynamic>>> getUnsyncedSales() async {
    if (_databaseService == null) return [];
    return _databaseService!.getUnsyncedSales();
  }

  /// Everything else still owed to the server, with the reason each is stuck.
  Future<List<Map<String, dynamic>>> getUnsyncedActions() async {
    if (_databaseService == null) return [];
    return _databaseService!.getUnsyncedActions();
  }

  /// Hold one CREATE on the device until the network comes back.
  ///
  /// Returns true when it is safely stored. A false means it was NOT recorded,
  /// and the caller owes the user that news plainly -- silence here is how a
  /// person walks away believing an expense was captured when it was not.
  ///
  /// [requestId] MUST be the key the failed online attempt used. That attempt
  /// may have reached the server and been answered into a dead socket, and
  /// carrying its key in here is what turns the eventual upload into a replay
  /// rather than a second record.
  Future<bool> queueAction({
    required OfflineAction action,
    required Map<String, dynamic> payload,
    required String requestId,
    String? summary,
  }) async {
    if (_databaseService == null) {
      // Unlike the read paths, reaching here means something a person did had
      // nowhere to go. Callers must check isInitialized before routing a
      // create into the queue.
      debugPrint(
          'OfflineProvider: cannot queue ${action.type} - offline mode is not enabled');
      return false;
    }

    // The server can switch queueing off without a release. Checked here, at
    // the one door every create goes through, rather than at each call site --
    // a screen that forgot the check would otherwise queue into a mode that is
    // supposed to be off. Draining what is already queued is untouched.
    if (!OfflineFeature.enabled) {
      debugPrint(
          'OfflineProvider: refusing to queue ${action.type} - offline mode is switched off');
      return false;
    }

    try {
      final id = await _databaseService!.queueAction(
        actionType: action.type,
        endpoint: action.endpoint,
        label: action.label,
        requestId: requestId,
        payload: payload,
        summary: summary,
      );
      debugPrint('💾 ${action.label} saved offline with local ID: $id');
      await _updateSyncCounts();
      return true;
    } catch (e) {
      debugPrint('OfflineProvider: Error queueing ${action.type} - $e');
      return false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivityProvider.removeListener(_onConnectivityChanged);
    _locationProvider?.removeListener(_onLocationsChanged);
    close();
    super.dispose();
  }
}
