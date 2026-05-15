import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:phone_shop_pos/core/database/database_constants.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';

class MigrationService {
  const MigrationService();

  int get latestVersion => DatabaseConstants.databaseVersion;

  Future<void> onConfigure(Database database) async {
    await database.execute(DatabaseConstants.sqliteForeignKeysOn);
    await database.execute(DatabaseConstants.sqliteJournalModeWal);
  }

  Future<void> onCreate(Database database, int version) async {
    for (var currentVersion = 1; currentVersion <= version; currentVersion++) {
      await _applyMigration(database, currentVersion);
    }
  }

  Future<void> onUpgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    for (
      var currentVersion = oldVersion + 1;
      currentVersion <= newVersion;
      currentVersion++
    ) {
      await _applyMigration(database, currentVersion);
    }
  }

  Future<void> _applyMigration(Database database, int version) async {
    final statements = _migrationStatements[version];
    if (statements == null) {
      return;
    }
    for (final statement in statements) {
      await database.execute(statement);
    }
  }

  static const Map<int, List<String>> _migrationStatements = {
    1: <String>[
      '''
      CREATE TABLE ${TableNames.productModels} (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        brand TEXT,
        category TEXT,
        sku TEXT UNIQUE,
        purchase_price REAL NOT NULL DEFAULT 0,
        sale_price REAL NOT NULL DEFAULT 0,
        has_imei INTEGER NOT NULL CHECK (has_imei IN (0, 1)),
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
      ''',
      '''
      CREATE TABLE ${TableNames.inventoryStock} (
        id TEXT PRIMARY KEY NOT NULL,
        product_model_id TEXT NOT NULL UNIQUE,
        quantity INTEGER NOT NULL DEFAULT 0 CHECK (quantity >= 0),
        min_quantity INTEGER NOT NULL DEFAULT 0 CHECK (min_quantity >= 0),
        max_quantity INTEGER CHECK (max_quantity IS NULL OR max_quantity >= min_quantity),
        unit_cost REAL NOT NULL DEFAULT 0,
        unit_price REAL NOT NULL DEFAULT 0,
        location TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (product_model_id) REFERENCES ${TableNames.productModels}(id)
          ON UPDATE CASCADE
          ON DELETE RESTRICT
      );
      ''',
      '''
      CREATE TABLE ${TableNames.customers} (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
      ''',
      '''
      CREATE TABLE ${TableNames.suppliers} (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        contact_person TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
      ''',
      '''
      CREATE TABLE ${TableNames.users} (
        id TEXT PRIMARY KEY NOT NULL,
        username TEXT NOT NULL UNIQUE,
        full_name TEXT NOT NULL,
        password_hash TEXT,
        role TEXT NOT NULL DEFAULT 'cashier',
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        last_login_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
      ''',
      '''
      CREATE TABLE ${TableNames.serializedStock} (
        id TEXT PRIMARY KEY NOT NULL,
        product_model_id TEXT NOT NULL,
        imei1 TEXT NOT NULL UNIQUE,
        imei2 TEXT,
        serial_number TEXT,
        cost_price REAL NOT NULL DEFAULT 0,
        selling_price REAL,
        stock_status TEXT NOT NULL CHECK (
          stock_status IN ('in_stock', 'sold', 'reserved', 'returned', 'damaged')
        ),
        supplier_id TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (product_model_id) REFERENCES ${TableNames.productModels}(id)
          ON UPDATE CASCADE
          ON DELETE RESTRICT,
        FOREIGN KEY (supplier_id) REFERENCES ${TableNames.suppliers}(id)
          ON UPDATE CASCADE
          ON DELETE SET NULL
      );
      ''',
      '''
      CREATE TABLE ${TableNames.sales} (
        id TEXT PRIMARY KEY NOT NULL,
        invoice_number TEXT NOT NULL UNIQUE,
        customer_id TEXT,
        user_id TEXT,
        sale_date TEXT NOT NULL,
        subtotal REAL NOT NULL DEFAULT 0,
        discount REAL NOT NULL DEFAULT 0,
        tax REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        paid_amount REAL NOT NULL DEFAULT 0,
        payment_method TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES ${TableNames.customers}(id)
          ON UPDATE CASCADE
          ON DELETE SET NULL,
        FOREIGN KEY (user_id) REFERENCES ${TableNames.users}(id)
          ON UPDATE CASCADE
          ON DELETE SET NULL
      );
      ''',
      '''
      CREATE TABLE ${TableNames.saleItems} (
        id TEXT PRIMARY KEY NOT NULL,
        sale_id TEXT NOT NULL,
        product_model_id TEXT NOT NULL,
        serialized_stock_id TEXT,
        quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
        unit_price REAL NOT NULL DEFAULT 0,
        discount REAL NOT NULL DEFAULT 0,
        line_total REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES ${TableNames.sales}(id)
          ON UPDATE CASCADE
          ON DELETE CASCADE,
        FOREIGN KEY (product_model_id) REFERENCES ${TableNames.productModels}(id)
          ON UPDATE CASCADE
          ON DELETE RESTRICT,
        FOREIGN KEY (serialized_stock_id) REFERENCES ${TableNames.serializedStock}(id)
          ON UPDATE CASCADE
          ON DELETE SET NULL
      );
      ''',
      '''
      CREATE TABLE ${TableNames.purchases} (
        id TEXT PRIMARY KEY NOT NULL,
        supplier_id TEXT,
        invoice_number TEXT,
        purchase_date TEXT NOT NULL,
        subtotal REAL NOT NULL DEFAULT 0,
        discount REAL NOT NULL DEFAULT 0,
        tax REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,
        paid_amount REAL NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES ${TableNames.suppliers}(id)
          ON UPDATE CASCADE
          ON DELETE SET NULL
      );
      ''',
      '''
      CREATE TABLE ${TableNames.purchaseItems} (
        id TEXT PRIMARY KEY NOT NULL,
        purchase_id TEXT NOT NULL,
        product_model_id TEXT NOT NULL,
        serialized_stock_id TEXT,
        quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
        unit_cost REAL NOT NULL DEFAULT 0,
        line_total REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (purchase_id) REFERENCES ${TableNames.purchases}(id)
          ON UPDATE CASCADE
          ON DELETE CASCADE,
        FOREIGN KEY (product_model_id) REFERENCES ${TableNames.productModels}(id)
          ON UPDATE CASCADE
          ON DELETE RESTRICT,
        FOREIGN KEY (serialized_stock_id) REFERENCES ${TableNames.serializedStock}(id)
          ON UPDATE CASCADE
          ON DELETE SET NULL
      );
      ''',
      '''
      CREATE TABLE ${TableNames.expenses} (
        id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        category TEXT,
        amount REAL NOT NULL DEFAULT 0,
        expense_date TEXT NOT NULL,
        supplier_id TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES ${TableNames.suppliers}(id)
          ON UPDATE CASCADE
          ON DELETE SET NULL
      );
      ''',
      'CREATE INDEX idx_product_models_name ON ${TableNames.productModels}(name);',
      'CREATE INDEX idx_product_models_has_imei ON ${TableNames.productModels}(has_imei);',
      'CREATE INDEX idx_serialized_stock_imei1 ON ${TableNames.serializedStock}(imei1);',
      'CREATE INDEX idx_serialized_stock_imei2 ON ${TableNames.serializedStock}(imei2);',
      'CREATE INDEX idx_serialized_stock_status ON ${TableNames.serializedStock}(stock_status);',
      'CREATE INDEX idx_serialized_stock_product_status ON ${TableNames.serializedStock}(product_model_id, stock_status);',
      'CREATE INDEX idx_inventory_stock_product ON ${TableNames.inventoryStock}(product_model_id);',
      'CREATE INDEX idx_customers_phone ON ${TableNames.customers}(phone);',
      'CREATE INDEX idx_suppliers_phone ON ${TableNames.suppliers}(phone);',
      'CREATE INDEX idx_sales_sale_date ON ${TableNames.sales}(sale_date);',
      'CREATE INDEX idx_sales_invoice_number ON ${TableNames.sales}(invoice_number);',
      'CREATE INDEX idx_sale_items_sale_id ON ${TableNames.saleItems}(sale_id);',
      'CREATE INDEX idx_purchases_purchase_date ON ${TableNames.purchases}(purchase_date);',
      'CREATE INDEX idx_purchase_items_purchase_id ON ${TableNames.purchaseItems}(purchase_id);',
    ],

    // ── v2: financial snapshot, invoice sequences, IMEI integrity, perf ──
    2: <String>[
      // Phase 3: cost_price snapshot — existing rows default to 0 (historical
      // data will show zero cost; acceptable trade-off for migration safety).
      '''
      ALTER TABLE ${TableNames.saleItems}
        ADD COLUMN cost_price REAL NOT NULL DEFAULT 0;
      ''',

      // Phase 4: atomic invoice number generation — avoids COUNT-based races.
      '''
      CREATE TABLE ${TableNames.invoiceSequences} (
        date_key TEXT PRIMARY KEY NOT NULL,
        last_seq INTEGER NOT NULL DEFAULT 0
      );
      ''',

      // Phase 7: performance indexes missing from v1.
      'CREATE INDEX IF NOT EXISTS idx_sale_items_product_model_id ON ${TableNames.saleItems}(product_model_id);',
      'CREATE INDEX IF NOT EXISTS idx_sale_items_serialized_stock_id ON ${TableNames.saleItems}(serialized_stock_id);',
      'CREATE INDEX IF NOT EXISTS idx_sales_created_at ON ${TableNames.sales}(created_at);',
      'CREATE INDEX IF NOT EXISTS idx_purchases_created_at ON ${TableNames.purchases}(created_at);',
    ],

    // ── v3: report/search scale indexes for long-running desktop usage ──
    3: <String>[
      'CREATE INDEX IF NOT EXISTS idx_sales_customer_sale_date ON ${TableNames.sales}(customer_id, sale_date);',
      'CREATE INDEX IF NOT EXISTS idx_sales_payment_method_sale_date ON ${TableNames.sales}(payment_method, sale_date);',
      'CREATE INDEX IF NOT EXISTS idx_sale_items_sale_product ON ${TableNames.saleItems}(sale_id, product_model_id);',
      'CREATE INDEX IF NOT EXISTS idx_customers_name ON ${TableNames.customers}(name);',
      'CREATE INDEX IF NOT EXISTS idx_product_models_sku ON ${TableNames.productModels}(sku);',
      'CREATE INDEX IF NOT EXISTS idx_product_models_brand ON ${TableNames.productModels}(brand);',
      'CREATE INDEX IF NOT EXISTS idx_serialized_stock_serial_number ON ${TableNames.serializedStock}(serial_number);',
      'CREATE INDEX IF NOT EXISTS idx_serialized_stock_product_status_created ON ${TableNames.serializedStock}(product_model_id, stock_status, created_at);',
    ],
  };
}
