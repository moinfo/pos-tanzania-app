import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Database service for offline data storage
/// Handles all SQLite operations for the POS Tanzania mobile app
class DatabaseService {
  static DatabaseService? _instance;
  static Database? _database;

  // Database version - increment when schema changes
  static const int _databaseVersion = 6;

  // Private constructor for singleton
  DatabaseService._();

  /// Get singleton instance
  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  /// Get database name based on client ID
  static String getDatabaseName(String clientId) {
    return 'pos_${clientId.toLowerCase().replaceAll(' ', '_')}_offline.db';
  }

  /// Initialize database for a specific client
  Future<Database> initDatabase(String clientId) async {
    if (_database != null) {
      return _database!;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, getDatabaseName(clientId));

    debugPrint('DatabaseService: Initializing database at $path');

    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: _configure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    return _database!;
  }

  /// Write-ahead logging, set before anything else touches the file.
  ///
  /// The default rollback journal takes an exclusive lock for the length of a
  /// write, so while SyncService is uploading a queued sale every read blocks
  /// behind it -- the cached lists, the pending counts, the till's own item
  /// lookup. On a phone's flash with a queue of a few hundred rows that is
  /// visible as jank, and under contention it surfaces as "database is
  /// locked". WAL lets readers carry on against the last committed state while
  /// one writer appends, which is exactly this app's shape: one background
  /// writer, several foreground readers.
  ///
  /// Also enables foreign keys, which sqflite leaves off by default.
  static Future<void> _configure(Database db) async {
    await db.execute('PRAGMA journal_mode = WAL');
    // NORMAL rather than FULL: with WAL this still survives an app crash, and
    // only loses the last commits if the DEVICE loses power mid-write. The
    // trade is one fsync per transaction instead of several, which on a till
    // ringing up sales continuously is the difference the seller feels.
    await db.execute('PRAGMA synchronous = NORMAL');
    await db.execute('PRAGMA foreign_keys = ON');
  }


  /// Open the database at an explicit path.
  ///
  /// Exists so tests can exercise the REAL schema and the real migrations
  /// against an in-memory database. Production code goes through
  /// [initDatabase], which derives the path from the client id -- a queue test
  /// that built its own tables would pass happily while the shipped schema
  /// drifted out from under it.
  @visibleForTesting
  Future<Database> initDatabaseAt(String path) async {
    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: _configure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _database!;
  }

  /// Get current database instance
  Database? get database => _database;

  /// Check if database is initialized
  bool get isInitialized => _database != null;

  /// Close database (call when switching clients)
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      debugPrint('DatabaseService: Database closed');
    }
  }

  /// Create all tables
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('DatabaseService: Creating database schema (version $version)');

    // Create tables in batch for better performance
    final batch = db.batch();

    // =====================================================
    // MASTER DATA TABLES (Synced from Server - Read Only)
    // =====================================================

    // People (Base for customers, employees, suppliers)
    batch.execute('''
      CREATE TABLE people (
        person_id INTEGER PRIMARY KEY,
        first_name TEXT,
        last_name TEXT,
        phone_number TEXT,
        email TEXT,
        address1 TEXT,
        address2 TEXT,
        city TEXT,
        state TEXT,
        zip TEXT,
        country TEXT,
        comments TEXT,
        credit_limit REAL DEFAULT 0,
        one_time_credit_limit REAL DEFAULT 0,
        supervisor_id INTEGER,
        last_synced_at TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Customers
    batch.execute('''
      CREATE TABLE customers (
        person_id INTEGER PRIMARY KEY,
        company_name TEXT,
        account_number TEXT,
        taxable INTEGER DEFAULT 1,
        discount_percent REAL DEFAULT 0,
        discount_type INTEGER DEFAULT 1,
        package_id INTEGER,
        points REAL DEFAULT 0,
        is_boda_boda INTEGER DEFAULT 0,
        one_time_credit INTEGER DEFAULT 0,
        dormant INTEGER DEFAULT 0,
        is_allowed_credit INTEGER DEFAULT 0,
        credit_limit REAL DEFAULT 0,
        balance REAL DEFAULT 0,
        bad_debtor INTEGER DEFAULT 0,
        nfc_confirm_required INTEGER DEFAULT 0,
        nfc_payment_enabled INTEGER DEFAULT 0,
        nfc_confirm_required_cash INTEGER DEFAULT 0,
        last_synced_at TEXT,
        FOREIGN KEY (person_id) REFERENCES people(person_id)
      )
    ''');

    // Employees (cached for reference)
    batch.execute('''
      CREATE TABLE employees (
        person_id INTEGER PRIMARY KEY,
        username TEXT,
        language TEXT DEFAULT 'english',
        language_code TEXT DEFAULT 'en',
        deleted INTEGER DEFAULT 0,
        last_synced_at TEXT,
        FOREIGN KEY (person_id) REFERENCES people(person_id)
      )
    ''');

    // Customer Cards (NFC cards linked to customers)
    batch.execute('''
      CREATE TABLE customer_cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_card_id INTEGER,
        customer_id INTEGER NOT NULL,
        card_uid TEXT NOT NULL UNIQUE,
        card_type TEXT DEFAULT 'nfc',
        is_active INTEGER DEFAULT 1,
        last_synced_at TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (customer_id) REFERENCES customers(person_id)
      )
    ''');

    // Supervisors
    batch.execute('''
      CREATE TABLE supervisors (
        supervisor_id INTEGER PRIMARY KEY,
        person_id INTEGER NOT NULL,
        last_synced_at TEXT,
        FOREIGN KEY (person_id) REFERENCES people(person_id)
      )
    ''');

    // Suppliers
    batch.execute('''
      CREATE TABLE suppliers (
        person_id INTEGER PRIMARY KEY,
        company_name TEXT,
        agency_name TEXT,
        account_number TEXT,
        deleted INTEGER DEFAULT 0,
        last_synced_at TEXT,
        FOREIGN KEY (person_id) REFERENCES people(person_id)
      )
    ''');

    // Items
    batch.execute('''
      CREATE TABLE items (
        item_id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT,
        supplier_id INTEGER,
        item_number TEXT,
        description TEXT,
        cost_price REAL DEFAULT 0,
        unit_price REAL DEFAULT 0,
        reorder_level REAL DEFAULT 0,
        receiving_quantity REAL DEFAULT 1,
        stock_type TEXT DEFAULT 'N/A',
        item_type INTEGER DEFAULT 0,
        is_serialized INTEGER DEFAULT 0,
        discount_limit REAL DEFAULT 100,
        tax1_name TEXT,
        tax1_percent REAL DEFAULT 0,
        tax2_name TEXT,
        tax2_percent REAL DEFAULT 0,
        custom1 TEXT,
        custom2 TEXT,
        custom3 TEXT,
        custom4 TEXT,
        custom5 TEXT,
        custom6 TEXT,
        custom7 TEXT,
        custom8 TEXT,
        custom9 TEXT,
        custom10 TEXT,
        arrange INTEGER DEFAULT 0,
        dormant INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
        last_synced_at TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Item Quantities by Location
    batch.execute('''
      CREATE TABLE item_quantities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER NOT NULL,
        location_id INTEGER NOT NULL,
        quantity REAL DEFAULT 0,
        last_synced_at TEXT,
        UNIQUE(item_id, location_id),
        FOREIGN KEY (item_id) REFERENCES items(item_id)
      )
    ''');

    // Item Taxes
    batch.execute('''
      CREATE TABLE items_taxes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER NOT NULL,
        name TEXT,
        percent REAL DEFAULT 0,
        tax_type INTEGER DEFAULT 0,
        cascade_tax INTEGER DEFAULT 0,
        cascade_sequence INTEGER DEFAULT 0,
        tax_category_id INTEGER,
        jurisdiction_id INTEGER,
        FOREIGN KEY (item_id) REFERENCES items(item_id)
      )
    ''');

    // Stock Locations
    batch.execute('''
      CREATE TABLE stock_locations (
        location_id INTEGER PRIMARY KEY,
        location_name TEXT NOT NULL,
        deleted INTEGER DEFAULT 0,
        last_synced_at TEXT
      )
    ''');

    // Expense Categories
    batch.execute('''
      CREATE TABLE expense_categories (
        expense_category_id INTEGER PRIMARY KEY,
        category_name TEXT NOT NULL,
        category_description TEXT,
        deleted INTEGER DEFAULT 0,
        last_synced_at TEXT
      )
    ''');

    // Tax Categories
    batch.execute('''
      CREATE TABLE tax_categories (
        tax_category_id INTEGER PRIMARY KEY,
        tax_category TEXT NOT NULL,
        tax_group_sequence INTEGER DEFAULT 0,
        deleted INTEGER DEFAULT 0,
        last_synced_at TEXT
      )
    ''');

    // Tax Codes
    batch.execute('''
      CREATE TABLE tax_codes (
        tax_code_id INTEGER PRIMARY KEY,
        tax_code TEXT,
        tax_code_name TEXT,
        city TEXT,
        state TEXT,
        deleted INTEGER DEFAULT 0,
        last_synced_at TEXT
      )
    ''');

    // =====================================================
    // TRANSACTIONAL TABLES (Created Locally, Synced to Server)
    // =====================================================

    // Sales
    batch.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_sale_id INTEGER,
        -- Idempotency key, minted ONCE when the sale is first recorded and
        -- never again. Every upload attempt for this sale carries it, so
        -- API_Controller::claim_request_id() replays the original response
        -- instead of writing a second sale. UNIQUE so a bug that tried to
        -- reuse one id across two sales fails here, locally, rather than
        -- silently making the second sale vanish into the first one's replay.
        request_id TEXT UNIQUE,
        customer_id INTEGER,
        employee_id INTEGER NOT NULL,
        sale_time TEXT NOT NULL,
        invoice_number TEXT,
        quote_number TEXT,
        work_order_number TEXT,
        sale_status INTEGER DEFAULT 0,
        sale_type INTEGER DEFAULT 0,
        dinner_table_id INTEGER,
        comment TEXT,
        subtotal REAL DEFAULT 0,
        tax_total REAL DEFAULT 0,
        total REAL DEFAULT 0,
        amount_tendered REAL DEFAULT 0,
        amount_change REAL DEFAULT 0,
        stock_location_id INTEGER,
        sync_status INTEGER DEFAULT 0,
        sync_error TEXT,
        sync_timestamp TEXT,
        -- When a person confirmed they have SEEN that the server refused this
        -- sale. Null while the refusal is still unread, which is what keeps
        -- the alert coming back after a force-quit. Never set by the sync
        -- code -- only by a human tapping through to the record.
        rejection_ack_at TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Sale Items
    batch.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        item_id INTEGER NOT NULL,
        item_name TEXT,
        line INTEGER DEFAULT 0,
        quantity_purchased REAL NOT NULL,
        item_cost_price REAL DEFAULT 0,
        item_unit_price REAL NOT NULL,
        discount REAL DEFAULT 0,
        discount_type INTEGER DEFAULT 1,
        discount_limit REAL DEFAULT 100,
        item_location INTEGER,
        print_option INTEGER DEFAULT 0,
        description TEXT,
        serialnumber TEXT,
        quantity_offer_id INTEGER,
        quantity_offer_free REAL DEFAULT 0,
        parent_line INTEGER,
        one_time_discount_id INTEGER,
        -- The approved discount request this line was priced under. Stored so
        -- a queued sale keeps the same paperwork an online one has; like the
        -- online path, it is not transmitted -- the server resolves approvals
        -- itself -- but without the column the INSERT fails outright and the
        -- sale cannot be saved at all.
        approved_request_id INTEGER,
        FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE
      )
    ''');

    // Sale Item Taxes
    batch.execute('''
      CREATE TABLE sale_items_taxes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_item_id INTEGER NOT NULL,
        tax_name TEXT,
        percent REAL DEFAULT 0,
        tax_type INTEGER DEFAULT 0,
        cascade_tax INTEGER DEFAULT 0,
        cascade_sequence INTEGER DEFAULT 0,
        item_tax_amount REAL DEFAULT 0,
        tax_category_id INTEGER,
        jurisdiction_id INTEGER,
        FOREIGN KEY (sale_item_id) REFERENCES sale_items(id) ON DELETE CASCADE
      )
    ''');

    // Sale Payments
    batch.execute('''
      CREATE TABLE sale_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        payment_type TEXT NOT NULL,
        payment_amount REAL NOT NULL,
        cash_refund REAL DEFAULT 0,
        transportation_cost REAL DEFAULT 0,
        employee_id INTEGER,
        stock_location_id INTEGER,
        payment_time TEXT,
        FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE
      )
    ''');

    // Sale Taxes
    batch.execute('''
      CREATE TABLE sale_taxes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        tax_type TEXT,
        tax_group TEXT,
        sale_tax_basis REAL DEFAULT 0,
        sale_tax_amount REAL DEFAULT 0,
        tax_rate REAL DEFAULT 0,
        sales_tax_code TEXT,
        rounding_code INTEGER DEFAULT 0,
        FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE
      )
    ''');

    // Expenses
    batch.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_expense_id INTEGER,
        supplier_id INTEGER,
        amount REAL NOT NULL,
        tax_amount REAL DEFAULT 0,
        description TEXT,
        date TEXT NOT NULL,
        employee_id INTEGER NOT NULL,
        expense_category_id INTEGER,
        category_name TEXT,
        payment_type TEXT,
        stock_location_id INTEGER,
        supplier_name TEXT,
        supplier_tax_code TEXT,
        deleted INTEGER DEFAULT 0,
        sync_status INTEGER DEFAULT 0,
        sync_error TEXT,
        sync_timestamp TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Receivings
    batch.execute('''
      CREATE TABLE receivings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_receiving_id INTEGER,
        supplier_id INTEGER NOT NULL,
        employee_id INTEGER NOT NULL,
        receiving_time TEXT NOT NULL,
        payment_type TEXT,
        reference TEXT,
        comment TEXT,
        stock_location_id INTEGER,
        total REAL DEFAULT 0,
        sync_status INTEGER DEFAULT 0,
        sync_error TEXT,
        sync_timestamp TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Receiving Items
    batch.execute('''
      CREATE TABLE receiving_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receiving_id INTEGER NOT NULL,
        item_id INTEGER NOT NULL,
        item_name TEXT,
        quantity_purchased REAL NOT NULL,
        item_cost_price REAL NOT NULL,
        discount_percent REAL DEFAULT 0,
        item_location INTEGER,
        serialnumber TEXT,
        line_total REAL DEFAULT 0,
        FOREIGN KEY (receiving_id) REFERENCES receivings(id) ON DELETE CASCADE
      )
    ''');

    // Banking
    batch.execute('''
      CREATE TABLE banking (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_banking_id INTEGER,
        date TEXT NOT NULL,
        amount REAL NOT NULL,
        reference TEXT,
        description TEXT,
        employee_id INTEGER NOT NULL,
        stock_location_id INTEGER,
        sync_status INTEGER DEFAULT 0,
        sync_error TEXT,
        sync_timestamp TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Customer Deposits/Withdrawals
    batch.execute('''
      CREATE TABLE customer_deposits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_deposit_id INTEGER,
        customer_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        type TEXT NOT NULL,
        reference TEXT,
        comment TEXT,
        employee_id INTEGER NOT NULL,
        stock_location_id INTEGER,
        sync_status INTEGER DEFAULT 0,
        sync_error TEXT,
        sync_timestamp TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Debits Credits (Customer Balance Transactions)
    batch.execute('''
      CREATE TABLE debits_credits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        client_id INTEGER NOT NULL,
        payment_mode TEXT,
        payment_id INTEGER,
        balance REAL DEFAULT 0,
        dr REAL DEFAULT 0,
        cr REAL DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
        date TEXT NOT NULL,
        employee_id INTEGER,
        stock_location_id INTEGER,
        sync_status INTEGER DEFAULT 0,
        sync_error TEXT,
        sync_timestamp TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // =====================================================
    // DISCOUNT & OFFER TABLES
    // =====================================================

    // One Time Discounts (Cached + Local Changes)
    batch.execute('''
      CREATE TABLE one_time_discounts (
        discount_id INTEGER PRIMARY KEY,
        document_number TEXT,
        requested_by INTEGER,
        customer_id INTEGER,
        item_id INTEGER,
        stock_location_id INTEGER,
        quantity REAL,
        discount_type INTEGER DEFAULT 1,
        discount_amount REAL,
        reason TEXT,
        valid_date TEXT,
        status TEXT DEFAULT 'pending',
        used_at TEXT,
        used_sale_id INTEGER,
        approved_by INTEGER,
        expires_at TEXT,
        deleted_at TEXT,
        is_local INTEGER DEFAULT 0,
        sync_status INTEGER DEFAULT 1,
        last_synced_at TEXT
      )
    ''');

    // Item Quantity Offers (Cached)
    batch.execute('''
      CREATE TABLE item_quantity_offers (
        offer_id INTEGER PRIMARY KEY,
        item_id INTEGER NOT NULL,
        stock_location_id INTEGER,
        buy_quantity REAL NOT NULL,
        reward_type TEXT,
        reward_item_id INTEGER,
        reward_quantity REAL DEFAULT 0,
        reward_discount_percent REAL DEFAULT 0,
        valid_from TEXT,
        valid_to TEXT,
        is_active INTEGER DEFAULT 1,
        last_synced_at TEXT
      )
    ''');

    // Offer Redemptions (Local + Synced)
    batch.execute('''
      CREATE TABLE offer_redemptions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_redemption_id INTEGER,
        offer_id INTEGER NOT NULL,
        sale_id INTEGER NOT NULL,
        customer_id INTEGER,
        quantity_purchased REAL,
        reward_given TEXT,
        redeemed_at TEXT,
        sync_status INTEGER DEFAULT 0,
        sync_timestamp TEXT,
        FOREIGN KEY (offer_id) REFERENCES item_quantity_offers(offer_id)
      )
    ''');

    // =====================================================
    // REWARDS & POINTS
    // =====================================================

    // Customer Packages (Cached)
    batch.execute('''
      CREATE TABLE customers_packages (
        package_id INTEGER PRIMARY KEY,
        package_name TEXT NOT NULL,
        points_percent REAL DEFAULT 0,
        deleted INTEGER DEFAULT 0,
        last_synced_at TEXT
      )
    ''');

    // Customer Points (Local + Synced)
    batch.execute('''
      CREATE TABLE customers_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        person_id INTEGER NOT NULL,
        package_id INTEGER,
        sale_id INTEGER,
        points_earned REAL DEFAULT 0,
        sync_status INTEGER DEFAULT 0,
        sync_timestamp TEXT
      )
    ''');

    // =====================================================
    // TRANSACTIONS MODULE (Wakala/SIM/Cash/Bank Basis)
    // =====================================================

    // Cash Basis Categories
    batch.execute('''
      CREATE TABLE cash_basis_categories (
        category_id INTEGER PRIMARY KEY,
        category_name TEXT NOT NULL,
        type TEXT,
        last_synced_at TEXT
      )
    ''');

    // Cash Basis Transactions
    batch.execute('''
      CREATE TABLE cash_basis_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        category_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        description TEXT,
        employee_id INTEGER,
        location_id INTEGER,
        sync_status INTEGER DEFAULT 0,
        sync_error TEXT,
        sync_timestamp TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Bank Basis Categories
    batch.execute('''
      CREATE TABLE bank_basis_categories (
        category_id INTEGER PRIMARY KEY,
        category_name TEXT NOT NULL,
        type TEXT,
        last_synced_at TEXT
      )
    ''');

    // Bank Basis Transactions
    batch.execute('''
      CREATE TABLE bank_basis_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        category_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        date TEXT NOT NULL,
        description TEXT,
        employee_id INTEGER,
        location_id INTEGER,
        sync_status INTEGER DEFAULT 0,
        sync_error TEXT,
        sync_timestamp TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // SIMs
    batch.execute('''
      CREATE TABLE sims (
        sim_id INTEGER PRIMARY KEY,
        sim_number TEXT NOT NULL,
        network TEXT,
        status TEXT DEFAULT 'active',
        location_id INTEGER,
        last_synced_at TEXT
      )
    ''');

    // Wakala Transactions
    batch.execute('''
      CREATE TABLE wakala_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_wakala_id INTEGER,
        sim_id INTEGER NOT NULL,
        transaction_type TEXT,
        amount REAL NOT NULL,
        float_before REAL DEFAULT 0,
        float_after REAL DEFAULT 0,
        date TEXT NOT NULL,
        employee_id INTEGER,
        sync_status INTEGER DEFAULT 0,
        sync_error TEXT,
        sync_timestamp TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // =====================================================
    // Z-REPORTS & CASH SUBMISSIONS
    // =====================================================

    // Z-Reports
    batch.execute('''
      CREATE TABLE zreports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_zreport_id INTEGER,
        report_date TEXT NOT NULL,
        employee_id INTEGER NOT NULL,
        location_id INTEGER,
        opening_float REAL DEFAULT 0,
        closing_float REAL DEFAULT 0,
        total_sales REAL DEFAULT 0,
        total_cash REAL DEFAULT 0,
        total_card REAL DEFAULT 0,
        total_credit REAL DEFAULT 0,
        total_expenses REAL DEFAULT 0,
        total_banking REAL DEFAULT 0,
        comment TEXT,
        sync_status INTEGER DEFAULT 0,
        sync_error TEXT,
        sync_timestamp TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Cash Submissions
    batch.execute('''
      CREATE TABLE cash_submissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_submission_id INTEGER,
        submission_date TEXT NOT NULL,
        employee_id INTEGER NOT NULL,
        supervisor_id INTEGER,
        location_id INTEGER,
        amount REAL NOT NULL,
        reference TEXT,
        comment TEXT,
        status TEXT DEFAULT 'pending',
        sync_status INTEGER DEFAULT 0,
        sync_error TEXT,
        sync_timestamp TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Profit Submissions
    batch.execute('''
      CREATE TABLE profit_submissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_id INTEGER,
        submission_date TEXT NOT NULL,
        employee_id INTEGER NOT NULL,
        location_id INTEGER,
        amount REAL NOT NULL,
        comment TEXT,
        sync_status INTEGER DEFAULT 0,
        sync_error TEXT,
        sync_timestamp TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // =====================================================
    // SYNC MANAGEMENT
    // =====================================================

    // Sync Queue
    batch.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        payload TEXT,
        priority INTEGER DEFAULT 0,
        retry_count INTEGER DEFAULT 0,
        max_retries INTEGER DEFAULT 5,
        sync_status INTEGER DEFAULT 0,
        error_message TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP,
        last_attempted_at TEXT
      )
    ''');

    // Pending Actions
    //
    // Every CREATE other than a sale waits here. One row is one thing a person
    // did: the endpoint it was going to, the exact body that was going to be
    // sent, and the idempotency key it was going to be sent under.
    //
    // Storing the request rather than a per-entity table is what keeps this to
    // ONE mechanism. The upload does not rebuild the call from a model -- it
    // re-sends the same body to the same path with the same key, so what the
    // queue posts is what the failed online attempt posted, and there is no
    // second code path that can drift away from the first.
    //
    // request_id is NOT NULL and UNIQUE. Not null because an action with no
    // key cannot be uploaded safely and must not be accepted into the queue in
    // the first place; unique because reusing one key for two different actions
    // would make the second one vanish into the first one's replay, and it is
    // far better for that to fail here, locally, than on the server.
    batch.execute('''
      CREATE TABLE pending_actions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type TEXT NOT NULL,
        endpoint TEXT NOT NULL,
        label TEXT,
        request_id TEXT NOT NULL UNIQUE,
        payload TEXT NOT NULL,
        summary TEXT,
        server_id INTEGER,
        sync_status INTEGER DEFAULT 0,
        sync_error TEXT,
        sync_timestamp TEXT,
        -- See sales.rejection_ack_at: null means a refusal nobody has read
        -- yet, and that is what survives the app being killed.
        rejection_ack_at TEXT,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Sync Log
    batch.execute('''
      CREATE TABLE sync_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL,
        entity_id INTEGER,
        server_id INTEGER,
        action TEXT NOT NULL,
        status TEXT NOT NULL,
        message TEXT,
        synced_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Last Sync Timestamps (for incremental sync)
    batch.execute('''
      CREATE TABLE sync_timestamps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL UNIQUE,
        last_synced_at TEXT,
        updated_at TEXT DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // =====================================================
    // APP CONFIGURATION
    // =====================================================

    // App Config (Cached from server)
    batch.execute('''
      CREATE TABLE app_config (
        key TEXT PRIMARY KEY,
        value TEXT,
        last_synced_at TEXT
      )
    ''');

    // User Session
    batch.execute('''
      CREATE TABLE user_session (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        username TEXT,
        first_name TEXT,
        last_name TEXT,
        token TEXT,
        location_id INTEGER,
        permissions TEXT,
        logged_in_at TEXT,
        client_id TEXT
      )
    ''');

    // =====================================================
    // INDEXES FOR PERFORMANCE
    // =====================================================

    batch.execute('CREATE INDEX idx_items_name ON items(name)');
    batch.execute('CREATE INDEX idx_items_category ON items(category)');
    batch.execute('CREATE INDEX idx_items_supplier ON items(supplier_id)');
    batch.execute('CREATE INDEX idx_item_quantities_location ON item_quantities(location_id)');
    batch.execute('CREATE INDEX idx_item_quantities_item ON item_quantities(item_id)');
    batch.execute('CREATE INDEX idx_people_phone ON people(phone_number)');
    batch.execute('CREATE INDEX idx_people_name ON people(first_name, last_name)');
    batch.execute('CREATE INDEX idx_sales_sync_status ON sales(sync_status)');
    batch.execute('CREATE INDEX idx_sales_date ON sales(sale_time)');
    batch.execute('CREATE INDEX idx_sales_customer ON sales(customer_id)');
    batch.execute('CREATE INDEX idx_sales_employee ON sales(employee_id)');
    batch.execute('CREATE INDEX idx_sales_location ON sales(stock_location_id)');
    batch.execute('CREATE INDEX idx_sale_items_sale ON sale_items(sale_id)');
    batch.execute('CREATE INDEX idx_sale_items_item ON sale_items(item_id)');
    batch.execute('CREATE INDEX idx_expenses_sync_status ON expenses(sync_status)');
    batch.execute('CREATE INDEX idx_expenses_date ON expenses(date)');
    batch.execute('CREATE INDEX idx_receivings_sync_status ON receivings(sync_status)');
    batch.execute('CREATE INDEX idx_receivings_supplier ON receivings(supplier_id)');
    batch.execute('CREATE INDEX idx_sync_queue_status ON sync_queue(sync_status)');
    batch.execute('CREATE INDEX idx_sync_queue_entity ON sync_queue(entity_type, entity_id)');
    batch.execute('CREATE INDEX idx_one_time_discounts_customer ON one_time_discounts(customer_id)');
    batch.execute('CREATE INDEX idx_one_time_discounts_item ON one_time_discounts(item_id)');
    batch.execute('CREATE INDEX idx_debits_credits_client ON debits_credits(client_id)');
    batch.execute('CREATE INDEX idx_customer_deposits_customer ON customer_deposits(customer_id)');
    batch.execute('CREATE INDEX idx_pending_actions_status ON pending_actions(sync_status)');
    batch.execute('CREATE INDEX idx_customer_cards_uid ON customer_cards(card_uid)');
    batch.execute('CREATE INDEX idx_customer_cards_customer ON customer_cards(customer_id)');

    await batch.commit(noResult: true);

    debugPrint('DatabaseService: Database schema created successfully');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('DatabaseService: Upgrading database from v$oldVersion to v$newVersion');

    // Add migration logic here for future versions
    if (oldVersion < 2) {
      // v2: persist customer NFC confirmation settings in the offline cache so
      // confirmation enforcement survives offline fallback. Guarded per-column
      // because a fresh install (created at the current schema) already has them.
      final existing = await db.rawQuery('PRAGMA table_info(customers)');
      final cols = existing.map((r) => r['name'] as String).toSet();
      if (!cols.contains('nfc_confirm_required')) {
        await db.execute('ALTER TABLE customers ADD COLUMN nfc_confirm_required INTEGER DEFAULT 0');
      }
      if (!cols.contains('nfc_payment_enabled')) {
        await db.execute('ALTER TABLE customers ADD COLUMN nfc_payment_enabled INTEGER DEFAULT 0');
      }
      if (!cols.contains('nfc_confirm_required_cash')) {
        await db.execute('ALTER TABLE customers ADD COLUMN nfc_confirm_required_cash INTEGER DEFAULT 0');
      }
    }

    if (oldVersion < 3) {
      // v3: sales carry the idempotency key they are uploaded with.
      //
      // Not UNIQUE here, unlike the fresh-install schema: SQLite cannot add a
      // UNIQUE column with ALTER TABLE, and rebuilding the sales table on an
      // upgrade would put un-uploaded sales at risk for a constraint that only
      // guards against a bug we do not have. A partial unique INDEX gives the
      // same protection without touching the existing rows; NULLs are exempt,
      // which is what we want for the rows migrated below.
      final existing = await db.rawQuery('PRAGMA table_info(sales)');
      final cols = existing.map((r) => r['name'] as String).toSet();
      if (!cols.contains('request_id')) {
        await db.execute('ALTER TABLE sales ADD COLUMN request_id TEXT');
        await db.execute(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_sales_request_id '
          'ON sales (request_id) WHERE request_id IS NOT NULL',
        );

        // Any sale already queued on an older build has no key. Backfill one
        // each so it can be uploaded exactly once, rather than leaving it to
        // upload unguarded. These sales have never reached the server (they
        // are still queued), so a fresh key is correct for them.
        const uuid = Uuid();
        final unkeyed = await db.query(
          'sales',
          columns: ['id'],
          where: 'request_id IS NULL',
        );
        for (final row in unkeyed) {
          await db.update(
            'sales',
            {'request_id': uuid.v4()},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
        }
        debugPrint('DatabaseService: v3 backfilled ${unkeyed.length} sale request ids');
      }

    }

    if (oldVersion < 4) {
      // v4: the offline sale writer has always written this column; the table
      // never had it, so every attempt to save a sale offline died with
      // "table sale_items has no column named approved_request_id" and the
      // sale was lost. Adding it is what makes that path run at all.
      final itemCols = await db.rawQuery('PRAGMA table_info(sale_items)');
      final itemColNames = itemCols.map((r) => r['name'] as String).toSet();
      if (!itemColNames.contains('approved_request_id')) {
        await db.execute('ALTER TABLE sale_items ADD COLUMN approved_request_id INTEGER');
      }
    }

    if (oldVersion < 5) {
      // v5: everything a seller or clerk can only CREATE gets the same queue,
      // and the same idempotency key, that sales already had.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pending_actions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          action_type TEXT NOT NULL,
          endpoint TEXT NOT NULL,
          label TEXT,
          request_id TEXT NOT NULL UNIQUE,
          payload TEXT NOT NULL,
          summary TEXT,
          server_id INTEGER,
          sync_status INTEGER DEFAULT 0,
          sync_error TEXT,
          sync_timestamp TEXT,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_pending_actions_status '
        'ON pending_actions(sync_status)',
      );

      // Clear out queue rows for the four entity types whose uploaders sent no
      // request_id and have been removed.
      //
      // Nothing in any shipped build ever wrote one -- createLocalExpense and
      // its siblings had no callers, which is exactly why ba6624d could leave
      // them un-idempotent -- so in practice this deletes nothing. It runs
      // anyway because the alternative, if a row DID exist, is a queue entry no
      // uploader will ever pick up: invisible, permanent, and counted against
      // the seller in the pending badge forever.
      final orphaned = await db.delete(
        'sync_queue',
        where: 'entity_type IN (?, ?, ?, ?)',
        whereArgs: ['expense', 'receiving', 'banking', 'customer_deposit'],
      );
      if (orphaned > 0) {
        debugPrint(
          'DatabaseService: v5 removed $orphaned queue rows with no uploader',
        );
      }
    }

    if (oldVersion < 6) {
      // v6: a refusal has to be READ by somebody, and the app has to know
      // whether it has been.
      //
      // Until now a rejected record was only a red number. A number cannot
      // tell you whether the person who needed to see it ever did, so the app
      // had no basis for insisting -- and a refusal nobody reads is the exact
      // shape of data dying quietly. This column is that basis: null means
      // unread, and because it lives in SQLite rather than in memory, killing
      // the app does not count as having read it.
      //
      // Deliberately per-record rather than one global "seen" flag: reading
      // about yesterday's refused expense must not silence today's refused
      // sale.
      for (final table in const ['sales', 'pending_actions']) {
        final cols = await db.rawQuery('PRAGMA table_info($table)');
        final names = cols.map((r) => r['name'] as String).toSet();
        if (!names.contains('rejection_ack_at')) {
          await db.execute('ALTER TABLE $table ADD COLUMN rejection_ack_at TEXT');
        }
      }
    }
  }

  /// Delete database (for testing or reset)
  Future<void> deleteDatabase(String clientId) async {
    await closeDatabase();
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, getDatabaseName(clientId));
    await databaseFactory.deleteDatabase(path);
    debugPrint('DatabaseService: Database deleted at $path');
  }

  /// Get database statistics
  Future<Map<String, int>> getDatabaseStats() async {
    if (_database == null) {
      return {};
    }

    final stats = <String, int>{};
    final tables = [
      'items', 'customers', 'suppliers', 'sales', 'expenses',
      'receivings', 'sync_queue', 'one_time_discounts'
    ];

    for (final table in tables) {
      try {
        final result = await _database!.rawQuery('SELECT COUNT(*) as count FROM $table');
        stats[table] = Sqflite.firstIntValue(result) ?? 0;
      } catch (e) {
        stats[table] = 0;
      }
    }

    return stats;
  }

  // =====================================================
  // SYNC STATUS CONSTANTS
  // =====================================================

  static const int syncStatusPending = 0;
  static const int syncStatusSynced = 1;
  static const int syncStatusFailed = 2;

  /// A person looked at a record the server had refused and chose, explicitly,
  /// to stop trying to upload it.
  ///
  /// This is NOT a delete. The row stays exactly where it is, with its payload
  /// and the server's own words for the refusal, so a question asked next week
  /// can still be answered. What changes is that it no longer appears in the
  /// queue, is no longer counted, and is never uploaded again. Nothing in the
  /// sync path ever sets this -- only a human, through a confirmation that
  /// names what is being given up.
  static const int syncStatusDiscarded = 3;

  // =====================================================
  // GENERIC CRUD OPERATIONS
  // =====================================================

  /// Insert a record into a table
  Future<int> insert(String table, Map<String, dynamic> data) async {
    if (_database == null) throw Exception('Database not initialized');
    return await _database!.insert(table, data);
  }

  /// Update a record in a table
  Future<int> update(String table, Map<String, dynamic> data, String where, List<dynamic> whereArgs) async {
    if (_database == null) throw Exception('Database not initialized');
    return await _database!.update(table, data, where: where, whereArgs: whereArgs);
  }

  /// Delete a record from a table
  Future<int> delete(String table, String where, List<dynamic> whereArgs) async {
    if (_database == null) throw Exception('Database not initialized');
    return await _database!.delete(table, where: where, whereArgs: whereArgs);
  }

  /// Query records from a table
  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (_database == null) throw Exception('Database not initialized');
    return await _database!.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  /// Execute raw SQL query
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    if (_database == null) throw Exception('Database not initialized');
    return await _database!.rawQuery(sql, arguments);
  }

  /// Execute raw SQL statement
  Future<void> execute(String sql, [List<dynamic>? arguments]) async {
    if (_database == null) throw Exception('Database not initialized');
    await _database!.execute(sql, arguments);
  }

  /// Run in transaction
  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    if (_database == null) throw Exception('Database not initialized');
    return await _database!.transaction(action);
  }

  // =====================================================
  // ITEMS OPERATIONS
  // =====================================================

  /// Save items to local database (upsert)
  Future<void> saveItems(List<Map<String, dynamic>> items) async {
    if (_database == null) throw Exception('Database not initialized');

    final batch = _database!.batch();
    final now = DateTime.now().toIso8601String();

    for (final item in items) {
      item['last_synced_at'] = now;
      batch.insert(
        'items',
        item,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    debugPrint('DatabaseService: Saved ${items.length} items');
  }

  /// Save item quantities to local database
  Future<void> saveItemQuantities(List<Map<String, dynamic>> quantities) async {
    if (_database == null) throw Exception('Database not initialized');

    final batch = _database!.batch();
    final now = DateTime.now().toIso8601String();

    for (final qty in quantities) {
      qty['last_synced_at'] = now;
      batch.insert(
        'item_quantities',
        qty,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    debugPrint('DatabaseService: Saved ${quantities.length} item quantities');
  }

  /// Get items with quantities for a location
  Future<List<Map<String, dynamic>>> getItemsWithQuantities({
    int? locationId,
    String? search,
    String? category,
    int limit = 50,
    int offset = 0,
  }) async {
    if (_database == null) throw Exception('Database not initialized');

    String sql = '''
      SELECT i.*, COALESCE(iq.quantity, 0) as quantity
      FROM items i
      LEFT JOIN item_quantities iq ON i.item_id = iq.item_id
    ''';

    final conditions = <String>[];
    final args = <dynamic>[];

    if (locationId != null) {
      conditions.add('(iq.location_id = ? OR iq.location_id IS NULL)');
      args.add(locationId);
    }

    if (search != null && search.isNotEmpty) {
      conditions.add('(i.name LIKE ? OR i.item_number LIKE ?)');
      args.add('%$search%');
      args.add('%$search%');
    }

    if (category != null && category.isNotEmpty) {
      conditions.add('i.category = ?');
      args.add(category);
    }

    conditions.add('i.is_deleted = 0');
    conditions.add('i.dormant = 0');

    if (conditions.isNotEmpty) {
      sql += ' WHERE ${conditions.join(' AND ')}';
    }

    sql += ' ORDER BY i.name ASC LIMIT ? OFFSET ?';
    args.add(limit);
    args.add(offset);

    return await _database!.rawQuery(sql, args);
  }

  /// Update item quantity locally (after sale)
  Future<void> updateItemQuantity(int itemId, int locationId, double quantityChange) async {
    if (_database == null) throw Exception('Database not initialized');

    await _database!.rawUpdate('''
      UPDATE item_quantities
      SET quantity = quantity + ?
      WHERE item_id = ? AND location_id = ?
    ''', [quantityChange, itemId, locationId]);
  }

  // =====================================================
  // CUSTOMERS OPERATIONS
  // =====================================================

  /// Save customers to local database
  Future<void> saveCustomers(List<Map<String, dynamic>> customers) async {
    if (_database == null) throw Exception('Database not initialized');

    final batch = _database!.batch();
    final now = DateTime.now().toIso8601String();

    for (final customer in customers) {
      // Save to people table first
      final personData = {
        'person_id': customer['person_id'],
        'first_name': customer['first_name'],
        'last_name': customer['last_name'],
        'phone_number': customer['phone_number'],
        'email': customer['email'],
        'address1': customer['address1'],
        'address2': customer['address2'],
        'city': customer['city'],
        'state': customer['state'],
        'zip': customer['zip'],
        'country': customer['country'],
        'comments': customer['comments'],
        'last_synced_at': now,
      };
      batch.insert('people', personData, conflictAlgorithm: ConflictAlgorithm.replace);

      // Save to customers table
      final customerData = {
        'person_id': customer['person_id'],
        'company_name': customer['company_name'],
        'account_number': customer['account_number'],
        'taxable': customer['taxable'] ?? 1,
        'discount_percent': customer['discount_percent'] ?? 0,
        'discount_type': customer['discount_type'] ?? 1,
        'package_id': customer['package_id'],
        'points': customer['points'] ?? 0,
        'is_allowed_credit': customer['is_allowed_credit'] ?? 0,
        'credit_limit': customer['credit_limit'] ?? 0,
        'balance': customer['balance'] ?? 0,
        'dormant': customer['dormant'] ?? 0,
        'bad_debtor': customer['bad_debtor'] ?? 0,
        // NFC confirmation settings — persist so enforcement survives offline.
        'nfc_confirm_required': (customer['nfc_confirm_required'] == true || customer['nfc_confirm_required'] == 1) ? 1 : 0,
        'nfc_payment_enabled': (customer['nfc_payment_enabled'] == true || customer['nfc_payment_enabled'] == 1) ? 1 : 0,
        'nfc_confirm_required_cash': (customer['nfc_confirm_required_cash'] == true || customer['nfc_confirm_required_cash'] == 1) ? 1 : 0,
        'last_synced_at': now,
      };
      batch.insert('customers', customerData, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
    debugPrint('DatabaseService: Saved ${customers.length} customers');
  }

  /// Get customers with search
  Future<List<Map<String, dynamic>>> getCustomers({
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    if (_database == null) throw Exception('Database not initialized');

    String sql = '''
      SELECT p.*, c.*
      FROM customers c
      JOIN people p ON c.person_id = p.person_id
    ''';

    final conditions = <String>[];
    final args = <dynamic>[];

    if (search != null && search.isNotEmpty) {
      conditions.add('(p.first_name LIKE ? OR p.last_name LIKE ? OR p.phone_number LIKE ? OR c.company_name LIKE ?)');
      args.add('%$search%');
      args.add('%$search%');
      args.add('%$search%');
      args.add('%$search%');
    }

    conditions.add('c.dormant = 0');

    if (conditions.isNotEmpty) {
      sql += ' WHERE ${conditions.join(' AND ')}';
    }

    sql += ' ORDER BY p.first_name ASC LIMIT ? OFFSET ?';
    args.add(limit);
    args.add(offset);

    return await _database!.rawQuery(sql, args);
  }

  // =====================================================
  // SALES OPERATIONS
  // =====================================================

  /// Create a local sale (offline).
  ///
  /// [requestId] is the idempotency key this sale will be uploaded under. Pass
  /// the one the failed online attempt already used -- that attempt may have
  /// reached the server and been answered into a dead socket, and reusing its
  /// key is what makes the upload return that same sale instead of creating a
  /// second one. Omitted only when the sale never had an online attempt, in
  /// which case a fresh key is minted here. Either way the key is written once
  /// and every later attempt reads it back from this row.
  Future<int> createLocalSale(
    Map<String, dynamic> sale,
    List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> payments, {
    String? requestId,
  }) async {
    if (_database == null) throw Exception('Database not initialized');

    return await _database!.transaction((txn) async {
      // Insert sale
      sale['sync_status'] = syncStatusPending;
      sale['request_id'] = requestId ?? const Uuid().v4();
      sale['created_at'] = DateTime.now().toIso8601String();
      sale['updated_at'] = DateTime.now().toIso8601String();

      final saleId = await txn.insert('sales', sale);

      // Insert sale items
      for (var i = 0; i < items.length; i++) {
        final item = Map<String, dynamic>.from(items[i]);
        item['sale_id'] = saleId;
        item['line'] = i;
        await txn.insert('sale_items', item);
      }

      // Insert payments
      for (final payment in payments) {
        final paymentData = Map<String, dynamic>.from(payment);
        paymentData['sale_id'] = saleId;
        paymentData['payment_time'] = DateTime.now().toIso8601String();
        await txn.insert('sale_payments', paymentData);
      }

      // Draw the sold quantity down in the local cache, in the same
      // transaction as the sale.
      //
      // This does NOT reserve anything -- the server is the only authority on
      // stock and it cannot be told about this sale yet. What it does is keep
      // THIS device honest: without it a seller looking at a cached quantity
      // could ring up the last carton five times in a row and be shown stock
      // in hand every time. Across devices nothing can be done offline, and
      // the server settles that at upload time by refusing the losers.
      //
      // Deliberately not restored if the upload later fails: the next master
      // data sync overwrites these rows with the server's real numbers, which
      // is the only figure worth trusting anyway.
      for (final item in items) {
        final itemId = item['item_id'];
        final locationId = item['item_location'] ?? sale['stock_location_id'];
        final quantity = (item['quantity_purchased'] as num?)?.toDouble() ?? 0;
        if (itemId == null || locationId == null || quantity == 0) continue;

        await txn.rawUpdate(
          'UPDATE item_quantities SET quantity = quantity - ? '
          'WHERE item_id = ? AND location_id = ?',
          [quantity, itemId, locationId],
        );
      }

      // Add to sync queue
      await txn.insert('sync_queue', {
        'entity_type': 'sale',
        'entity_id': saleId,
        'action': 'create',
        'priority': 1,
        'sync_status': syncStatusPending,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('DatabaseService: Created local sale with id $saleId');
      return saleId;
    });
  }

  /// Get pending sales (not synced)
  Future<List<Map<String, dynamic>>> getPendingSales() async {
    if (_database == null) throw Exception('Database not initialized');

    return await _database!.query(
      'sales',
      where: 'sync_status = ?',
      whereArgs: [syncStatusPending],
      orderBy: 'created_at ASC',
    );
  }

  /// Update sale sync status
  Future<void> updateSaleSyncStatus(int localSaleId, int status, {int? serverSaleId, String? error}) async {
    if (_database == null) throw Exception('Database not initialized');

    final data = <String, dynamic>{
      'sync_status': status,
      'sync_timestamp': DateTime.now().toIso8601String(),
    };

    if (serverSaleId != null) {
      data['server_sale_id'] = serverSaleId;
    }

    if (error != null) {
      data['sync_error'] = error;
    }

    await _database!.update(
      'sales',
      data,
      where: 'id = ?',
      whereArgs: [localSaleId],
    );
  }

  /// Get sale with items and payments
  Future<Map<String, dynamic>?> getSaleWithDetails(int saleId) async {
    if (_database == null) throw Exception('Database not initialized');

    final sales = await _database!.query('sales', where: 'id = ?', whereArgs: [saleId]);
    if (sales.isEmpty) return null;

    final sale = Map<String, dynamic>.from(sales.first);

    sale['items'] = await _database!.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
    sale['payments'] = await _database!.query('sale_payments', where: 'sale_id = ?', whereArgs: [saleId]);

    return sale;
  }

  // =====================================================
  // SYNC QUEUE OPERATIONS
  // =====================================================

  /// Get pending sync items
  Future<List<Map<String, dynamic>>> getPendingSyncItems({String? entityType, int limit = 50}) async {
    if (_database == null) throw Exception('Database not initialized');

    String? where;
    List<dynamic>? whereArgs;

    if (entityType != null) {
      where = 'sync_status = ? AND entity_type = ?';
      whereArgs = [syncStatusPending, entityType];
    } else {
      where = 'sync_status = ?';
      whereArgs = [syncStatusPending];
    }

    return await _database!.query(
      'sync_queue',
      where: where,
      whereArgs: whereArgs,
      // id breaks the tie: created_at has one-second resolution, and two sales
      // rung up in the same second must still upload in the order they were
      // made -- the receipt sequence the seller handed out depends on it.
      orderBy: 'priority DESC, created_at ASC, id ASC',
      limit: limit,
    );
  }

  /// Update sync queue item status
  Future<void> updateSyncQueueStatus(int id, int status, {String? error}) async {
    if (_database == null) throw Exception('Database not initialized');

    final data = <String, dynamic>{
      'sync_status': status,
      'last_attempted_at': DateTime.now().toIso8601String(),
    };

    if (error != null) {
      data['error_message'] = error;
    }

    if (status == syncStatusPending) {
      // Increment retry count
      await _database!.rawUpdate(
        'UPDATE sync_queue SET retry_count = retry_count + 1, sync_status = ?, last_attempted_at = ?, error_message = ? WHERE id = ?',
        [status, data['last_attempted_at'], error, id],
      );
    } else {
      await _database!.update('sync_queue', data, where: 'id = ?', whereArgs: [id]);
    }
  }

  /// Note an attempt that failed without the server ever answering.
  ///
  /// Deliberately does NOT touch retry_count. A phone that spends a week out
  /// of coverage would otherwise burn through max_retries against a server it
  /// never spoke to and mark perfectly good sales as permanently failed. Only
  /// a real answer from the server is evidence worth counting against a sale.
  Future<void> recordSyncQueueAttempt(int id, String error) async {
    if (_database == null) throw Exception('Database not initialized');

    await _database!.update(
      'sync_queue',
      {
        'sync_status': syncStatusPending,
        'last_attempted_at': DateTime.now().toIso8601String(),
        'error_message': error,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Remove from sync queue (after successful sync)
  Future<void> removeSyncQueueItem(int id) async {
    if (_database == null) throw Exception('Database not initialized');
    await _database!.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  /// Get sync queue count by status
  Future<Map<String, int>> getSyncQueueCounts() async {
    if (_database == null) return {'pending': 0, 'failed': 0};

    final pending = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(*) FROM sync_queue WHERE sync_status = ?', [syncStatusPending])
    ) ?? 0;

    final failed = Sqflite.firstIntValue(
      await _database!.rawQuery('SELECT COUNT(*) FROM sync_queue WHERE sync_status = ?', [syncStatusFailed])
    ) ?? 0;

    return {'pending': pending, 'failed': failed};
  }

  /// Sales that have not reached the server yet, newest first, with the queue
  /// state joined on so the seller can see WHY one is stuck rather than only
  /// that it is. Drives the sync sheet's list.
  ///
  /// Sales whose queue row is gone but which are still marked unsynced would
  /// be invisible to a plain join, so this reads from `sales` and pulls the
  /// queue row in on the left.
  Future<List<Map<String, dynamic>>> getUnsyncedSales({int limit = 100}) async {
    if (_database == null) return [];

    return await _database!.rawQuery('''
      SELECT s.id, s.request_id, s.sale_time, s.total, s.customer_id,
             s.sync_status, s.sync_error, s.server_sale_id,
             s.rejection_ack_at, s.created_at,
             q.retry_count, q.error_message, q.last_attempted_at,
             q.sync_status AS queue_status
      FROM sales s
      LEFT JOIN sync_queue q
        ON q.entity_type = 'sale' AND q.entity_id = s.id
      WHERE s.sync_status NOT IN (?, ?)
      ORDER BY s.created_at DESC, s.id DESC
      LIMIT ?
    ''', [syncStatusSynced, syncStatusDiscarded, limit]);
  }

  /// Count of sales the seller is still owed an upload for, split by whether
  /// the queue has given up on them. Cheaper than loading the list for a badge.
  Future<Map<String, int>> getUnsyncedSaleCounts() async {
    if (_database == null) return {'pending': 0, 'failed': 0};

    final pending = Sqflite.firstIntValue(await _database!.rawQuery(
      'SELECT COUNT(*) FROM sales WHERE sync_status = ?',
      [syncStatusPending],
    )) ?? 0;

    final failed = Sqflite.firstIntValue(await _database!.rawQuery(
      'SELECT COUNT(*) FROM sales WHERE sync_status = ?',
      [syncStatusFailed],
    )) ?? 0;

    return {'pending': pending, 'failed': failed};
  }

  // =====================================================
  // PENDING ACTIONS (every CREATE that is not a sale)
  // =====================================================

  /// Entity type the sync queue files a pending action under.
  static const String pendingActionEntity = 'pending_action';

  /// Record one action that could not reach the server, so it can be uploaded
  /// later exactly once.
  ///
  /// [requestId] MUST be the key the failed online attempt already used. That
  /// attempt may have been received and processed before the connection died --
  /// we simply never heard the answer -- and carrying its key in here is what
  /// turns the eventual upload into a replay of that record rather than a
  /// second one. Minting a fresh key at this point would BE the duplicate.
  ///
  /// [payload] is the exact body that was posted, minus the key itself; the key
  /// is re-attached at upload time so one column stays the single home of it.
  ///
  /// Throws if the key is already in the queue. That is deliberate: a caller
  /// reusing a key across two different actions is a bug, and failing here --
  /// locally, loudly, before anything is promised to the user -- is far better
  /// than the server quietly replaying the first action's answer for the
  /// second one.
  Future<int> queueAction({
    required String actionType,
    required String endpoint,
    required String label,
    required String requestId,
    required Map<String, dynamic> payload,
    String? summary,
  }) async {
    if (_database == null) throw Exception('Database not initialized');
    if (requestId.isEmpty) {
      throw ArgumentError('queueAction requires a non-empty request id');
    }

    return await _database!.transaction((txn) async {
      final actionId = await txn.insert('pending_actions', {
        'action_type': actionType,
        'endpoint': endpoint,
        'label': label,
        'request_id': requestId,
        'payload': jsonEncode(payload),
        'summary': summary,
        'sync_status': syncStatusPending,
        'created_at': DateTime.now().toIso8601String(),
      });

      await txn.insert('sync_queue', {
        'entity_type': pendingActionEntity,
        'entity_id': actionId,
        'action': 'create',
        'priority': 0,
        'sync_status': syncStatusPending,
        'created_at': DateTime.now().toIso8601String(),
      });

      debugPrint('DatabaseService: Queued $actionType action id $actionId');
      return actionId;
    });
  }

  /// One queued action by its local id.
  Future<Map<String, dynamic>?> getPendingAction(int id) async {
    if (_database == null) throw Exception('Database not initialized');

    final rows =
        await _database!.query('pending_actions', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// Update a queued action after an upload attempt.
  Future<void> updatePendingActionStatus(
    int id,
    int status, {
    int? serverId,
    String? error,
  }) async {
    if (_database == null) throw Exception('Database not initialized');

    final data = <String, dynamic>{
      'sync_status': status,
      'sync_timestamp': DateTime.now().toIso8601String(),
    };
    if (serverId != null) data['server_id'] = serverId;
    if (error != null) data['sync_error'] = error;

    await _database!
        .update('pending_actions', data, where: 'id = ?', whereArgs: [id]);
  }

  /// Actions that have not reached the server yet, newest first, with the
  /// queue state joined on so a person can see WHY one is stuck rather than
  /// only that it is. Mirrors [getUnsyncedSales] and drives the same sheet.
  Future<List<Map<String, dynamic>>> getUnsyncedActions({int limit = 100}) async {
    if (_database == null) return [];

    return await _database!.rawQuery('''
      SELECT a.id, a.action_type, a.label, a.summary, a.request_id,
             a.created_at, a.sync_status, a.sync_error, a.server_id,
             a.rejection_ack_at,
             q.retry_count, q.error_message, q.last_attempted_at,
             q.sync_status AS queue_status
      FROM pending_actions a
      LEFT JOIN sync_queue q
        ON q.entity_type = ? AND q.entity_id = a.id
      WHERE a.sync_status NOT IN (?, ?)
      ORDER BY a.created_at DESC, a.id DESC
      LIMIT ?
    ''', [pendingActionEntity, syncStatusSynced, syncStatusDiscarded, limit]);
  }

  /// Counts for the badge, split by whether the queue has given up.
  Future<Map<String, int>> getUnsyncedActionCounts() async {
    if (_database == null) return {'pending': 0, 'failed': 0};

    final pending = Sqflite.firstIntValue(await _database!.rawQuery(
      'SELECT COUNT(*) FROM pending_actions WHERE sync_status = ?',
      [syncStatusPending],
    )) ?? 0;

    final failed = Sqflite.firstIntValue(await _database!.rawQuery(
      'SELECT COUNT(*) FROM pending_actions WHERE sync_status = ?',
      [syncStatusFailed],
    )) ?? 0;

    return {'pending': pending, 'failed': failed};
  }

  // =====================================================
  // REJECTED RECORDS
  //
  // A record the server LOOKED AT and refused. Retrying replays the same
  // refusal, so nothing on this device will ever move it -- which makes it the
  // one state where data dies quietly unless a person is told. Everything
  // below exists to make sure a person is told, and to give them something to
  // do about it other than shrug.
  // =====================================================

  /// Entity type the sync queue files a sale under.
  static const String saleEntity = 'sale';

  /// The two tables a queued record can live in, keyed by the entity type the
  /// sync queue files it under. Keeping the mapping in one place is what lets
  /// the acknowledge / retry / discard trio treat a refused sale and a refused
  /// expense as the same problem, which for the person holding the phone they
  /// are.
  static const Map<String, String> _rejectableTables = {
    saleEntity: 'sales',
    pendingActionEntity: 'pending_actions',
  };

  /// How many refusals nobody has read yet.
  ///
  /// Drives the alert that will not go away. Counted across both tables,
  /// because a seller does not care which table their money is stuck in.
  Future<int> countUnreadRejections() async {
    if (_database == null) return 0;

    var total = 0;
    for (final table in _rejectableTables.values) {
      total += Sqflite.firstIntValue(await _database!.rawQuery(
            'SELECT COUNT(*) FROM $table '
            'WHERE sync_status = ? AND rejection_ack_at IS NULL',
            [syncStatusFailed],
          )) ??
          0;
    }
    return total;
  }

  /// Every refusal, read or not, so a screen can list them.
  ///
  /// Returns the two tables' rows in one list under a common shape; the caller
  /// gets `entity_type` to tell them apart.
  Future<List<Map<String, dynamic>>> getRejections({int limit = 100}) async {
    if (_database == null) return [];

    final sales = await _database!.rawQuery('''
      SELECT id, sale_time, total, sync_error, rejection_ack_at, created_at
      FROM sales WHERE sync_status = ?
      ORDER BY created_at DESC, id DESC LIMIT ?
    ''', [syncStatusFailed, limit]);

    final actions = await _database!.rawQuery('''
      SELECT id, label, summary, sync_error, rejection_ack_at, created_at
      FROM pending_actions WHERE sync_status = ?
      ORDER BY created_at DESC, id DESC LIMIT ?
    ''', [syncStatusFailed, limit]);

    return [
      for (final row in sales)
        {...row, 'entity_type': saleEntity},
      for (final row in actions)
        {...row, 'entity_type': pendingActionEntity},
    ];
  }

  /// Record that a person has SEEN this refusal.
  ///
  /// Only ever called from a human action. Nothing in the sync path may call
  /// it: an app that marks its own bad news as read is back to losing data
  /// quietly, which is the whole thing this is here to stop.
  Future<void> acknowledgeRejection({
    required String entityType,
    required int id,
  }) async {
    final table = _rejectableTables[entityType];
    if (_database == null || table == null) return;

    await _database!.update(
      table,
      {'rejection_ack_at': DateTime.now().toIso8601String()},
      where: 'id = ? AND sync_status = ?',
      whereArgs: [id, syncStatusFailed],
    );
  }

  /// Mark every refusal currently on the device as seen.
  ///
  /// Backs the one button on the alert that dismisses it for good, and it is
  /// deliberately the only bulk form -- a person who has scrolled the list has
  /// seen the list.
  Future<void> acknowledgeAllRejections() async {
    if (_database == null) return;

    final now = DateTime.now().toIso8601String();
    for (final table in _rejectableTables.values) {
      await _database!.update(
        table,
        {'rejection_ack_at': now},
        where: 'sync_status = ? AND rejection_ack_at IS NULL',
        whereArgs: [syncStatusFailed],
      );
    }
  }

  /// Put a refused record back in the queue so the next sync tries it again.
  ///
  /// Safe to do by hand because the record keeps the request_id it was first
  /// written under: if an earlier attempt did reach the server, the server
  /// replays that answer rather than writing a second record. Some 4xx really
  /// do become valid later -- a document number that has since been freed, a
  /// stock location the seller has since been given back -- and the difference
  /// between those and the permanent ones is a judgement only a person can
  /// make, which is why nothing here happens on its own.
  ///
  /// Returns false when there was nothing in that state to reopen.
  Future<bool> reopenRejected({
    required String entityType,
    required int id,
  }) async {
    final table = _rejectableTables[entityType];
    if (_database == null || table == null) return false;

    final rows = await _database!.query(
      table,
      where: 'id = ? AND sync_status = ?',
      whereArgs: [id, syncStatusFailed],
    );
    if (rows.isEmpty) return false;

    await _database!.update(
      table,
      {'sync_status': syncStatusPending, 'sync_error': null},
      where: 'id = ?',
      whereArgs: [id],
    );

    // The queue row is what the uploader actually reads. It is normally still
    // there, marked failed; the retry counter is cleared with it, because a
    // person choosing to try again is not asking for the five attempts that
    // already ran to be held against this one.
    final queued = await _database!.update(
      'sync_queue',
      {
        'sync_status': syncStatusPending,
        'retry_count': 0,
        'error_message': null,
      },
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType, id],
    );

    if (queued == 0) {
      // No queue row survived. Rebuild one rather than leave a record marked
      // pending that no uploader will ever pick up -- invisible work is how a
      // queue silently stops being a queue.
      await _database!.insert('sync_queue', {
        'entity_type': entityType,
        'entity_id': id,
        'action': 'create',
        'priority': entityType == saleEntity ? 1 : 0,
        'sync_status': syncStatusPending,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    debugPrint('DatabaseService: reopened rejected $entityType $id');
    return true;
  }

  /// Stop trying to upload a refused record, on purpose.
  ///
  /// NOT a delete. The row keeps its payload, its key and the server's words
  /// for the refusal; it simply leaves the queue and the counts. Support can
  /// still read it off the device afterwards, which would be impossible if
  /// this threw the row away -- and a person who discards the wrong thing has
  /// not destroyed it.
  ///
  /// Returns false when there was nothing in that state to discard.
  Future<bool> discardRejected({
    required String entityType,
    required int id,
  }) async {
    final table = _rejectableTables[entityType];
    if (_database == null || table == null) return false;

    final changed = await _database!.update(
      table,
      {
        'sync_status': syncStatusDiscarded,
        // Discarding is itself an act of having seen it.
        'rejection_ack_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ? AND sync_status = ?',
      whereArgs: [id, syncStatusFailed],
    );
    if (changed == 0) return false;

    // The queue row goes, so nothing ever uploads it and nothing counts it.
    await _database!.delete(
      'sync_queue',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType, id],
    );

    debugPrint('DatabaseService: discarded rejected $entityType $id');
    return true;
  }

  /// Add to sync log
  Future<void> addSyncLog(String entityType, int entityId, int? serverId, String action, String status, {String? message}) async {
    if (_database == null) throw Exception('Database not initialized');

    await _database!.insert('sync_log', {
      'entity_type': entityType,
      'entity_id': entityId,
      'server_id': serverId,
      'action': action,
      'status': status,
      'message': message,
      'synced_at': DateTime.now().toIso8601String(),
    });
  }

  // =====================================================
  // SYNC TIMESTAMPS
  // =====================================================

  /// Get last sync timestamp for an entity type
  Future<String?> getLastSyncTimestamp(String entityType) async {
    if (_database == null) return null;

    final result = await _database!.query(
      'sync_timestamps',
      where: 'entity_type = ?',
      whereArgs: [entityType],
    );

    if (result.isEmpty) return null;
    return result.first['last_synced_at'] as String?;
  }

  /// Update last sync timestamp
  Future<void> updateLastSyncTimestamp(String entityType) async {
    if (_database == null) throw Exception('Database not initialized');

    await _database!.insert(
      'sync_timestamps',
      {
        'entity_type': entityType,
        'last_synced_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // =====================================================
  // SUPPLIERS OPERATIONS
  // =====================================================

  /// Save suppliers to local database
  Future<void> saveSuppliers(List<Map<String, dynamic>> suppliers) async {
    if (_database == null) throw Exception('Database not initialized');

    final batch = _database!.batch();
    final now = DateTime.now().toIso8601String();

    for (final supplier in suppliers) {
      // Save to people table first
      final personData = {
        'person_id': supplier['person_id'],
        'first_name': supplier['first_name'],
        'last_name': supplier['last_name'],
        'phone_number': supplier['phone_number'],
        'email': supplier['email'],
        'address1': supplier['address1'],
        'city': supplier['city'],
        'last_synced_at': now,
      };
      batch.insert('people', personData, conflictAlgorithm: ConflictAlgorithm.replace);

      // Save to suppliers table
      final supplierData = {
        'person_id': supplier['person_id'],
        'company_name': supplier['company_name'],
        'agency_name': supplier['agency_name'],
        'account_number': supplier['account_number'],
        'deleted': supplier['deleted'] ?? 0,
        'last_synced_at': now,
      };
      batch.insert('suppliers', supplierData, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
    debugPrint('DatabaseService: Saved ${suppliers.length} suppliers');
  }

  /// Get suppliers
  Future<List<Map<String, dynamic>>> getSuppliers({String? search}) async {
    if (_database == null) throw Exception('Database not initialized');

    String sql = '''
      SELECT p.*, s.*
      FROM suppliers s
      JOIN people p ON s.person_id = p.person_id
      WHERE s.deleted = 0
    ''';

    final args = <dynamic>[];

    if (search != null && search.isNotEmpty) {
      sql += ' AND (p.first_name LIKE ? OR s.company_name LIKE ?)';
      args.add('%$search%');
      args.add('%$search%');
    }

    sql += ' ORDER BY COALESCE(s.company_name, p.first_name) ASC';

    return await _database!.rawQuery(sql, args);
  }

  // =====================================================
  // EXPENSE OPERATIONS
  // =====================================================

  // An offline expense is queued through [queueAction] like every other
  // non-sale create, not written into the `expenses` table. The old
  // createLocalExpense() wrote a row and filed it under an entity type whose
  // uploader sent no request_id -- so the first thing that ever called it
  // would have started duplicating expenses on every retry. It had no callers
  // and is gone rather than left as a trap.

  /// Save expense categories
  Future<void> saveExpenseCategories(List<Map<String, dynamic>> categories) async {
    if (_database == null) throw Exception('Database not initialized');

    final batch = _database!.batch();
    final now = DateTime.now().toIso8601String();

    for (final category in categories) {
      category['last_synced_at'] = now;
      batch.insert('expense_categories', category, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
    debugPrint('DatabaseService: Saved ${categories.length} expense categories');
  }

  /// Get expense categories
  Future<List<Map<String, dynamic>>> getExpenseCategories() async {
    if (_database == null) throw Exception('Database not initialized');

    return await _database!.query(
      'expense_categories',
      where: 'deleted = 0',
      orderBy: 'category_name ASC',
    );
  }

  // =====================================================
  // STOCK LOCATIONS
  // =====================================================

  /// Save stock locations
  Future<void> saveStockLocations(List<Map<String, dynamic>> locations) async {
    if (_database == null) throw Exception('Database not initialized');

    final batch = _database!.batch();
    final now = DateTime.now().toIso8601String();

    for (final location in locations) {
      location['last_synced_at'] = now;
      batch.insert('stock_locations', location, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
    debugPrint('DatabaseService: Saved ${locations.length} stock locations');
  }

  /// Get stock locations
  Future<List<Map<String, dynamic>>> getStockLocations() async {
    if (_database == null) throw Exception('Database not initialized');

    return await _database!.query(
      'stock_locations',
      where: 'deleted = 0',
      orderBy: 'location_name ASC',
    );
  }

  // =====================================================
  // ONE TIME DISCOUNTS
  // =====================================================

  /// Save one time discounts
  Future<void> saveOneTimeDiscounts(List<Map<String, dynamic>> discounts) async {
    if (_database == null) throw Exception('Database not initialized');

    final batch = _database!.batch();
    final now = DateTime.now().toIso8601String();

    for (final discount in discounts) {
      discount['last_synced_at'] = now;
      discount['sync_status'] = syncStatusSynced;
      batch.insert('one_time_discounts', discount, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
    debugPrint('DatabaseService: Saved ${discounts.length} one-time discounts');
  }

  /// Get available one-time discounts for customer and item
  Future<List<Map<String, dynamic>>> getAvailableOneTimeDiscounts({
    required int customerId,
    required int itemId,
    required int locationId,
    required double quantity,
  }) async {
    if (_database == null) throw Exception('Database not initialized');

    return await _database!.query(
      'one_time_discounts',
      where: '''
        customer_id = ? AND item_id = ? AND stock_location_id = ?
        AND quantity <= ? AND status = 'approved'
        AND (expires_at IS NULL OR expires_at > ?)
        AND used_at IS NULL AND deleted_at IS NULL
      ''',
      whereArgs: [customerId, itemId, locationId, quantity, DateTime.now().toIso8601String()],
    );
  }

  /// Mark one-time discount as used locally
  Future<void> markOneTimeDiscountUsed(int discountId, int saleId) async {
    if (_database == null) throw Exception('Database not initialized');

    await _database!.update(
      'one_time_discounts',
      {
        'used_at': DateTime.now().toIso8601String(),
        'used_sale_id': saleId,
        'status': 'used',
        'sync_status': syncStatusPending,
      },
      where: 'discount_id = ?',
      whereArgs: [discountId],
    );
  }

  // =====================================================
  // ITEM QUANTITY OFFERS
  // =====================================================

  /// Save item quantity offers
  Future<void> saveItemQuantityOffers(List<Map<String, dynamic>> offers) async {
    if (_database == null) throw Exception('Database not initialized');

    final batch = _database!.batch();
    final now = DateTime.now().toIso8601String();

    for (final offer in offers) {
      offer['last_synced_at'] = now;
      batch.insert('item_quantity_offers', offer, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
    debugPrint('DatabaseService: Saved ${offers.length} item quantity offers');
  }

  /// Get active offers for an item
  Future<List<Map<String, dynamic>>> getActiveOffersForItem(int itemId, int locationId) async {
    if (_database == null) throw Exception('Database not initialized');

    final now = DateTime.now().toIso8601String();

    return await _database!.query(
      'item_quantity_offers',
      where: '''
        item_id = ? AND (stock_location_id = ? OR stock_location_id IS NULL)
        AND is_active = 1
        AND (valid_from IS NULL OR valid_from <= ?)
        AND (valid_to IS NULL OR valid_to >= ?)
      ''',
      whereArgs: [itemId, locationId, now, now],
    );
  }

  // =====================================================
  // CLEAR DATA OPERATIONS
  // =====================================================

  /// Clear all synced data (keep pending)
  Future<void> clearSyncedData() async {
    if (_database == null) throw Exception('Database not initialized');

    // Clear master data
    await _database!.delete('items');
    await _database!.delete('item_quantities');
    await _database!.delete('customers');
    await _database!.delete('people');
    await _database!.delete('suppliers');
    await _database!.delete('expense_categories');
    await _database!.delete('stock_locations');
    await _database!.delete('one_time_discounts', where: 'is_local = 0');
    await _database!.delete('item_quantity_offers');

    // Clear synced transactions (keep pending)
    await _database!.delete('sales', where: 'sync_status = ?', whereArgs: [syncStatusSynced]);
    await _database!.delete('expenses', where: 'sync_status = ?', whereArgs: [syncStatusSynced]);
    await _database!.delete('receivings', where: 'sync_status = ?', whereArgs: [syncStatusSynced]);

    // Uploaded actions only. A pending or failed one is still owed to the
    // server and must survive a cache clear -- it is the only copy there is.
    await _database!.delete('pending_actions', where: 'sync_status = ?', whereArgs: [syncStatusSynced]);

    // Clear completed sync queue items
    await _database!.delete('sync_queue', where: 'sync_status = ?', whereArgs: [syncStatusSynced]);

    // Reset sync timestamps
    await _database!.delete('sync_timestamps');

    debugPrint('DatabaseService: Cleared synced data');
  }

  // =====================================================
  // CUSTOMER CARDS OPERATIONS (NFC)
  // =====================================================

  /// Save customer cards from server
  Future<void> saveCustomerCards(List<Map<String, dynamic>> cards) async {
    if (_database == null) throw Exception('Database not initialized');

    final batch = _database!.batch();
    final now = DateTime.now().toIso8601String();

    for (final card in cards) {
      final cardData = {
        'server_card_id': card['id'] ?? card['card_id'],
        'customer_id': card['customer_id'] ?? card['person_id'],
        'card_uid': card['card_uid'],
        'card_type': card['card_type'] ?? 'nfc',
        'is_active': card['is_active'] == true || card['is_active'] == 1 ? 1 : 0,
        'last_synced_at': now,
        'created_at': card['created_at'] ?? now,
        'updated_at': card['updated_at'] ?? now,
      };
      batch.insert('customer_cards', cardData, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
    debugPrint('DatabaseService: Saved ${cards.length} customer cards');
  }

  /// Get customer by card UID
  Future<Map<String, dynamic>?> getCustomerByCardUid(String cardUid) async {
    if (_database == null) throw Exception('Database not initialized');

    final result = await _database!.rawQuery('''
      SELECT p.*, c.*, cc.card_uid, cc.card_type
      FROM customer_cards cc
      JOIN customers c ON cc.customer_id = c.person_id
      JOIN people p ON c.person_id = p.person_id
      WHERE cc.card_uid = ? AND cc.is_active = 1
      LIMIT 1
    ''', [cardUid]);

    if (result.isEmpty) return null;
    return result.first;
  }

  /// Get all cards for a customer
  Future<List<Map<String, dynamic>>> getCustomerCards(int customerId) async {
    if (_database == null) throw Exception('Database not initialized');

    return await _database!.query(
      'customer_cards',
      where: 'customer_id = ? AND is_active = 1',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
  }

  /// Save a new customer card locally
  Future<int> saveCustomerCard(Map<String, dynamic> card) async {
    if (_database == null) throw Exception('Database not initialized');

    final now = DateTime.now().toIso8601String();
    final cardData = {
      'server_card_id': card['id'] ?? card['server_card_id'],
      'customer_id': card['customer_id'],
      'card_uid': card['card_uid'],
      'card_type': card['card_type'] ?? 'nfc',
      'is_active': 1,
      'last_synced_at': now,
      'created_at': now,
      'updated_at': now,
    };

    return await _database!.insert(
      'customer_cards',
      cardData,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Deactivate a customer card
  Future<void> deactivateCustomerCard(String cardUid) async {
    if (_database == null) throw Exception('Database not initialized');

    await _database!.update(
      'customer_cards',
      {
        'is_active': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'card_uid = ?',
      whereArgs: [cardUid],
    );
  }

  /// Check if card UID already exists
  Future<bool> cardUidExists(String cardUid) async {
    if (_database == null) throw Exception('Database not initialized');

    final result = await _database!.rawQuery(
      'SELECT COUNT(*) as count FROM customer_cards WHERE card_uid = ? AND is_active = 1',
      [cardUid],
    );

    return (result.first['count'] as int) > 0;
  }
}
