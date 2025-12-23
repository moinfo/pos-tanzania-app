import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_service.dart';
import 'api_service.dart';
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

  // Configuration
  static const int _maxRetries = 5;
  static const Duration _autoSyncInterval = Duration(minutes: 5);

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

  /// Start auto-sync timer
  void _startAutoSyncTimer() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(_autoSyncInterval, (timer) async {
      if (!_isSyncing) {
        await syncAll();
      }
    });
  }

  /// Update sync counts and notify listeners
  Future<void> _updateSyncCounts() async {
    final counts = await _dbService.getSyncQueueCounts();
    onSyncCountChanged?.call(counts['pending'] ?? 0, counts['failed'] ?? 0);
  }

  /// Set sync status and notify
  void _setStatus(SyncStatus status) {
    _status = status;
    onSyncStatusChanged?.call(status);
  }

  /// Check if online
  Future<bool> _isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      debugPrint('SyncService: Error checking connectivity - $e');
      return true; // Assume online if check fails
    }
  }

  /// Sync all pending items
  Future<void> syncAll() async {
    if (_isSyncing) {
      debugPrint('SyncService: Already syncing, skipping...');
      return;
    }

    // Check connectivity first
    if (!await _isOnline()) {
      debugPrint('SyncService: No connectivity, skipping sync');
      return;
    }

    _isSyncing = true;
    _setStatus(SyncStatus.syncing);

    debugPrint('SyncService: Starting sync...');

    try {
      // Sync in order of priority
      await _syncSales();
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

  /// Sync pending sales
  Future<void> _syncSales() async {
    final pendingItems = await _dbService.getPendingSyncItems(entityType: 'sale');
    debugPrint('SyncService: Found ${pendingItems.length} pending sales to sync');

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
        // Get sale details from local DB
        final sale = await _dbService.getSaleWithDetails(entityId);
        if (sale == null) {
          await _dbService.removeSyncQueueItem(item['id'] as int);
          continue;
        }

        // Convert local sale to Sale model for API
        final saleModel = _convertLocalSaleToModel(sale);

        // Send to server
        final response = await _apiService.createSale(saleModel);

        if (response.isSuccess && response.data != null) {
          final serverSaleId = response.data!.saleId;

          // Update local sale with server ID
          await _dbService.updateSaleSyncStatus(
            entityId,
            DatabaseService.syncStatusSynced,
            serverSaleId: serverSaleId,
          );

          // Remove from sync queue
          await _dbService.removeSyncQueueItem(item['id'] as int);

          // Log success
          await _dbService.addSyncLog('sale', entityId, serverSaleId, 'create', 'success');

          // Notify
          onItemSynced?.call(SyncResult(
            entityType: 'sale',
            entityId: entityId,
            success: true,
            serverId: serverSaleId,
          ));

          debugPrint('SyncService: Sale $entityId synced successfully (server ID: $serverSaleId)');
        } else {
          throw Exception(response.message ?? 'Unknown error');
        }
      } catch (e) {
        debugPrint('SyncService: Failed to sync sale $entityId - $e');

        // Update retry count
        await _dbService.updateSyncQueueStatus(
          item['id'] as int,
          DatabaseService.syncStatusPending,
          error: e.toString(),
        );

        // Update sale sync status
        await _dbService.updateSaleSyncStatus(entityId, DatabaseService.syncStatusFailed, error: e.toString());

        // Log failure
        await _dbService.addSyncLog('sale', entityId, null, 'create', 'failed', message: e.toString());

        // Notify
        onItemSynced?.call(SyncResult(
          entityType: 'sale',
          entityId: entityId,
          success: false,
          error: e.toString(),
        ));
      }
    }
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
