import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_service.dart';
import 'api_service.dart';
import '../models/api_response.dart';
import '../models/sale.dart';
import '../models/expense.dart';
import '../models/receiving.dart';
import '../models/banking.dart';
import '../models/transaction.dart';

/// Sync status enum
enum SyncStatus {
  idle,
  syncing,
  completed,
  failed,
}

/// What a failed upload means for the item that failed.
enum _Outcome {
  /// The server never answered. Says nothing about the item.
  unreachable,

  /// The server is holding an earlier attempt of this same request.
  inFlight,

  /// The server answered, but with something that may pass.
  retryable,

  /// The server looked at the item and refused it. Retrying changes nothing.
  rejected,
}

/// Sync result for a single item
class SyncResult {
  final String entityType;
  final int entityId;
  final bool success;
  final int? serverId;
  final String? error;

  SyncResult({
    required this.entityType,
    required this.entityId,
    required this.success,
    this.serverId,
    this.error,
  });
}

/// Service to handle data synchronization between local database and server
class SyncService {
  static SyncService? _instance;

  final DatabaseService _dbService;
  final ApiService _apiService;

  // Sync state
  SyncStatus _status = SyncStatus.idle;
  bool _isSyncing = false;
  Timer? _autoSyncTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Callbacks
  Function(SyncStatus status)? onSyncStatusChanged;
  Function(int pending, int failed)? onSyncCountChanged;
  Function(SyncResult result)? onItemSynced;
  Function(bool reachable)? onReachabilityChanged;

  // Configuration
  static const int _maxRetries = 5;

  /// Sweep interval while everything is healthy. The connectivity listener and
  /// the app-resume hook are what normally start a sync; this is the backstop
  /// for the cases neither fires -- the interface never dropped but the uplink
  /// came back, which is the common shape of a bad connection in the field.
  static const Duration _autoSyncInterval = Duration(minutes: 5);

  /// Sweep interval while the server is known to be unreachable but there is
  /// still something queued. Faster than the healthy interval so a seller who
  /// walks back into coverage sees the queue drain in under a minute rather
  /// than standing there wondering whether to press something.
  static const Duration _retrySyncInterval = Duration(seconds: 30);

  SyncService._({
    required DatabaseService dbService,
    required ApiService apiService,
  }) : _dbService = dbService,
       _apiService = apiService;

  /// Get singleton instance
  static SyncService getInstance({
    required DatabaseService dbService,
    required ApiService apiService,
  }) {
    _instance ??= SyncService._(dbService: dbService, apiService: apiService);
    return _instance!;
  }

  /// Get current sync status
  SyncStatus get status => _status;

  /// Check if currently syncing
  bool get isSyncing => _isSyncing;

  /// Initialize sync service
  Future<void> initialize() async {
    debugPrint('SyncService: Initializing...');

    try {
      // Listen to connectivity changes
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
        _handleConnectivityChange(result);
      });
    } catch (e) {
      debugPrint('SyncService: Connectivity listener not available - $e');
    }

    // Start auto-sync timer
    _startAutoSyncTimer();

    // Update sync counts
    await _updateSyncCounts();

    debugPrint('SyncService: Initialized');

    // A queue that survived the last run is drained now, without waiting for
    // the first timer tick or for connectivity to change. This is what makes
    // sync survive the app being killed: the sales are in SQLite, and opening
    // the app is itself a trigger.
    unawaited(syncAll());
  }

  /// The app came back to the foreground.
  ///
  /// Backgrounded apps get their timers throttled and eventually suspended by
  /// iOS, so the periodic sweep cannot be relied on to have run while the
  /// seller was in WhatsApp. Resuming is a trigger in its own right.
  Future<void> onAppResumed() async {
    debugPrint('SyncService: App resumed, syncing');
    _startAutoSyncTimer(); // reschedule; the old one may have been suspended
    await syncAll();
  }

  /// Dispose sync service
  void dispose() {
    _autoSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
    _instance = null;
    debugPrint('SyncService: Disposed');
  }

  /// Handle connectivity changes
  Future<void> _handleConnectivityChange(ConnectivityResult result) async {
    final hasConnection = result != ConnectivityResult.none;

    debugPrint('SyncService: Connectivity changed - hasConnection: $hasConnection');

    if (hasConnection && !_isSyncing) {
      // Trigger sync when connection is restored
      await syncAll();
    }
  }

  /// Start auto-sync timer.
  ///
  /// Rescheduled after every run rather than left as one fixed Timer.periodic,
  /// so the interval can tighten while a queue is stuck waiting on a server
  /// that is not answering and relax again once it drains.
  void _startAutoSyncTimer() {
    _autoSyncTimer?.cancel();

    final counts = _lastCounts;
    final queueWaiting = (counts['pending'] ?? 0) > 0;
    final interval = (!_serverReachable && queueWaiting)
        ? _retrySyncInterval
        : _autoSyncInterval;

    _autoSyncTimer = Timer(interval, () async {
      if (!_isSyncing) {
        await syncAll();
      }
      _startAutoSyncTimer();
    });
  }

  /// Last known queue counts, so the timer can pick its interval without
  /// going back to SQLite on every reschedule.
  Map<String, int> _lastCounts = const {'pending': 0, 'failed': 0};

  /// Update sync counts and notify listeners
  Future<void> _updateSyncCounts() async {
    final counts = await _dbService.getSyncQueueCounts();
    _lastCounts = counts;
    onSyncCountChanged?.call(counts['pending'] ?? 0, counts['failed'] ?? 0);
  }

  /// Set sync status and notify
  void _setStatus(SyncStatus status) {
    _status = status;
    onSyncStatusChanged?.call(status);
  }

  /// Whether the device has a network interface up.
  ///
  /// This is a cheap negative check, not proof of anything. connectivity_plus
  /// reports the radio, not the route: a phone joined to a shop's wifi whose
  /// uplink is dead reports "connected" all day. So a false here reliably
  /// means do-not-bother, but a true only means worth-a-try -- the real test
  /// is whether the upload gets an answer, which is what _syncSales reports
  /// back and what `serverReachable` reflects.
  Future<bool> _hasNetworkInterface() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      debugPrint('SyncService: Error checking connectivity - $e');
      return true; // Assume online if check fails
    }
  }

  /// Whether the last upload attempt actually got an answer from the server.
  ///
  /// Starts optimistic, so a fresh install with nothing queued does not claim
  /// the server is down before it has ever tried to reach it.
  bool _serverReachable = true;
  bool get serverReachable => _serverReachable;

  /// Called whenever an upload attempt tells us something about the server.
  void _noteReachability(bool reachable) {
    if (_serverReachable == reachable) return;
    _serverReachable = reachable;
    onReachabilityChanged?.call(reachable);
  }

  /// Sync all pending items
  Future<void> syncAll() async {
    if (_isSyncing) {
      debugPrint('SyncService: Already syncing, skipping...');
      return;
    }

    if (!await _hasNetworkInterface()) {
      debugPrint('SyncService: No connectivity, skipping sync');
      return;
    }

    _isSyncing = true;
    _setStatus(SyncStatus.syncing);

    debugPrint('SyncService: Starting sync...');

    try {
      // Sales first, and they gate the rest: when the server did not answer
      // the sale upload it will not answer the other five either, and pushing
      // on means five more 30-second timeouts before the seller's screen stops
      // saying "Syncing...". Everything left simply stays queued.
      // With an empty queue _syncSales has nothing to learn from, so it cannot
      // tell us whether the server is up -- and a seller about to start a
      // shift deserves to know that BEFORE the first sale, not after it. One
      // cheap authenticated call settles it. auth/verify carries no request_id,
      // so probing can never disturb the idempotency log.
      final hasQueuedSales =
          (await _dbService.getPendingSyncItems(entityType: 'sale', limit: 1))
              .isNotEmpty;

      final bool reachable;
      if (hasQueuedSales) {
        reachable = await _syncSales();
      } else {
        final probe = await _apiService.verifyToken();
        // A refusal (401, 403, anything with a code) still proves the server
        // answered. Only the absence of a code means nobody was home.
        reachable = probe.isSuccess || probe.statusCode != null;
      }
      _noteReachability(reachable);

      if (!reachable) {
        debugPrint('SyncService: Server unreachable, leaving the rest queued');
        _setStatus(SyncStatus.failed);
        return;
      }

      await _syncExpenses();
      await _syncReceivings();
      await _syncBanking();
      await _syncCustomerDeposits();
      await _syncOneTimeDiscountUsage();

      _setStatus(SyncStatus.completed);
      debugPrint('SyncService: Sync completed');
    } catch (e) {
      debugPrint('SyncService: Sync failed - $e');
      _setStatus(SyncStatus.failed);
    } finally {
      _isSyncing = false;
      await _updateSyncCounts();
    }
  }

  /// Read a failed upload and decide what it says about the item.
  ///
  /// The discriminator is whether there is a status code at all: ApiService
  /// only produces one when the server actually answered, so a null code is
  /// exactly "we never got a reply" -- no connection, DNS gone, timeout.
  static _Outcome _classify(ApiResponse response) {
    final code = response.statusCode;
    if (code == null) return _Outcome.unreachable;

    // 409 here is claim_request_id refusing to run our own request twice.
    if (code == 409) return _Outcome.inFlight;

    // 401 is the token, not the sale. A refresh or re-login fixes it and the
    // sale is still perfectly good, so it must not be marked as rejected.
    if (code == 401 || code == 408 || code == 429 || code >= 500) {
      return _Outcome.retryable;
    }

    return _Outcome.rejected;
  }

  /// Sync pending sales.
  ///
  /// Returns false when the run stopped because the server could not be
  /// reached, so the caller can abandon the rest of the sync instead of
  /// waiting out a 30-second timeout per remaining item.
  ///
  /// Sales upload one at a time, oldest first, and a transport failure stops
  /// the run where it stands. Skipping past a stuck sale to upload a later one
  /// would land them on the server out of order, and the Z report reads the
  /// server's order.
  Future<bool> _syncSales() async {
    final pendingItems = await _dbService.getPendingSyncItems(entityType: 'sale');
    debugPrint('SyncService: Found ${pendingItems.length} pending sales to sync');

    for (final item in pendingItems) {
      final entityId = item['entity_id'] as int;
      final queueId = item['id'] as int;
      final retryCount = item['retry_count'] as int? ?? 0;

      if (retryCount >= _maxRetries) {
        await _dbService.updateSyncQueueStatus(
          queueId,
          DatabaseService.syncStatusFailed,
          error: 'Max retries exceeded',
        );
        await _dbService.updateSaleSyncStatus(
          entityId,
          DatabaseService.syncStatusFailed,
          error: 'Max retries exceeded',
        );
        continue;
      }

      // Get sale details from local DB
      final sale = await _dbService.getSaleWithDetails(entityId);
      if (sale == null) {
        await _dbService.removeSyncQueueItem(queueId);
        continue;
      }

      // The key this sale was FIRST recorded under. Reused verbatim on every
      // attempt: that is the whole exactly-once guarantee. If a previous
      // attempt reached the server and we never heard the answer, the server
      // replays that answer now instead of writing the sale a second time.
      final requestId = sale['request_id'] as String?;
      if (requestId == null || requestId.isEmpty) {
        // Nothing safe to do: uploading without a key risks a duplicate, and
        // a duplicate sale is worse than one that waits for a human.
        await _dbService.updateSyncQueueStatus(
          queueId,
          DatabaseService.syncStatusFailed,
          error: 'Sale has no idempotency key and cannot be uploaded safely',
        );
        await _dbService.updateSaleSyncStatus(
          entityId,
          DatabaseService.syncStatusFailed,
          error: 'Sale has no idempotency key and cannot be uploaded safely',
        );
        continue;
      }

      ApiResponse<Sale> response;
      try {
        response = await _apiService.createSale(
          _convertLocalSaleToModel(sale),
          requestId: requestId,
        );
      } catch (e) {
        // createSale already converts transport errors into an error response;
        // reaching here means something unexpected threw. Treat it as
        // unreachable rather than as the sale's fault.
        debugPrint('SyncService: Sale $entityId threw during upload - $e');
        await _dbService.recordSyncQueueAttempt(queueId, e.toString());
        return false;
      }

      if (response.isSuccess) {
        // A replay lands here too, carrying the original sale's id -- which is
        // exactly what we want to record.
        final serverSaleId = response.data?.saleId;

        await _dbService.updateSaleSyncStatus(
          entityId,
          DatabaseService.syncStatusSynced,
          serverSaleId: serverSaleId,
        );
        await _dbService.removeSyncQueueItem(queueId);
        await _dbService.addSyncLog('sale', entityId, serverSaleId, 'create', 'success');

        onItemSynced?.call(SyncResult(
          entityType: 'sale',
          entityId: entityId,
          success: true,
          serverId: serverSaleId,
        ));

        debugPrint('SyncService: Sale $entityId synced (server ID: $serverSaleId)');
        continue;
      }

      final outcome = _classify(response);
      final message = response.message;

      switch (outcome) {
        case _Outcome.unreachable:
          // The server never answered. The sale stays exactly as it is, keeps
          // its key, and is tried again on the next trigger -- forever if need
          // be. Nothing about this run is the sale's fault, so nothing is
          // counted against it and it is not shown to the seller as failed.
          debugPrint('SyncService: Server unreachable, pausing sale sync');
          await _dbService.recordSyncQueueAttempt(queueId, message);
          return false;

        case _Outcome.inFlight:
          // 409 from claim_request_id: our own earlier attempt is still being
          // processed on the server. Waiting is the correct move -- a second
          // push cannot help and the stale-claim takeover will let us back in
          // if that original really did die.
          debugPrint('SyncService: Sale $entityId is still in flight server-side, will retry');
          await _dbService.recordSyncQueueAttempt(queueId, message);
          continue;

        case _Outcome.retryable:
          // 5xx or an expired token: the server is there but cannot take the
          // sale right now. Countable, because this one CAN run out of road.
          debugPrint('SyncService: Sale $entityId failed transiently - $message');
          await _dbService.updateSyncQueueStatus(
            queueId,
            DatabaseService.syncStatusPending,
            error: message,
          );
          await _dbService.addSyncLog('sale', entityId, null, 'create', 'retry', message: message);
          break;

        case _Outcome.rejected:
          // The server looked at this sale and said no -- out of stock, a
          // location the seller no longer has, a customer that is gone.
          // Retrying replays the same rejection, so stop and put it in front
          // of a human instead of grinding quietly.
          debugPrint('SyncService: Sale $entityId rejected by server - $message');
          await _dbService.updateSyncQueueStatus(
            queueId,
            DatabaseService.syncStatusFailed,
            error: message,
          );
          await _dbService.updateSaleSyncStatus(
            entityId,
            DatabaseService.syncStatusFailed,
            error: message,
          );
          await _dbService.addSyncLog('sale', entityId, null, 'create', 'failed', message: message);
          break;
      }

      onItemSynced?.call(SyncResult(
        entityType: 'sale',
        entityId: entityId,
        success: false,
        error: message,
      ));
    }

    return true;
  }

  /// Convert local sale data to Sale model for API
  Sale _convertLocalSaleToModel(Map<String, dynamic> localSale) {
    final items = (localSale['items'] as List<Map<String, dynamic>>).map((item) {
      return SaleItem(
        itemId: item['item_id'] as int,
        itemName: item['item_name'] as String? ?? '',
        quantity: (item['quantity_purchased'] as num).toDouble(),
        costPrice: (item['item_cost_price'] as num?)?.toDouble() ?? 0,
        unitPrice: (item['item_unit_price'] as num).toDouble(),
        discount: (item['discount'] as num?)?.toDouble() ?? 0,
        discountType: item['discount_type'] as int? ?? 0,
        discountLimit: (item['discount_limit'] as num?)?.toInt() ?? 100,
        // The online checkout sends this when a one-time discount was applied,
        // so a queued sale must too -- otherwise the same basket uploads with
        // the discounted price but no record of which allowance paid for it,
        // and the discount looks unused.
        oneTimeDiscountId: item['one_time_discount_id'] as int?,
        serialNumber: item['serialnumber'] as String?,
        stockLocationId: item['item_location'] as int?,
        quantityOfferId: item['quantity_offer_id'] as int?,
        quantityOfferFree: (item['quantity_offer_free'] as num?)?.toDouble() != 0,
        parentLine: item['parent_line'] as int?,
      );
    }).toList();

    final payments = (localSale['payments'] as List<Map<String, dynamic>>).map((payment) {
      return SalePayment(
        paymentType: payment['payment_type'] as String,
        amount: (payment['payment_amount'] as num).toDouble(),
      );
    }).toList();

    return Sale(
      customerId: localSale['customer_id'] as int?,
      employeeId: localSale['employee_id'] as int,
      saleTime: localSale['sale_time'] as String? ?? DateTime.now().toIso8601String(),
      saleType: localSale['sale_type'] as int? ?? 0,
      saleStatus: localSale['sale_status'] as int? ?? 0,
      stockLocationId: localSale['stock_location_id'] as int?,
      comment: localSale['comment'] as String?,
      items: items,
      payments: payments,
      subtotal: (localSale['subtotal'] as num?)?.toDouble() ?? 0,
      taxTotal: (localSale['tax_total'] as num?)?.toDouble() ?? 0,
      total: (localSale['total'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Sync pending expenses
  Future<void> _syncExpenses() async {
    final pendingItems = await _dbService.getPendingSyncItems(entityType: 'expense');
    debugPrint('SyncService: Found ${pendingItems.length} pending expenses to sync');

    for (final item in pendingItems) {
      final entityId = item['entity_id'] as int;
      final retryCount = item['retry_count'] as int? ?? 0;

      if (retryCount >= _maxRetries) {
        await _dbService.updateSyncQueueStatus(
          item['id'] as int,
          DatabaseService.syncStatusFailed,
          error: 'Max retries exceeded',
        );
        continue;
      }

      try {
        // Get expense from local DB
        final expenses = await _dbService.query('expenses', where: 'id = ?', whereArgs: [entityId]);
        if (expenses.isEmpty) {
          await _dbService.removeSyncQueueItem(item['id'] as int);
          continue;
        }

        final expense = expenses.first;

        // Create expense form data
        final formData = ExpenseFormData(
          date: expense['date'] as String,
          amount: (expense['amount'] as num).toDouble(),
          taxAmount: (expense['tax_amount'] as num?)?.toDouble() ?? 0,
          paymentType: expense['payment_type'] as String? ?? 'Cash',
          description: expense['description'] as String? ?? '',
          categoryId: expense['expense_category_id'] as int?,
          supplierTaxCode: expense['supplier_tax_code'] as String?,
          stockLocationId: expense['stock_location_id'] as int?,
        );

        // Send to server
        final response = await _apiService.createExpense(formData);

        if (response.isSuccess && response.data != null) {
          final serverExpenseId = response.data!.expenseId;

          // Update local expense
          await _dbService.update(
            'expenses',
            {
              'server_expense_id': serverExpenseId,
              'sync_status': DatabaseService.syncStatusSynced,
              'sync_timestamp': DateTime.now().toIso8601String(),
            },
            'id = ?',
            [entityId],
          );

          // Remove from sync queue
          await _dbService.removeSyncQueueItem(item['id'] as int);

          // Log success
          await _dbService.addSyncLog('expense', entityId, serverExpenseId, 'create', 'success');

          debugPrint('SyncService: Expense $entityId synced successfully');
        } else {
          throw Exception(response.message ?? 'Unknown error');
        }
      } catch (e) {
        debugPrint('SyncService: Failed to sync expense $entityId - $e');

        await _dbService.updateSyncQueueStatus(
          item['id'] as int,
          DatabaseService.syncStatusPending,
          error: e.toString(),
        );
      }
    }
  }

  /// Sync pending receivings
  Future<void> _syncReceivings() async {
    final pendingItems = await _dbService.getPendingSyncItems(entityType: 'receiving');
    debugPrint('SyncService: Found ${pendingItems.length} pending receivings to sync');

    for (final item in pendingItems) {
      final entityId = item['entity_id'] as int;
      final retryCount = item['retry_count'] as int? ?? 0;

      if (retryCount >= _maxRetries) {
        await _dbService.updateSyncQueueStatus(
          item['id'] as int,
          DatabaseService.syncStatusFailed,
          error: 'Max retries exceeded',
        );
        continue;
      }

      try {
        // Get receiving and items from local DB
        final receivings = await _dbService.query('receivings', where: 'id = ?', whereArgs: [entityId]);
        if (receivings.isEmpty) {
          await _dbService.removeSyncQueueItem(item['id'] as int);
          continue;
        }

        final receiving = receivings.first;
        final localItems = await _dbService.query('receiving_items', where: 'receiving_id = ?', whereArgs: [entityId]);

        // Convert to Receiving model
        final receivingModel = _convertLocalReceivingToModel(receiving, localItems);

        // Send to server
        final response = await _apiService.createReceiving(receivingModel);

        if (response.isSuccess && response.data != null) {
          final serverReceivingId = response.data!['receiving_id'] as int?;

          // Update local receiving
          await _dbService.update(
            'receivings',
            {
              'server_receiving_id': serverReceivingId,
              'sync_status': DatabaseService.syncStatusSynced,
              'sync_timestamp': DateTime.now().toIso8601String(),
            },
            'id = ?',
            [entityId],
          );

          // Remove from sync queue
          await _dbService.removeSyncQueueItem(item['id'] as int);

          // Log success
          await _dbService.addSyncLog('receiving', entityId, serverReceivingId, 'create', 'success');

          debugPrint('SyncService: Receiving $entityId synced successfully');
        } else {
          throw Exception(response.message ?? 'Unknown error');
        }
      } catch (e) {
        debugPrint('SyncService: Failed to sync receiving $entityId - $e');

        await _dbService.updateSyncQueueStatus(
          item['id'] as int,
          DatabaseService.syncStatusPending,
          error: e.toString(),
        );
      }
    }
  }

  /// Convert local receiving to Receiving model
  Receiving _convertLocalReceivingToModel(Map<String, dynamic> localReceiving, List<Map<String, dynamic>> localItems) {
    final items = localItems.map((item) {
      return ReceivingItem(
        itemId: item['item_id'] as int,
        itemName: item['item_name'] as String? ?? '',
        line: item['line'] as int? ?? 0,
        quantity: (item['quantity_purchased'] as num).toDouble(),
        costPrice: (item['item_cost_price'] as num).toDouble(),
        unitPrice: (item['item_unit_price'] as num?)?.toDouble() ?? 0,
        itemLocation: item['item_location'] as int? ?? 1,
      );
    }).toList();

    return Receiving(
      supplierId: localReceiving['supplier_id'] as int,
      employeeId: localReceiving['employee_id'] as int?,
      paymentType: localReceiving['payment_type'] as String? ?? 'Cash',
      reference: localReceiving['reference'] as String?,
      comment: localReceiving['comment'] as String?,
      stockLocation: localReceiving['stock_location_id'] as int? ?? 1,
      items: items,
    );
  }

  /// Sync pending banking
  Future<void> _syncBanking() async {
    final pendingItems = await _dbService.getPendingSyncItems(entityType: 'banking');
    debugPrint('SyncService: Found ${pendingItems.length} pending banking to sync');

    for (final item in pendingItems) {
      final entityId = item['entity_id'] as int;
      final retryCount = item['retry_count'] as int? ?? 0;

      if (retryCount >= _maxRetries) {
        await _dbService.updateSyncQueueStatus(
          item['id'] as int,
          DatabaseService.syncStatusFailed,
          error: 'Max retries exceeded',
        );
        continue;
      }

      try {
        final banking = await _dbService.query('banking', where: 'id = ?', whereArgs: [entityId]);
        if (banking.isEmpty) {
          await _dbService.removeSyncQueueItem(item['id'] as int);
          continue;
        }

        final record = banking.first;

        // Create banking model
        final bankingModel = BankingCreate(
          date: record['date'] as String,
          amount: (record['amount'] as num).toDouble(),
          bankName: record['bank_name'] as String? ?? '',
          depositor: record['depositor'] as String? ?? '',
          supervisorId: record['supervisor_id'] as int? ?? 0,
          stockLocationId: record['stock_location_id'] as int?,
        );

        final response = await _apiService.createBanking(bankingModel);

        if (response.isSuccess && response.data != null) {
          final serverBankingId = response.data!['banking_id'] as int?;

          await _dbService.update(
            'banking',
            {
              'server_banking_id': serverBankingId,
              'sync_status': DatabaseService.syncStatusSynced,
              'sync_timestamp': DateTime.now().toIso8601String(),
            },
            'id = ?',
            [entityId],
          );

          await _dbService.removeSyncQueueItem(item['id'] as int);
          debugPrint('SyncService: Banking $entityId synced successfully');
        } else {
          throw Exception(response.message ?? 'Unknown error');
        }
      } catch (e) {
        debugPrint('SyncService: Failed to sync banking $entityId - $e');
        await _dbService.updateSyncQueueStatus(
          item['id'] as int,
          DatabaseService.syncStatusPending,
          error: e.toString(),
        );
      }
    }
  }

  /// Sync pending customer deposits
  Future<void> _syncCustomerDeposits() async {
    final pendingItems = await _dbService.getPendingSyncItems(entityType: 'customer_deposit');
    debugPrint('SyncService: Found ${pendingItems.length} pending customer deposits to sync');

    for (final item in pendingItems) {
      final entityId = item['entity_id'] as int;
      final retryCount = item['retry_count'] as int? ?? 0;

      if (retryCount >= _maxRetries) {
        await _dbService.updateSyncQueueStatus(
          item['id'] as int,
          DatabaseService.syncStatusFailed,
          error: 'Max retries exceeded',
        );
        continue;
      }

      try {
        final deposits = await _dbService.query('customer_deposits', where: 'id = ?', whereArgs: [entityId]);
        if (deposits.isEmpty) {
          await _dbService.removeSyncQueueItem(item['id'] as int);
          continue;
        }

        final deposit = deposits.first;
        final isDeposit = deposit['type'] == 'deposit';
        final customerId = deposit['customer_id'] as int;
        final amount = (deposit['amount'] as num).toDouble();

        // Create TransactionFormData
        final formData = TransactionFormData(
          customerId: customerId,
          amount: amount,
          description: deposit['comment'] as String?,
          date: deposit['date'] as String?,
        );

        // Call appropriate API based on type
        final response = isDeposit
            ? await _apiService.addDeposit(formData)
            : await _apiService.addWithdrawal(formData);

        if (response.isSuccess) {
          await _dbService.update(
            'customer_deposits',
            {
              'sync_status': DatabaseService.syncStatusSynced,
              'sync_timestamp': DateTime.now().toIso8601String(),
            },
            'id = ?',
            [entityId],
          );

          await _dbService.removeSyncQueueItem(item['id'] as int);
          debugPrint('SyncService: Customer deposit $entityId synced successfully');
        } else {
          throw Exception(response.message ?? 'Unknown error');
        }
      } catch (e) {
        debugPrint('SyncService: Failed to sync customer deposit $entityId - $e');
        await _dbService.updateSyncQueueStatus(
          item['id'] as int,
          DatabaseService.syncStatusPending,
          error: e.toString(),
        );
      }
    }
  }

  /// Sync one-time discount usage
  Future<void> _syncOneTimeDiscountUsage() async {
    // Get locally marked discounts that need to sync their usage
    final pendingDiscounts = await _dbService.query(
      'one_time_discounts',
      where: 'sync_status = ? AND used_at IS NOT NULL',
      whereArgs: [DatabaseService.syncStatusPending],
    );

    debugPrint('SyncService: Found ${pendingDiscounts.length} one-time discounts to sync usage');

    for (final discount in pendingDiscounts) {
      try {
        final discountId = discount['discount_id'] as int;
        final localSaleId = discount['used_sale_id'] as int?;

        if (localSaleId == null) continue;

        // Get server sale ID
        final sales = await _dbService.query(
          'sales',
          where: 'id = ?',
          whereArgs: [localSaleId],
        );

        if (sales.isEmpty || sales.first['server_sale_id'] == null) {
          // Wait for sale to sync first
          continue;
        }

        final serverSaleId = sales.first['server_sale_id'] as int;

        final response = await _apiService.useOneTimeDiscount(
          discountId: discountId,
          saleId: serverSaleId,
        );

        if (response.isSuccess) {
          await _dbService.update(
            'one_time_discounts',
            {'sync_status': DatabaseService.syncStatusSynced},
            'discount_id = ?',
            [discountId],
          );

          debugPrint('SyncService: One-time discount $discountId usage synced');
        }
      } catch (e) {
        debugPrint('SyncService: Failed to sync one-time discount usage - $e');
      }
    }
  }

  /// Manual sync trigger
  Future<bool> triggerSync() async {
    await syncAll();
    return _status == SyncStatus.completed;
  }

  /// Get sync statistics
  Future<Map<String, dynamic>> getSyncStats() async {
    final counts = await _dbService.getSyncQueueCounts();
    final dbStats = await _dbService.getDatabaseStats();

    return {
      'pending_count': counts['pending'] ?? 0,
      'failed_count': counts['failed'] ?? 0,
      'status': _status.name,
      'is_syncing': _isSyncing,
      'database_stats': dbStats,
    };
  }

  /// Retry failed sync items
  Future<void> retryFailedItems() async {
    debugPrint('SyncService: Retrying failed items...');

    // Reset failed items to pending (with reset retry count)
    await _dbService.execute('''
      UPDATE sync_queue
      SET sync_status = 0, retry_count = 0, error_message = NULL
      WHERE sync_status = 2
    ''');

    // Trigger sync
    await syncAll();
  }

  /// Clear completed sync log entries older than specified days
  Future<void> cleanupSyncLog({int olderThanDays = 7}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));

    await _dbService.delete(
      'sync_log',
      'synced_at < ?',
      [cutoffDate.toIso8601String()],
    );

    debugPrint('SyncService: Cleaned up sync log entries older than $olderThanDays days');
  }
}
