# Offline Implementation Plan for POS Tanzania Mobile App

## Overview

This document outlines the comprehensive plan for implementing offline functionality in the POS Tanzania mobile application. The implementation will allow users to continue working without internet connectivity and automatically synchronize data when connection is restored.

---

## Current State Analysis

### Architecture
- **Framework:** Flutter with Provider 6.1.1 (ChangeNotifier pattern)
- **API Service:** Centralized service with 80+ endpoints (`lib/services/api_service.dart`)
- **Authentication:** Bearer token stored in FlutterSecureStorage
- **State Management:** Multiple providers (Auth, Sale, Receiving, Location, Permission, Theme)

### Current Local Storage
| Storage Type | Usage |
|--------------|-------|
| SharedPreferences | User preferences, theme, selected location, permissions (JSON) |
| FlutterSecureStorage | Authentication token |
| In-Memory Cache | Dashboard data (60-second TTL) |

### Gap
- **No local database exists** - All data fetched from server on demand
- **No offline capability** - App requires constant internet connection
- **No sync mechanism** - No queue for pending operations

---

## Complete Server Database Structure

### Summary: 50+ Tables

The server database (MySQL) contains the following tables organized by category:

---

### 1. PEOPLE & ACCOUNTS (6 tables)

| Table | Description | Key Fields |
|-------|-------------|------------|
| `ospos_people` | Core person information | person_id, first_name, last_name, phone_number, email, address1, address2, city, state, zip, country, comments, credit_limit, one_time_credit_limit, supervisor_id |
| `ospos_customers` | Customer-specific data | person_id, company_name, account_number, taxable, discount_percent, package_id, points, is_boda_boda, one_time_credit, dormant, is_allowed_credit, bad_debtor |
| `ospos_employees` | Employee accounts | person_id, username, password, hash_version, language, language_code, deleted |
| `ospos_supervisors` | Supervisor management | supervisor_id, person_id |
| `ospos_drivers` | Driver information | driver_id, person_id |
| `ospos_person` | Alternative person model | (shared structure with people) |

---

### 2. ITEMS & INVENTORY (10 tables)

| Table | Description | Key Fields |
|-------|-------------|------------|
| `ospos_items` | Product catalog | item_id, name, category, supplier_id, item_number, description, cost_price, unit_price, reorder_level, stock_type, item_type, custom1-10, discount_limit, arrange, dormant, is_serialized, is_deleted |
| `ospos_item_quantities` | Stock levels by location | item_id, location_id, quantity |
| `ospos_item_kits` | Bundle/kit definitions | item_kit_id, item_id, kit_discount_percent, price_option, print_option |
| `ospos_item_kit_items` | Items in a kit | item_kit_id, item_id, quantity, kit_sequence |
| `ospos_inventory` | Inventory transaction log | trans_id, trans_items, trans_user, trans_date, trans_comment, trans_location, trans_inventory, trans_customer_id |
| `ospos_inventory_transaction` | Detailed inventory tracking | id, item_id, location_id, quantity, transaction_type, reference_id, created_at |
| `ospos_stock_locations` | Warehouse/storage locations | location_id, location_name, deleted |
| `ospos_items_taxes` | Tax rates for items | item_id, name, percent, tax_type, cascade_tax, cascade_sequence, tax_category_id, jurisdiction_id |
| `ospos_attribute` | Item attribute definitions | attribute_id, name |
| `ospos_attribute_links` | Links items to attributes | attribute_id, item_id, attribute_value |
| `ospos_attribute_values` | Attribute value storage | attribute_value_id, attribute_id, value |

---

### 3. SUPPLIERS & RECEIVING (4 tables)

| Table | Description | Key Fields |
|-------|-------------|------------|
| `ospos_suppliers` | Supplier information | person_id, company_name, agency_name, account_number, deleted |
| `ospos_suppliers_creditor` | Supplier credit tracking | creditor_id, supplier_id, amount, date, balance |
| `ospos_receivings` | Purchase orders/receivings | receiving_id, supplier_id, employee_id, receiving_time, payment_type, reference, comment |
| `ospos_receivings_items` | Line items in PO | receiving_id, item_id, quantity_purchased, item_cost_price, discount_percent, item_location, serialnumber |

---

### 4. SALES & QUOTES (6 tables)

| Table | Description | Key Fields |
|-------|-------------|------------|
| `ospos_sales` | Sales transactions | sale_id, customer_id, employee_id, sale_time, invoice_number, quote_number, work_order_number, sale_status (0=completed, 2=suspended), sale_type (0=POS, 1=Invoice, 2=Return), dinner_table_id, comment |
| `ospos_sales_items` | Line items per sale | sale_id, item_id, line, quantity_purchased, item_cost_price, item_unit_price, discount, discount_type, discount_limit, item_location, print_option, description, serialnumber |
| `ospos_sales_payments` | Payment details per sale | sale_id, payment_id, payment_type, payment_amount, cash_refund, transportation_cost, employee_id, stock_location_id, payment_time |
| `ospos_sales_taxes` | Tax amounts per sale | sale_id, tax_type, tax_group, sale_tax_basis, sale_tax_amount, tax_rate, sales_tax_code, rounding_code |
| `ospos_sales_items_taxes` | Tax per line item | sale_id, item_id, line, tax_name, percent, tax_type, cascade_tax, cascade_sequence, item_tax_amount, tax_category_id, jurisdiction_id |
| `ospos_dinner_tables` | Restaurant table mgmt | dinner_table_id, name, status (occupied/available) |

---

### 5. EXPENSES & FINANCIAL (6 tables)

| Table | Description | Key Fields |
|-------|-------------|------------|
| `ospos_expenses` | Operating expenses | expense_id, supplier_id, amount, tax_amount, description, date, employee_id, expense_category_id, payment_type, stock_location_id, deleted |
| `ospos_expense_category` | Expense classifications | expense_category_id, category_name, category_description, deleted |
| `ospos_banking` | Bank transactions | banking_id, date, amount, reference, description, employee_id, stock_location_id |
| `ospos_deposit_model` | Deposit tracking | deposit_id, customer_id, amount, date, reference, employee_id |
| `ospos_account` | Financial accounts | account_id, account_name, account_type, balance |
| `ospos_financial_analysis_model` | Financial reporting | analysis_id, type, period, data |

---

### 6. CUSTOMER FINANCE (6 tables)

| Table | Description | Key Fields |
|-------|-------------|------------|
| `ospos_debits_credits` | Customer debit/credit balance | id, client_id, payment_mode, payment_id, balance, dr, delete, date, employee_id, stock_location_id |
| `ospos_customer_deposits` | Customer advance deposits | deposit_id, customer_id, amount, date, type (deposit/withdrawal), reference, employee_id, stock_location_id |
| `ospos_customer_credit_limit` | Credit limit settings | id, customer_id, credit_limit, requested_by, approved_by, status, created_at, approved_at |
| `ospos_advance_salary_model` | Employee advance salary | advance_id, employee_id, amount, date, status |
| `ospos_loan_model` | Employee loan tracking | loan_id, employee_id, amount, balance, date, status |
| `ospos_customer_rewards` | Customer reward management | reward_id, customer_id, points, date, type |

---

### 7. GIFT CARDS & REWARDS (4 tables)

| Table | Description | Key Fields |
|-------|-------------|------------|
| `ospos_giftcards` | Gift card records | giftcard_id, giftcard_number, value, person_id, deleted |
| `ospos_customers_packages` | Loyalty program packages | package_id, package_name, points_percent, deleted |
| `ospos_customers_points` | Points earned per customer | id, person_id, package_id, sale_id, points_earned |
| `ospos_sales_reward_points` | Points tracking per sale | sale_id, earned, used |

---

### 8. DISCOUNTS & OFFERS (3 tables)

| Table | Description | Key Fields |
|-------|-------------|------------|
| `ospos_one_time_discounts` | Ad-hoc discounts | discount_id, document_number, requested_by, customer_id, item_id, stock_location_id, quantity, discount_type, discount_amount, reason, valid_date, status, used_at, used_sale_id, approved_by, expires_at, deleted_at |
| `ospos_item_quantity_offer` | Bulk promotional offers | offer_id, item_id, stock_location_id, buy_quantity, reward_type, reward_item_id, reward_quantity, reward_discount_percent, valid_from, valid_to, is_active |
| `ospos_item_quantity_offer_redemption` | Offer redemption tracking | redemption_id, offer_id, sale_id, customer_id, quantity_purchased, reward_given, redeemed_at |

---

### 9. APPROVAL & WORKFLOW (5 tables)

| Table | Description | Key Fields |
|-------|-------------|------------|
| `ospos_approval_flows` | Workflow definitions | flow_id, name, model_type, description, status, created_at, created_by |
| `ospos_approval_flow_steps` | Steps in workflow | step_id, flow_id, role_id, step_order, action, can_return, can_reject |
| `ospos_approval_statuses` | Document approval status | id, document_id, document_type, current_status, current_step, approved_by, rejected_reason, created_at |
| `ospos_process_approvals` | Individual approval records | approval_id, document_id, document_type, step_id, approved_by, action, comment, created_at |
| `ospos_commission_passcodes` | Commission passcode mgmt | passcode_id, passcode, employee_id, valid_from, valid_to, is_active |

---

### 10. ROLES & PERMISSIONS (4 tables)

| Table | Description | Key Fields |
|-------|-------------|------------|
| `ospos_permissions` | Permission definitions | permission_id, module_id, location_id |
| `ospos_grants` | Permission assignments | grant_id, permission_id, person_id, menu_group |
| `ospos_modules` | System modules | module_id, name_lang_key, desc_lang_key, sort |
| `ospos_roles` | Role definitions | role_id, role_name, description |
| `ospos_role_permissions` | Role-to-permission mapping | role_id, permission_id |

---

### 11. TAX CONFIGURATION (4 tables)

| Table | Description | Key Fields |
|-------|-------------|------------|
| `ospos_tax_categories` | Tax category definitions | tax_category_id, tax_category, tax_group_sequence, deleted |
| `ospos_tax_codes` | Tax code definitions | tax_code_id, tax_code, tax_code_name, city, state, deleted |
| `ospos_tax_code_rates` | Tax rates by code | tax_code_id, tax_category_id, tax_rate, rounding_code |
| `ospos_tax_jurisdiction` | Tax jurisdiction config | jurisdiction_id, jurisdiction_name, tax_group, cascade_sequence, tax_type |

---

### 12. NOTIFICATION & COMMUNICATION (3 tables)

| Table | Description | Key Fields |
|-------|-------------|------------|
| `ospos_notification` | System notifications | notification_id, title, message, type, user_id, read, created_at |
| `ospos_announcement` | Company announcements | announcement_id, title, message, image_path, created_by, created_at, expires_at |
| `ospos_issue` | Issue/ticket tracking | issue_id, title, description, status, priority, created_by, assigned_to, created_at |

---

### 13. SYSTEM & CONFIGURATION (4 tables)

| Table | Description | Key Fields |
|-------|-------------|------------|
| `ospos_app_config` | Application settings | key, value (company info, tax rates, receipt templates, date formats, etc.) |
| `ospos_sessions` | User session management | id, ip_address, timestamp, data |
| `ospos_contracts` | Contract management | contract_id, customer_id, start_date, end_date, terms, status |
| `ospos_password_reset_model` | Password reset OTP | reset_id, employee_id, otp, expires_at, used |

---

### 14. PHYSICAL INVENTORY (2 tables)

| Table | Description | Key Fields |
|-------|-------------|------------|
| `ospos_physical_counting` | Physical count records | count_id, location_id, employee_id, count_date, status |
| `ospos_physical_counting_items` | Count line items | id, count_id, item_id, system_quantity, counted_quantity, variance |

---

### 15. MULTI-SHOP SUPPORT (4 tables)

| Table | Description | Key Fields |
|-------|-------------|------------|
| `ospos_shop` | Shop/location definitions | shop_id, shop_name, address, phone |
| `ospos_shop_item` | Items per shop | shop_id, item_id, quantity, price |
| `ospos_shop_sale` | Sales per shop | shop_id, sale_id |
| `ospos_shop_receiving` | Receivings per shop | shop_id, receiving_id |

---

### 16. TARGETING & PERFORMANCE (3 tables)

| Table | Description | Key Fields |
|-------|-------------|------------|
| `ospos_customer_item_target_setup_model` | Customer item targets | target_id, customer_id, item_id, target_quantity, period |
| `ospos_salesman_item_target_model` | Salesman item targets | target_id, employee_id, item_id, target_quantity, period |
| `ospos_target` | General targeting | target_id, type, entity_id, target_value, actual_value, period |

---

### 17. TRA (TAX AUTHORITY) INTEGRATION (2 tables)

| Table | Description | Key Fields |
|-------|-------------|------------|
| `ospos_tra_sales_model` | Sales data for TRA | tra_id, sale_id, submission_date, status, response |
| `ospos_tra_purchases_model` | Purchase data for TRA | tra_id, receiving_id, submission_date, status, response |

---

### 18. TRANSACTIONS MODULE (New - Wakala/SIM/Cash/Bank) (6 tables)

| Table | Description | Key Fields |
|-------|-------------|------------|
| `ospos_cash_basis_categories` | Cash basis categories | category_id, category_name, type (income/expense) |
| `ospos_cash_basis_transactions` | Cash basis records | transaction_id, category_id, amount, date, description, employee_id, location_id |
| `ospos_bank_basis_categories` | Bank basis categories | category_id, category_name, type (income/expense) |
| `ospos_bank_basis_transactions` | Bank basis records | transaction_id, category_id, amount, date, description, employee_id, location_id |
| `ospos_sims` | SIM card inventory | sim_id, sim_number, network, status, location_id |
| `ospos_wakala_transactions` | Wakala transactions | wakala_id, sim_id, transaction_type, amount, float_before, float_after, date, employee_id |

---

## Implementation Phases

### Phase 1: Core Offline Sales (Priority)

| Feature | Description | Status |
|---------|-------------|--------|
| SQLite Database Setup | Local storage infrastructure | Pending |
| Database Schema (50+ tables) | Tables matching server structure | Pending |
| Offline Sales Creation | Create sales without internet | Pending |
| Local Item Cache | Items with stock quantities per location | Pending |
| Local Customer Cache | Customer data for credit sales | Pending |
| Sync Queue | Track pending transactions | Pending |
| Auto-Sync Engine | Sync when internet available | Pending |
| Offline Indicator UI | Show connection status | Pending |

### Phase 2: Full Offline Support

| Feature | Description | Status |
|---------|-------------|--------|
| Offline Receivings | Create stock receivings offline | Pending |
| Offline Expenses | Record expenses offline | Pending |
| Suspended Sales | Save/resume sales locally | Pending |
| Credit Payments | Record payments offline | Pending |
| Conflict Resolution | Handle sync conflicts | Pending |
| Batch Sync | Sync multiple records at once | Pending |

### Phase 3: Advanced Features

| Feature | Description | Status |
|---------|-------------|--------|
| Master Data Sync | Periodic sync of items/customers | Pending |
| Sync History Screen | View pending/failed syncs | Pending |
| Retry Failed Syncs | Manual retry option | Pending |
| One-Time Discounts Offline | Discount approval workflow | Pending |
| Quantity Offers Offline | Buy X Get Y offline | Pending |
| Customer Rewards/Points | Points tracking offline | Pending |
| Background Sync | Sync when app backgrounded | Pending |

---

## SQLite Schema (Mobile App)

### Priority Tables for Offline (Phase 1)

```sql
-- =====================================================
-- MASTER DATA TABLES (Synced from Server - Read Only)
-- =====================================================

-- People (Base for customers, employees, suppliers)
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
);

-- Customers
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
    last_synced_at TEXT,
    FOREIGN KEY (person_id) REFERENCES people(person_id)
);

-- Employees (cached for reference)
CREATE TABLE employees (
    person_id INTEGER PRIMARY KEY,
    username TEXT,
    language TEXT DEFAULT 'english',
    language_code TEXT DEFAULT 'en',
    deleted INTEGER DEFAULT 0,
    last_synced_at TEXT,
    FOREIGN KEY (person_id) REFERENCES people(person_id)
);

-- Suppliers
CREATE TABLE suppliers (
    person_id INTEGER PRIMARY KEY,
    company_name TEXT,
    agency_name TEXT,
    account_number TEXT,
    deleted INTEGER DEFAULT 0,
    last_synced_at TEXT,
    FOREIGN KEY (person_id) REFERENCES people(person_id)
);

-- Items
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
);

-- Item Quantities by Location
CREATE TABLE item_quantities (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    item_id INTEGER NOT NULL,
    location_id INTEGER NOT NULL,
    quantity REAL DEFAULT 0,
    last_synced_at TEXT,
    UNIQUE(item_id, location_id),
    FOREIGN KEY (item_id) REFERENCES items(item_id)
);

-- Item Taxes
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
);

-- Stock Locations
CREATE TABLE stock_locations (
    location_id INTEGER PRIMARY KEY,
    location_name TEXT NOT NULL,
    deleted INTEGER DEFAULT 0,
    last_synced_at TEXT
);

-- Expense Categories
CREATE TABLE expense_categories (
    expense_category_id INTEGER PRIMARY KEY,
    category_name TEXT NOT NULL,
    category_description TEXT,
    deleted INTEGER DEFAULT 0,
    last_synced_at TEXT
);

-- Tax Categories
CREATE TABLE tax_categories (
    tax_category_id INTEGER PRIMARY KEY,
    tax_category TEXT NOT NULL,
    tax_group_sequence INTEGER DEFAULT 0,
    deleted INTEGER DEFAULT 0,
    last_synced_at TEXT
);

-- Tax Codes
CREATE TABLE tax_codes (
    tax_code_id INTEGER PRIMARY KEY,
    tax_code TEXT,
    tax_code_name TEXT,
    city TEXT,
    state TEXT,
    deleted INTEGER DEFAULT 0,
    last_synced_at TEXT
);

-- =====================================================
-- TRANSACTIONAL TABLES (Created Locally, Synced to Server)
-- =====================================================

-- Sales
CREATE TABLE sales (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    server_sale_id INTEGER,  -- NULL until synced
    customer_id INTEGER,
    employee_id INTEGER NOT NULL,
    sale_time TEXT NOT NULL,
    invoice_number TEXT,
    quote_number TEXT,
    work_order_number TEXT,
    sale_status INTEGER DEFAULT 0,  -- 0=completed, 2=suspended
    sale_type INTEGER DEFAULT 0,    -- 0=POS, 1=Invoice, 2=Return
    dinner_table_id INTEGER,
    comment TEXT,
    subtotal REAL DEFAULT 0,
    tax_total REAL DEFAULT 0,
    total REAL DEFAULT 0,
    amount_tendered REAL DEFAULT 0,
    amount_change REAL DEFAULT 0,
    sync_status INTEGER DEFAULT 0,  -- 0=pending, 1=synced, 2=failed
    sync_error TEXT,
    sync_timestamp TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Sale Items
CREATE TABLE sale_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    sale_id INTEGER NOT NULL,
    item_id INTEGER NOT NULL,
    line INTEGER DEFAULT 0,
    quantity_purchased REAL NOT NULL,
    item_cost_price REAL DEFAULT 0,
    item_unit_price REAL NOT NULL,
    discount REAL DEFAULT 0,
    discount_type INTEGER DEFAULT 1,  -- 1=fixed
    discount_limit REAL DEFAULT 100,
    item_location INTEGER,
    print_option INTEGER DEFAULT 0,
    description TEXT,
    serialnumber TEXT,
    quantity_offer_id INTEGER,
    quantity_offer_free REAL DEFAULT 0,
    parent_line INTEGER,
    FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE
);

-- Sale Item Taxes
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
);

-- Sale Payments
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
);

-- Sale Taxes
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
);

-- Expenses
CREATE TABLE expenses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    server_expense_id INTEGER,  -- NULL until synced
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
);

-- Receivings
CREATE TABLE receivings (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    server_receiving_id INTEGER,  -- NULL until synced
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
);

-- Receiving Items
CREATE TABLE receiving_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    receiving_id INTEGER NOT NULL,
    item_id INTEGER NOT NULL,
    quantity_purchased REAL NOT NULL,
    item_cost_price REAL NOT NULL,
    discount_percent REAL DEFAULT 0,
    item_location INTEGER,
    serialnumber TEXT,
    line_total REAL DEFAULT 0,
    FOREIGN KEY (receiving_id) REFERENCES receivings(id) ON DELETE CASCADE
);

-- Banking
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
);

-- Customer Deposits/Withdrawals
CREATE TABLE customer_deposits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    server_deposit_id INTEGER,
    customer_id INTEGER NOT NULL,
    amount REAL NOT NULL,
    date TEXT NOT NULL,
    type TEXT NOT NULL,  -- 'deposit' or 'withdrawal'
    reference TEXT,
    comment TEXT,
    employee_id INTEGER NOT NULL,
    stock_location_id INTEGER,
    sync_status INTEGER DEFAULT 0,
    sync_error TEXT,
    sync_timestamp TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Debits Credits (Customer Balance Transactions)
CREATE TABLE debits_credits (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    server_id INTEGER,
    client_id INTEGER NOT NULL,
    payment_mode TEXT,
    payment_id INTEGER,
    balance REAL DEFAULT 0,
    dr REAL DEFAULT 0,
    delete INTEGER DEFAULT 0,
    date TEXT NOT NULL,
    employee_id INTEGER,
    stock_location_id INTEGER,
    sync_status INTEGER DEFAULT 0,
    sync_error TEXT,
    sync_timestamp TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- DISCOUNT & OFFER TABLES
-- =====================================================

-- One Time Discounts (Cached + Local Changes)
CREATE TABLE one_time_discounts (
    discount_id INTEGER PRIMARY KEY,
    document_number TEXT,
    requested_by INTEGER,
    customer_id INTEGER,
    item_id INTEGER,
    stock_location_id INTEGER,
    quantity REAL,
    discount_type INTEGER DEFAULT 1,  -- 1=fixed
    discount_amount REAL,
    reason TEXT,
    valid_date TEXT,
    status TEXT DEFAULT 'pending',  -- pending, approved, rejected, used
    used_at TEXT,
    used_sale_id INTEGER,
    approved_by INTEGER,
    expires_at TEXT,
    deleted_at TEXT,
    is_local INTEGER DEFAULT 0,  -- 1 if created locally
    sync_status INTEGER DEFAULT 1,  -- 1=synced for server data
    last_synced_at TEXT
);

-- Item Quantity Offers (Cached)
CREATE TABLE item_quantity_offers (
    offer_id INTEGER PRIMARY KEY,
    item_id INTEGER NOT NULL,
    stock_location_id INTEGER,
    buy_quantity REAL NOT NULL,
    reward_type TEXT,  -- 'free_item', 'discount_percent', 'fixed_discount'
    reward_item_id INTEGER,
    reward_quantity REAL DEFAULT 0,
    reward_discount_percent REAL DEFAULT 0,
    valid_from TEXT,
    valid_to TEXT,
    is_active INTEGER DEFAULT 1,
    last_synced_at TEXT
);

-- Offer Redemptions (Local + Synced)
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
);

-- =====================================================
-- REWARDS & POINTS
-- =====================================================

-- Customer Packages (Cached)
CREATE TABLE customers_packages (
    package_id INTEGER PRIMARY KEY,
    package_name TEXT NOT NULL,
    points_percent REAL DEFAULT 0,
    deleted INTEGER DEFAULT 0,
    last_synced_at TEXT
);

-- Customer Points (Local + Synced)
CREATE TABLE customers_points (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    server_id INTEGER,
    person_id INTEGER NOT NULL,
    package_id INTEGER,
    sale_id INTEGER,
    points_earned REAL DEFAULT 0,
    sync_status INTEGER DEFAULT 0,
    sync_timestamp TEXT
);

-- =====================================================
-- TRANSACTIONS MODULE (Wakala/SIM/Cash/Bank Basis)
-- =====================================================

-- Cash Basis Categories
CREATE TABLE cash_basis_categories (
    category_id INTEGER PRIMARY KEY,
    category_name TEXT NOT NULL,
    type TEXT,  -- 'income' or 'expense'
    last_synced_at TEXT
);

-- Cash Basis Transactions
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
);

-- Bank Basis Categories
CREATE TABLE bank_basis_categories (
    category_id INTEGER PRIMARY KEY,
    category_name TEXT NOT NULL,
    type TEXT,  -- 'income' or 'expense'
    last_synced_at TEXT
);

-- Bank Basis Transactions
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
);

-- SIMs
CREATE TABLE sims (
    sim_id INTEGER PRIMARY KEY,
    sim_number TEXT NOT NULL,
    network TEXT,
    status TEXT DEFAULT 'active',
    location_id INTEGER,
    last_synced_at TEXT
);

-- Wakala Transactions
CREATE TABLE wakala_transactions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    server_wakala_id INTEGER,
    sim_id INTEGER NOT NULL,
    transaction_type TEXT,  -- 'deposit', 'withdrawal', 'commission', etc.
    amount REAL NOT NULL,
    float_before REAL DEFAULT 0,
    float_after REAL DEFAULT 0,
    date TEXT NOT NULL,
    employee_id INTEGER,
    sync_status INTEGER DEFAULT 0,
    sync_error TEXT,
    sync_timestamp TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- Z-REPORTS & CASH SUBMISSIONS
-- =====================================================

-- Z-Reports
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
    comment TEXT,
    sync_status INTEGER DEFAULT 0,
    sync_error TEXT,
    sync_timestamp TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Cash Submissions
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
);

-- Profit Submissions
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
);

-- =====================================================
-- SYNC MANAGEMENT
-- =====================================================

-- Sync Queue
CREATE TABLE sync_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type TEXT NOT NULL,  -- 'sale', 'expense', 'receiving', 'customer_deposit', etc.
    entity_id INTEGER NOT NULL,
    action TEXT NOT NULL,       -- 'create', 'update', 'delete'
    payload TEXT,               -- JSON data for sync
    priority INTEGER DEFAULT 0, -- Higher = more urgent
    retry_count INTEGER DEFAULT 0,
    max_retries INTEGER DEFAULT 5,
    sync_status INTEGER DEFAULT 0,  -- 0=pending, 1=in_progress, 2=completed, 3=failed
    error_message TEXT,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    last_attempted_at TEXT
);

-- Sync Log
CREATE TABLE sync_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type TEXT NOT NULL,
    entity_id INTEGER,
    server_id INTEGER,
    action TEXT NOT NULL,
    status TEXT NOT NULL,  -- 'success', 'failed', 'conflict'
    message TEXT,
    synced_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- Last Sync Timestamps (for incremental sync)
CREATE TABLE sync_timestamps (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    entity_type TEXT NOT NULL UNIQUE,
    last_synced_at TEXT,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- APP CONFIGURATION
-- =====================================================

-- App Config (Cached from server)
CREATE TABLE app_config (
    key TEXT PRIMARY KEY,
    value TEXT,
    last_synced_at TEXT
);

-- User Session
CREATE TABLE user_session (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    username TEXT,
    first_name TEXT,
    last_name TEXT,
    token TEXT,
    location_id INTEGER,
    permissions TEXT,  -- JSON
    logged_in_at TEXT,
    client_id TEXT
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

CREATE INDEX idx_items_name ON items(name);
CREATE INDEX idx_items_category ON items(category);
CREATE INDEX idx_items_supplier ON items(supplier_id);
CREATE INDEX idx_item_quantities_location ON item_quantities(location_id);
CREATE INDEX idx_customers_phone ON people(phone_number);
CREATE INDEX idx_customers_name ON people(first_name, last_name);
CREATE INDEX idx_sales_sync_status ON sales(sync_status);
CREATE INDEX idx_sales_date ON sales(sale_time);
CREATE INDEX idx_sales_customer ON sales(customer_id);
CREATE INDEX idx_sales_employee ON sales(employee_id);
CREATE INDEX idx_sale_items_sale ON sale_items(sale_id);
CREATE INDEX idx_sale_items_item ON sale_items(item_id);
CREATE INDEX idx_expenses_sync_status ON expenses(sync_status);
CREATE INDEX idx_expenses_date ON expenses(date);
CREATE INDEX idx_receivings_sync_status ON receivings(sync_status);
CREATE INDEX idx_receivings_supplier ON receivings(supplier_id);
CREATE INDEX idx_sync_queue_status ON sync_queue(sync_status);
CREATE INDEX idx_sync_queue_entity ON sync_queue(entity_type, entity_id);
CREATE INDEX idx_one_time_discounts_customer ON one_time_discounts(customer_id);
CREATE INDEX idx_one_time_discounts_item ON one_time_discounts(item_id);
CREATE INDEX idx_debits_credits_client ON debits_credits(client_id);
```

---

## Table Count Summary

| Category | Server Tables | Mobile Tables |
|----------|---------------|---------------|
| People & Accounts | 6 | 4 |
| Items & Inventory | 10 | 4 |
| Suppliers & Receiving | 4 | 3 |
| Sales & Quotes | 6 | 5 |
| Expenses & Financial | 6 | 3 |
| Customer Finance | 6 | 3 |
| Gift Cards & Rewards | 4 | 2 |
| Discounts & Offers | 3 | 3 |
| Approval & Workflow | 5 | 0 (online only) |
| Roles & Permissions | 4 | 0 (cached as JSON) |
| Tax Configuration | 4 | 2 |
| Notification | 3 | 0 (online only) |
| System & Config | 4 | 2 |
| Physical Inventory | 2 | 0 (online only) |
| Multi-Shop | 4 | 0 (not needed) |
| Targeting | 3 | 0 (online only) |
| TRA Integration | 2 | 0 (online only) |
| Transactions Module | 6 | 6 |
| Z-Reports & Cash | 3 | 3 |
| Sync Management | 0 | 3 |
| **TOTAL** | **~85** | **~43** |

---

## Data Flow for Offline Mode

### Master Data Sync (Server → Mobile)

```
┌──────────────────────────────────────────────────────────────┐
│                    MASTER DATA SYNC                          │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  On First Login / Manual Refresh:                            │
│                                                              │
│  Server                              Mobile SQLite            │
│  ──────                              ────────────            │
│  ospos_items          ──────────►    items                   │
│  ospos_item_quantities ─────────►    item_quantities         │
│  ospos_customers      ──────────►    customers + people      │
│  ospos_suppliers      ──────────►    suppliers               │
│  ospos_stock_locations ─────────►    stock_locations         │
│  ospos_expense_category ────────►    expense_categories      │
│  ospos_one_time_discounts ──────►    one_time_discounts      │
│  ospos_item_quantity_offer ─────►    item_quantity_offers    │
│  ospos_cash_basis_categories ───►    cash_basis_categories   │
│  ospos_bank_basis_categories ───►    bank_basis_categories   │
│  ospos_sims           ──────────►    sims                    │
│                                                              │
│  Incremental Sync (after first load):                        │
│  - Use sync_timestamps table to track last sync              │
│  - Request only records modified since last sync             │
│  - API: GET /api/sync/items?since=2024-01-01T00:00:00       │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Transaction Sync (Mobile → Server)

```
┌──────────────────────────────────────────────────────────────┐
│                  TRANSACTION SYNC                            │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  When Online:                                                │
│                                                              │
│  Mobile SQLite                       Server                  │
│  ────────────                        ──────                  │
│  sales (sync_status=0) ─────────►    ospos_sales            │
│  sale_items           ─────────►     ospos_sales_items       │
│  sale_payments        ─────────►     ospos_sales_payments    │
│  expenses             ─────────►     ospos_expenses          │
│  receivings           ─────────►     ospos_receivings        │
│  banking              ─────────►     ospos_banking           │
│  customer_deposits    ─────────►     ospos_customer_deposits │
│  wakala_transactions  ─────────►     ospos_wakala_trans      │
│  zreports             ─────────►     ospos_zreports          │
│  cash_submissions     ─────────►     ospos_cash_submit       │
│                                                              │
│  After Successful Sync:                                      │
│  1. Update server_sale_id with returned ID                   │
│  2. Set sync_status = 1 (synced)                            │
│  3. Set sync_timestamp = current time                        │
│  4. Remove from sync_queue                                   │
│  5. Update item_quantities (reduce stock)                    │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## Client-Specific Data Isolation

```
Database Files:
├── pos_sada_offline.db          # SADA client data
├── pos_comeandsave_offline.db   # Come & Save client data
└── pos_leruma_offline.db        # Leruma client data

Each database is completely independent with:
- Own master data (items, customers, etc.)
- Own transactions (sales, expenses, etc.)
- Own sync queue and status
```

---

## Dependencies

```yaml
# pubspec.yaml additions

dependencies:
  # Database
  sqflite: ^2.3.0
  path: ^1.8.3

  # Network Monitoring
  connectivity_plus: ^5.0.2

  # UUID for local IDs
  uuid: ^4.2.1

  # Background Tasks (Phase 3)
  workmanager: ^0.5.2
```

---

## Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2024-12-23 | 0.1.0 | Initial planning document |
| 2024-12-23 | 0.2.0 | Updated with complete server database structure (50+ tables) |

---

## Notes

- Server has ~85 tables, mobile needs ~43 tables for full offline support
- Approval workflows remain online-only (require real-time approval)
- TRA integration remains online-only (requires government API)
- Physical inventory counting remains online-only
- Multi-shop features not needed (handled by stock_locations)
- Targeting/performance features remain online-only
