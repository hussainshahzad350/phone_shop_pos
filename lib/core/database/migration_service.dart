import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/database/database_constants.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';

class MigrationService {
  const MigrationService();

  int get latestVersion => DatabaseConstants.databaseVersion;

  Future<void> onConfigure(Database database) async {
    await database.execute(DatabaseConstants.sqliteForeignKeysOn);
    await database.execute(DatabaseConstants.sqliteJournalModeWal);
    await database.execute(
      'PRAGMA busy_timeout = ${DatabaseConstants.sqliteBusyTimeoutMs};',
    );
  }

  Future<void> onCreate(Database database, int version) async {
    for (var currentVersion = 1; currentVersion <= version; currentVersion++) {
      // v9, v12 and v13 are transitional table-rewrite migrations for
      // existing databases. Fresh installs already use the latest sales
      // schema.
      if (currentVersion == 9 ||
          ((currentVersion == 12 || currentVersion == 13) &&
              version == latestVersion)) {
        continue;
      }
      await _applyMigration(database, currentVersion);
    }

    if (version == latestVersion && version >= 12) {
      await _applyFreshInstallSalesChecks(database);
    }
  }

  Future<void> onUpgrade(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    for (var currentVersion = oldVersion + 1;
        currentVersion <= newVersion;
        currentVersion++) {
      await _applyMigration(database, currentVersion);
    }
  }

  Future<void> _applyMigration(Database database, int version) async {
    // Migration for customer ledger table schema upgrade (master data alignment)
    if (version == 22) {
      // 1. Rename old table
      await database.execute(
          'ALTER TABLE ${TableNames.customerLedger} RENAME TO ${TableNames.customerLedger}_old;');
      // 2. Create new table with updated schema
      await database.execute('''
            CREATE TABLE ${TableNames.customerLedger} (
              id TEXT PRIMARY KEY NOT NULL,
              party_id TEXT NOT NULL,
              transaction_id TEXT NOT NULL,
              ledger_type TEXT NOT NULL,
              amount REAL NOT NULL CHECK (amount >= 0),
              direction TEXT NOT NULL CHECK (direction IN ('debit', 'credit')),
              note TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              created_by TEXT,
              is_reversal INTEGER NOT NULL DEFAULT 0 CHECK (is_reversal IN (0, 1)),
              reversal_of TEXT,
              payment_method TEXT,
              FOREIGN KEY (party_id) REFERENCES ${TableNames.customers}(id)
                ON UPDATE CASCADE
                ON DELETE RESTRICT
            );
          ''');
      // 3. Copy data from old table (set updated_at = created_at for existing rows)
      await database.execute('''
            INSERT INTO ${TableNames.customerLedger} (
              id, party_id, transaction_id, ledger_type, amount, direction, note, created_at, updated_at, created_by, is_reversal, reversal_of, payment_method
            )
            SELECT
              id, party_id, transaction_id, ledger_type, amount, direction, note, created_at, created_at as updated_at, created_by, is_reversal, reversal_of, payment_method
            FROM ${TableNames.customerLedger}_old;
          ''');
      // 4. Restore indexes
      await database.execute(
          'CREATE INDEX IF NOT EXISTS idx_customer_ledger_party_id ON ${TableNames.customerLedger}(party_id);');
      await database.execute(
          'CREATE INDEX IF NOT EXISTS idx_customer_ledger_transaction_id ON ${TableNames.customerLedger}(transaction_id);');
      await database.execute(
          'CREATE INDEX IF NOT EXISTS idx_customer_ledger_created_at ON ${TableNames.customerLedger}(created_at);');
      await database.execute(
          'CREATE INDEX IF NOT EXISTS idx_customer_ledger_type ON ${TableNames.customerLedger}(ledger_type);');
      await database.execute(
          'CREATE INDEX IF NOT EXISTS idx_customer_ledger_reversal_of ON ${TableNames.customerLedger}(reversal_of);');
      // 5. Drop old table
      await database.execute('DROP TABLE ${TableNames.customerLedger}_old;');
    }
    if (version == 7) {
      await _applyMigrationV7(database);
      return;
    }
    if (version == 9) {
      await _applyMigrationV9(database);
      return;
    }
    if (version == 12) {
      await _applyMigrationV12(database);
      return;
    }
    if (version == 13) {
      await _applyMigrationV12(database);
      return;
    }
    if (version == 14) {
      await _applyMigrationV14(database);
      return;
    }
    if (version == 15) {
      await _applyMigrationV15(database);
      return;
    }
    if (version == 17) {
      await _applyMigrationV17(database);
      return;
    }
    if (version == 18) {
      await _applyMigrationV18(database);
      return;
    }
    if (version == 21) {
      await _applyMigrationV21(database);
      return;
    }
    if (version == 23) {
      await _applyMigrationV23(database);
      return;
    }
    if (version == 24) {
      await _applyMigrationV24(database);
      return;
    }
    final statements = _migrationStatements[version];
    if (statements == null) {
      return;
    }
    for (final statement in statements) {
      await database.execute(statement);
    }
  }

  Future<void> _applyMigrationV7(Database database) async {
    final duplicateRows = await database.rawQuery('''
      SELECT imei2, COUNT(*) AS duplicate_count
      FROM ${TableNames.serializedStock}
      WHERE imei2 IS NOT NULL
      GROUP BY imei2
      HAVING COUNT(*) > 1
      ORDER BY duplicate_count DESC, imei2 ASC
      LIMIT 5
    ''');

    if (duplicateRows.isNotEmpty) {
      final examples = duplicateRows
          .map(
            (row) =>
                '${row['imei2']} (${(row['duplicate_count'] as num?)?.toInt() ?? 0}x)',
          )
          .join(', ');
      throw StateError(
        'Migration v7 blocked: duplicate non-null serialized_stock.imei2 values found ($examples). Resolve duplicates before upgrading.',
      );
    }

    await database.execute(
      '''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_serialized_stock_imei2_unique
      ON ${TableNames.serializedStock}(imei2)
      WHERE imei2 IS NOT NULL;
      ''',
    );
  }

  Future<void> _applyMigrationV9(Database database) async {
    await database.execute(
      '''
      UPDATE ${TableNames.sales}
      SET payment_method = '${PaymentMethod.bank}'
      WHERE payment_method = 'bank_transfer'
      ''',
    );
    await database.execute(
      '''
      UPDATE ${TableNames.sales}
      SET payment_method = NULL
      WHERE payment_method IS NOT NULL
        AND payment_method NOT IN (
          '${PaymentMethod.cash}',
          '${PaymentMethod.card}',
          '${PaymentMethod.bank}',
          '${PaymentMethod.credit}'
        )
      ''',
    );

    // SQLite requires foreign keys to be disabled while the sales table is
    // renamed and recreated, otherwise the schema change is rejected.
    await database.execute('PRAGMA foreign_keys = OFF;');
    await database.execute('PRAGMA legacy_alter_table = ON;');
    try {
      await database.execute(
        'ALTER TABLE ${TableNames.sales} RENAME TO ${TableNames.sales}_old;',
      );
      await database.execute(
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
          payment_method TEXT CHECK (
            payment_method IS NULL OR payment_method IN (
              '${PaymentMethod.cash}',
              '${PaymentMethod.card}',
              '${PaymentMethod.bank}',
              '${PaymentMethod.credit}'
            )
          ),
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
      );
      await database.execute(
        '''
        INSERT INTO ${TableNames.sales} (
          id,
          invoice_number,
          customer_id,
          user_id,
          sale_date,
          subtotal,
          discount,
          tax,
          total,
          paid_amount,
          payment_method,
          notes,
          created_at,
          updated_at
        )
        SELECT
          id,
          invoice_number,
          customer_id,
          user_id,
          sale_date,
          subtotal,
          discount,
          tax,
          total,
          paid_amount,
          payment_method,
          notes,
          created_at,
          updated_at
        FROM ${TableNames.sales}_old;
        ''',
      );
      await database.execute('DROP TABLE ${TableNames.sales}_old;');
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_sale_date ON ${TableNames.sales}(sale_date);',
      );
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_invoice_number ON ${TableNames.sales}(invoice_number);',
      );
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_customer_sale_date ON ${TableNames.sales}(customer_id, sale_date);',
      );
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_payment_method_sale_date ON ${TableNames.sales}(payment_method, sale_date);',
      );
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_pending_balance ON ${TableNames.sales}(total, paid_amount);',
      );
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_created_at ON ${TableNames.sales}(created_at);',
      );
    } finally {
      await database.execute('PRAGMA legacy_alter_table = OFF;');
      await database.execute('PRAGMA foreign_keys = ON;');
    }
  }

  // ── v12: strict financial CHECK constraints on the sales table ───────────
  // Enforces: subtotal >= 0, discount >= 0, tax >= 0, total >= 0,
  //           paid_amount >= 0, and paid_amount <= total at the DB level.
  // Any legacy rows that violate these invariants are silently clamped
  // during the INSERT … SELECT so that the upgrade never blocks.
  Future<void> _applyMigrationV12(Database database) async {
    await database.execute('PRAGMA foreign_keys = OFF;');
    await database.execute('PRAGMA legacy_alter_table = ON;');
    try {
      await database.execute(
        'ALTER TABLE ${TableNames.sales} RENAME TO ${TableNames.sales}_old;',
      );
      await database.execute(
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
          payment_method TEXT CHECK (
            payment_method IS NULL OR payment_method IN (
              '${PaymentMethod.cash}',
              '${PaymentMethod.card}',
              '${PaymentMethod.bank}',
              '${PaymentMethod.credit}'
            )
          ),
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (customer_id) REFERENCES ${TableNames.customers}(id)
            ON UPDATE CASCADE
            ON DELETE SET NULL,
          FOREIGN KEY (user_id) REFERENCES ${TableNames.users}(id)
            ON UPDATE CASCADE
            ON DELETE SET NULL,
          CHECK (subtotal >= 0),
          CHECK (discount >= 0),
          CHECK (tax >= 0),
          CHECK (total >= 0),
          CHECK (paid_amount >= 0),
          CHECK (paid_amount <= total)
        );
        ''',
      );
      // Migrate existing rows; clamp any values that violate the new
      // constraints so the upgrade never fails on corrupted legacy data.
      await database.execute(
        '''
        INSERT INTO ${TableNames.sales} (
          id,
          invoice_number,
          customer_id,
          user_id,
          sale_date,
          subtotal,
          discount,
          tax,
          total,
          paid_amount,
          payment_method,
          notes,
          created_at,
          updated_at
        )
        SELECT
          id,
          invoice_number,
          customer_id,
          user_id,
          sale_date,
          MAX(0.0, subtotal),
          MAX(0.0, discount),
          MAX(0.0, tax),
          MAX(0.0, total),
          MAX(0.0, MIN(paid_amount, MAX(0.0, total))),
          payment_method,
          notes,
          created_at,
          updated_at
        FROM ${TableNames.sales}_old;
        ''',
      );
      await database.execute('DROP TABLE ${TableNames.sales}_old;');
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_sale_date ON ${TableNames.sales}(sale_date);',
      );
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_invoice_number ON ${TableNames.sales}(invoice_number);',
      );
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_customer_sale_date ON ${TableNames.sales}(customer_id, sale_date);',
      );
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_payment_method_sale_date ON ${TableNames.sales}(payment_method, sale_date);',
      );
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_pending_balance ON ${TableNames.sales}(total, paid_amount);',
      );
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_created_at ON ${TableNames.sales}(created_at);',
      );
    } finally {
      await database.execute('PRAGMA legacy_alter_table = OFF;');
      await database.execute('PRAGMA foreign_keys = ON;');
    }
  }

  Future<void> _applyFreshInstallSalesChecks(Database database) async {
    await database.execute('PRAGMA foreign_keys = OFF;');
    try {
      await database.execute('DROP TABLE IF EXISTS ${TableNames.sales};');
      await database.execute(
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
          payment_method TEXT CHECK (
            payment_method IS NULL OR payment_method IN (
              '${PaymentMethod.cash}',
              '${PaymentMethod.card}',
              '${PaymentMethod.bank}',
              '${PaymentMethod.credit}'
            )
          ),
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (customer_id) REFERENCES ${TableNames.customers}(id)
            ON UPDATE CASCADE
            ON DELETE SET NULL,
          FOREIGN KEY (user_id) REFERENCES ${TableNames.users}(id)
            ON UPDATE CASCADE
            ON DELETE SET NULL,
          CHECK (subtotal >= 0),
          CHECK (discount >= 0),
          CHECK (tax >= 0),
          CHECK (total >= 0),
          CHECK (paid_amount >= 0),
          CHECK (paid_amount <= total)
        );
        ''',
      );
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_sale_date ON ${TableNames.sales}(sale_date);',
      );
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_invoice_number ON ${TableNames.sales}(invoice_number);',
      );
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_customer_sale_date ON ${TableNames.sales}(customer_id, sale_date);',
      );
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_payment_method_sale_date ON ${TableNames.sales}(payment_method, sale_date);',
      );
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_pending_balance ON ${TableNames.sales}(total, paid_amount);',
      );
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_sales_created_at ON ${TableNames.sales}(created_at);',
      );
    } finally {
      await database.execute('PRAGMA foreign_keys = ON;');
    }
  }

  Future<void> _applyMigrationV14(Database database) async {
    await _repairSalesOldForeignKeyReferences(database);
  }

  Future<void> _repairSalesOldForeignKeyReferences(Database database) async {
    await database.execute('PRAGMA foreign_keys = OFF;');
    try {
      const legacySalesParent = '${TableNames.sales}_old';

      if (await _tableReferencesParent(
        database,
        tableName: TableNames.saleItems,
        parentTableName: legacySalesParent,
      )) {
        await _rebuildSaleItemsTable(database);
      }

      if (await _tableReferencesParent(
        database,
        tableName: TableNames.salePayments,
        parentTableName: legacySalesParent,
      )) {
        await _rebuildSalePaymentsTable(database);
      }

      if (await _tableReferencesParent(
        database,
        tableName: TableNames.saleReturns,
        parentTableName: legacySalesParent,
      )) {
        await _rebuildSaleReturnsTable(database);
      }
    } finally {
      await database.execute('PRAGMA foreign_keys = ON;');
    }
  }

  Future<bool> _tableReferencesParent(
    Database database, {
    required String tableName,
    required String parentTableName,
  }) async {
    final rows =
        await database.rawQuery('PRAGMA foreign_key_list($tableName);');
    for (final row in rows) {
      final referencedTable = (row['table'] as String?)?.trim();
      if (referencedTable == parentTableName) {
        return true;
      }
    }
    return false;
  }

  Future<void> _rebuildSaleItemsTable(Database database) async {
    await database.execute(
      'ALTER TABLE ${TableNames.saleItems} RENAME TO ${TableNames.saleItems}_old;',
    );
    await database.execute(
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
        cost_price REAL NOT NULL DEFAULT 0,
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
    );
    await database.execute(
      '''
      INSERT INTO ${TableNames.saleItems} (
        id,
        sale_id,
        product_model_id,
        serialized_stock_id,
        quantity,
        unit_price,
        discount,
        line_total,
        cost_price,
        created_at,
        updated_at
      )
      SELECT
        id,
        sale_id,
        product_model_id,
        serialized_stock_id,
        quantity,
        unit_price,
        discount,
        line_total,
        cost_price,
        created_at,
        updated_at
      FROM ${TableNames.saleItems}_old;
      ''',
    );
    await _dropTableBestEffort(database, '${TableNames.saleItems}_old');
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_sale_items_sale_id ON ${TableNames.saleItems}(sale_id);',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_sale_items_product_model_id ON ${TableNames.saleItems}(product_model_id);',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_sale_items_serialized_stock_id ON ${TableNames.saleItems}(serialized_stock_id);',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_sale_items_sale_product ON ${TableNames.saleItems}(sale_id, product_model_id);',
    );
  }

  Future<void> _rebuildSalePaymentsTable(Database database) async {
    await database.execute(
      'ALTER TABLE ${TableNames.salePayments} RENAME TO ${TableNames.salePayments}_old;',
    );
    await database.execute(
      '''
      CREATE TABLE ${TableNames.salePayments} (
        id TEXT PRIMARY KEY NOT NULL,
        sale_id TEXT NOT NULL,
        amount REAL NOT NULL CHECK (amount > 0),
        payment_method TEXT NOT NULL CHECK (
          payment_method IN (
            '${PaymentMethod.cash}',
            '${PaymentMethod.card}',
            '${PaymentMethod.bank}'
          )
        ),
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES ${TableNames.sales}(id)
          ON UPDATE CASCADE
          ON DELETE CASCADE
      );
      ''',
    );
    await database.execute(
      '''
      INSERT INTO ${TableNames.salePayments} (
        id,
        sale_id,
        amount,
        payment_method,
        notes,
        created_at,
        updated_at
      )
      SELECT
        id,
        sale_id,
        amount,
        payment_method,
        notes,
        created_at,
        updated_at
      FROM ${TableNames.salePayments}_old;
      ''',
    );
    await _dropTableBestEffort(database, '${TableNames.salePayments}_old');
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_sale_payments_sale_created ON ${TableNames.salePayments}(sale_id, created_at DESC);',
    );
  }

  Future<void> _rebuildSaleReturnsTable(Database database) async {
    await database.execute(
      'ALTER TABLE ${TableNames.saleReturns} RENAME TO ${TableNames.saleReturns}_old;',
    );
    await database.execute(
      '''
      CREATE TABLE ${TableNames.saleReturns} (
        id TEXT PRIMARY KEY NOT NULL,
        sale_id TEXT NOT NULL,
        sale_item_id TEXT NOT NULL,
        product_model_id TEXT NOT NULL,
        serialized_stock_id TEXT,
        return_type TEXT NOT NULL CHECK (return_type IN ('imei', 'quantity')),
        return_qty INTEGER NOT NULL CHECK (return_qty > 0),
        return_amount REAL NOT NULL DEFAULT 0,
        reason TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        cost_price REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (sale_id) REFERENCES ${TableNames.sales}(id)
          ON UPDATE CASCADE
          ON DELETE CASCADE,
        FOREIGN KEY (sale_item_id) REFERENCES ${TableNames.saleItems}(id)
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
    );
    await database.execute(
      '''
      INSERT INTO ${TableNames.saleReturns} (
        id,
        sale_id,
        sale_item_id,
        product_model_id,
        serialized_stock_id,
        return_type,
        return_qty,
        return_amount,
        reason,
        notes,
        created_at,
        updated_at,
        cost_price
      )
      SELECT
        id,
        sale_id,
        sale_item_id,
        product_model_id,
        serialized_stock_id,
        return_type,
        return_qty,
        return_amount,
        reason,
        notes,
        created_at,
        updated_at,
        cost_price
      FROM ${TableNames.saleReturns}_old;
      ''',
    );
    await _dropTableBestEffort(database, '${TableNames.saleReturns}_old');
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_sale_returns_sale_item ON ${TableNames.saleReturns}(sale_id, sale_item_id);',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_sale_returns_serialized ON ${TableNames.saleReturns}(serialized_stock_id);',
    );
  }

  /// Migration v15: add used-phone tracking columns to serialized_stock.
  /// `condition` is NOT NULL DEFAULT 'new'; all seller/condition detail columns
  /// are nullable so existing rows remain valid without any backfill.
  Future<void> _applyMigrationV15(Database database) async {
    await database.execute(
      "ALTER TABLE ${TableNames.serializedStock} ADD COLUMN condition TEXT NOT NULL DEFAULT 'new' CHECK (condition IN ('new', 'used'));",
    );
    await database.execute(
      'ALTER TABLE ${TableNames.serializedStock} ADD COLUMN seller_name TEXT;',
    );
    await database.execute(
      'ALTER TABLE ${TableNames.serializedStock} ADD COLUMN seller_id_card TEXT;',
    );
    await database.execute(
      'ALTER TABLE ${TableNames.serializedStock} ADD COLUMN seller_address TEXT;',
    );
    await database.execute(
      'ALTER TABLE ${TableNames.serializedStock} ADD COLUMN remaining_warranty TEXT;',
    );
    await database.execute(
      'ALTER TABLE ${TableNames.serializedStock} ADD COLUMN accessories TEXT;',
    );
    await database.execute(
      'ALTER TABLE ${TableNames.serializedStock} ADD COLUMN phone_condition_notes TEXT;',
    );
  }

  /// Migration v17: normalize expenses schema for reports-driven expense
  /// tracking with soft-delete support and category/date indexing.
  Future<void> _applyMigrationV17(Database database) async {
    const defaultExpenseCategory = 'General';
    await database.execute('PRAGMA foreign_keys = OFF;');
    await database.execute('PRAGMA legacy_alter_table = ON;');
    try {
      await database.execute(
        'ALTER TABLE ${TableNames.expenses} RENAME TO ${TableNames.expenses}_old;',
      );
      await database.execute(
        '''
        CREATE TABLE ${TableNames.expenses} (
          id TEXT PRIMARY KEY,
          expense_date TEXT NOT NULL,
          category TEXT NOT NULL,
          amount REAL NOT NULL CHECK(amount >= 0),
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          is_deleted INTEGER NOT NULL DEFAULT 0
        );
        ''',
      );
      await database.execute(
        '''
        INSERT INTO ${TableNames.expenses} (
          id,
          expense_date,
          category,
          amount,
          notes,
          created_at,
          updated_at,
          is_deleted
        )
        SELECT
          id,
          expense_date,
          COALESCE(
            NULLIF(TRIM(category), ''),
            NULLIF(TRIM(title), ''),
            '$defaultExpenseCategory'
          ),
          MAX(0.0, amount),
          notes,
          created_at,
          NULLIF(updated_at, ''),
          0
        FROM ${TableNames.expenses}_old;
        ''',
      );
      await _dropTableBestEffort(database, '${TableNames.expenses}_old');
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_date ON ${TableNames.expenses}(expense_date);',
      );
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_category ON ${TableNames.expenses}(category);',
      );
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_deleted ON ${TableNames.expenses}(is_deleted);',
      );
    } finally {
      await database.execute('PRAGMA legacy_alter_table = OFF;');
      await database.execute('PRAGMA foreign_keys = ON;');
    }
  }

  Future<void> _applyMigrationV18(Database database) async {
    await database.execute(
      '''
      CREATE TABLE IF NOT EXISTS ${TableNames.repairJobs} (
        id TEXT PRIMARY KEY,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        repair_date TEXT NOT NULL,
        customer_name TEXT,
        customer_phone TEXT,
        phone_model TEXT NOT NULL,
        imei TEXT,
        problem_description TEXT NOT NULL,
        accessories TEXT,
        technician_name TEXT,
        estimated_cost REAL,
        advance_received REAL NOT NULL DEFAULT 0,
        final_cost REAL,
        repair_expense REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL CHECK(
          status IN (
            'received',
            'diagnosing',
            'repairing',
            'ready',
            'delivered',
            'cancelled'
          )
        ),
        notes TEXT,
        is_deleted INTEGER NOT NULL DEFAULT 0
      );
      ''',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_repair_jobs_date ON ${TableNames.repairJobs}(repair_date);',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_repair_jobs_status ON ${TableNames.repairJobs}(status);',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_repair_jobs_deleted ON ${TableNames.repairJobs}(is_deleted);',
    );
  }

  Future<void> _applyMigrationV21(Database database) async {
    await _createLedgerTables(database);
    await _createSettlementSupportTables(database);
    await _backfillCustomerLedger(database);
    await _backfillSupplierLedger(database);
  }

  Future<void> _createLedgerTables(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS ${TableNames.customerLedger} (
        id TEXT PRIMARY KEY NOT NULL,
        party_id TEXT NOT NULL,
        transaction_id TEXT NOT NULL,
        ledger_type TEXT NOT NULL,
        amount REAL NOT NULL CHECK (amount >= 0),
        direction TEXT NOT NULL CHECK (direction IN ('debit', 'credit')),
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        created_by TEXT,
        is_reversal INTEGER NOT NULL DEFAULT 0 CHECK (is_reversal IN (0, 1)),
        reversal_of TEXT,
        payment_method TEXT,
        FOREIGN KEY (party_id) REFERENCES ${TableNames.customers}(id)
          ON UPDATE CASCADE
          ON DELETE RESTRICT
      );
      ''');
    await database.execute(
      '''
      CREATE TABLE IF NOT EXISTS ${TableNames.supplierLedger} (
        id TEXT PRIMARY KEY NOT NULL,
        party_id TEXT NOT NULL,
        transaction_id TEXT NOT NULL,
        ledger_type TEXT NOT NULL,
        amount REAL NOT NULL CHECK (amount >= 0),
        direction TEXT NOT NULL CHECK (direction IN ('debit', 'credit')),
        note TEXT,
        created_at TEXT NOT NULL,
        created_by TEXT,
        is_reversal INTEGER NOT NULL DEFAULT 0 CHECK (is_reversal IN (0, 1)),
        reversal_of TEXT,
        payment_method TEXT
      );
      ''',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_customer_ledger_party_id ON ${TableNames.customerLedger}(party_id);',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_customer_ledger_transaction_id ON ${TableNames.customerLedger}(transaction_id);',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_customer_ledger_created_at ON ${TableNames.customerLedger}(created_at);',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_customer_ledger_type ON ${TableNames.customerLedger}(ledger_type);',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_customer_ledger_reversal_of ON ${TableNames.customerLedger}(reversal_of);',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_supplier_ledger_party_id ON ${TableNames.supplierLedger}(party_id);',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_supplier_ledger_transaction_id ON ${TableNames.supplierLedger}(transaction_id);',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_supplier_ledger_created_at ON ${TableNames.supplierLedger}(created_at);',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_supplier_ledger_type ON ${TableNames.supplierLedger}(ledger_type);',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_supplier_ledger_reversal_of ON ${TableNames.supplierLedger}(reversal_of);',
    );
  }

  Future<void> _createSettlementSupportTables(Database database) async {
    await database.execute(
      '''
      CREATE TABLE IF NOT EXISTS ${TableNames.customerPaymentTransactions} (
        id TEXT PRIMARY KEY NOT NULL,
        customer_id TEXT NOT NULL,
        amount REAL NOT NULL CHECK (amount > 0),
        payment_method TEXT NOT NULL CHECK (
          payment_method IN (
            '${PaymentMethod.cash}',
            '${PaymentMethod.card}',
            '${PaymentMethod.bank}'
          )
        ),
        note TEXT,
        created_at TEXT NOT NULL,
        created_by TEXT,
        idempotency_key TEXT UNIQUE
      );
      ''',
    );
    await database.execute(
      '''
      CREATE TABLE IF NOT EXISTS ${TableNames.supplierPaymentTransactions} (
        id TEXT PRIMARY KEY NOT NULL,
        supplier_id TEXT NOT NULL,
        amount REAL NOT NULL CHECK (amount > 0),
        payment_method TEXT NOT NULL CHECK (
          payment_method IN (
            '${PaymentMethod.cash}',
            '${PaymentMethod.card}',
            '${PaymentMethod.bank}'
          )
        ),
        note TEXT,
        created_at TEXT NOT NULL,
        created_by TEXT,
        idempotency_key TEXT UNIQUE
      );
      ''',
    );
    await database.execute(
      '''
      CREATE TABLE IF NOT EXISTS ${TableNames.auditLogs} (
        id TEXT PRIMARY KEY NOT NULL,
        action TEXT NOT NULL,
        actor_id TEXT,
        entity_id TEXT NOT NULL,
        details TEXT,
        created_at TEXT NOT NULL
      );
      ''',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_customer_payment_transactions_customer ON ${TableNames.customerPaymentTransactions}(customer_id);',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_customer_payment_transactions_created ON ${TableNames.customerPaymentTransactions}(created_at);',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_supplier_payment_transactions_supplier ON ${TableNames.supplierPaymentTransactions}(supplier_id);',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_supplier_payment_transactions_created ON ${TableNames.supplierPaymentTransactions}(created_at);',
    );
    await database.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON ${TableNames.auditLogs}(created_at);',
    );
  }

  Future<void> _backfillCustomerLedger(Database database) async {
    await database.execute(
      '''
      INSERT OR IGNORE INTO ${TableNames.customerLedger} (
        id, party_id, transaction_id, ledger_type, amount, direction, note, created_at, created_by, is_reversal, reversal_of, payment_method
      )
      SELECT
        'bcl_sale_' || s.id,
        s.customer_id,
        s.id,
        'sale',
        COALESCE(s.total, 0),
        'debit',
        s.notes,
        s.sale_date,
        s.user_id,
        0,
        NULL,
        s.payment_method
      FROM ${TableNames.sales} s
      WHERE s.customer_id IS NOT NULL
        AND TRIM(s.customer_id) != ''
        AND LOWER(s.customer_id) != 'walk_in';
      ''',
    );
    await database.execute(
      '''
      INSERT OR IGNORE INTO ${TableNames.customerLedger} (
        id, party_id, transaction_id, ledger_type, amount, direction, note, created_at, created_by, is_reversal, reversal_of, payment_method
      )
      SELECT
        'bcl_sp_' || sp.id,
        s.customer_id,
        s.id,
        'sale_payment',
        COALESCE(sp.amount, 0),
        'credit',
        sp.notes,
        sp.created_at,
        NULL,
        0,
        NULL,
        sp.payment_method
      FROM ${TableNames.salePayments} sp
      JOIN ${TableNames.sales} s ON s.id = sp.sale_id
      WHERE s.customer_id IS NOT NULL
        AND TRIM(s.customer_id) != ''
        AND LOWER(s.customer_id) != 'walk_in';
      ''',
    );
    await database.execute(
      '''
      INSERT OR IGNORE INTO ${TableNames.customerLedger} (
        id, party_id, transaction_id, ledger_type, amount, direction, note, created_at, created_by, is_reversal, reversal_of, payment_method
      )
      SELECT
        'bcl_sr_' || sr.id,
        s.customer_id,
        s.id,
        'sale_return',
        COALESCE(sr.return_amount, 0),
        'credit',
        COALESCE(sr.reason, sr.notes),
        sr.created_at,
        NULL,
        0,
        NULL,
        NULL
      FROM ${TableNames.saleReturns} sr
      JOIN ${TableNames.sales} s ON s.id = sr.sale_id
      WHERE s.customer_id IS NOT NULL
        AND TRIM(s.customer_id) != ''
        AND LOWER(s.customer_id) != 'walk_in';
      ''',
    );
    await database.execute(
      '''
      INSERT OR IGNORE INTO ${TableNames.customerLedger} (
        id, party_id, transaction_id, ledger_type, amount, direction, note, created_at, created_by, is_reversal, reversal_of, payment_method
      )
      SELECT
        'bcl_rep_due_' || rj.id,
        c.id,
        rj.id,
        'repair_due',
        COALESCE(rj.final_cost, 0),
        'debit',
        rj.notes,
        COALESCE(rj.updated_at, rj.created_at),
        NULL,
        0,
        NULL,
        NULL
      FROM ${TableNames.repairJobs} rj
      JOIN ${TableNames.customers} c
        ON LOWER(TRIM(c.phone)) = LOWER(TRIM(COALESCE(rj.customer_phone, '')))
      WHERE COALESCE(rj.final_cost, 0) > 0;
      ''',
    );
    await database.execute(
      '''
      INSERT OR IGNORE INTO ${TableNames.customerLedger} (
        id, party_id, transaction_id, ledger_type, amount, direction, note, created_at, created_by, is_reversal, reversal_of, payment_method
      )
      SELECT
        'bcl_rep_pay_' || rj.id,
        c.id,
        rj.id,
        'repair_payment',
        COALESCE(rj.advance_received, 0),
        'credit',
        rj.notes,
        COALESCE(rj.updated_at, rj.created_at),
        NULL,
        0,
        NULL,
        '${PaymentMethod.cash}'
      FROM ${TableNames.repairJobs} rj
      JOIN ${TableNames.customers} c
        ON LOWER(TRIM(c.phone)) = LOWER(TRIM(COALESCE(rj.customer_phone, '')))
      WHERE COALESCE(rj.advance_received, 0) > 0;
      ''',
    );
    await database.execute(
      '''
      INSERT OR IGNORE INTO ${TableNames.customerLedger} (
        id, party_id, transaction_id, ledger_type, amount, direction, note, created_at, created_by, is_reversal, reversal_of, payment_method
      )
      SELECT
        'bcl_used_' || pi.id,
        c.id,
        p.id,
        'used_phone_buy',
        COALESCE(pi.line_total, 0),
        'credit',
        ss.seller_name,
        p.purchase_date,
        NULL,
        0,
        NULL,
        NULL
      FROM ${TableNames.purchaseItems} pi
      JOIN ${TableNames.purchases} p ON p.id = pi.purchase_id
      JOIN ${TableNames.serializedStock} ss ON ss.id = pi.serialized_stock_id
      JOIN ${TableNames.customers} c
        ON LOWER(TRIM(c.name)) = LOWER(TRIM(COALESCE(ss.seller_name, '')))
      WHERE ss.seller_name IS NOT NULL AND TRIM(ss.seller_name) != '';
      ''',
    );
  }

  Future<void> _backfillSupplierLedger(Database database) async {
    await database.execute(
      '''
      INSERT OR IGNORE INTO ${TableNames.supplierLedger} (
        id, party_id, transaction_id, ledger_type, amount, direction, note, created_at, created_by, is_reversal, reversal_of, payment_method
      )
      SELECT
        'bsl_purchase_' || p.id,
        p.supplier_id,
        p.id,
        'purchase',
        COALESCE(p.total, 0),
        'credit',
        p.notes,
        p.purchase_date,
        NULL,
        0,
        NULL,
        NULL
      FROM ${TableNames.purchases} p
      WHERE p.supplier_id IS NOT NULL AND TRIM(p.supplier_id) != '';
      ''',
    );
    await database.execute(
      '''
      INSERT OR IGNORE INTO ${TableNames.supplierLedger} (
        id, party_id, transaction_id, ledger_type, amount, direction, note, created_at, created_by, is_reversal, reversal_of, payment_method
      )
      SELECT
        'bsl_payment_' || p.id,
        p.supplier_id,
        p.id,
        'purchase_payment',
        COALESCE(p.paid_amount, 0),
        'debit',
        p.notes,
        p.purchase_date,
        NULL,
        0,
        NULL,
        '${PaymentMethod.cash}'
      FROM ${TableNames.purchases} p
      WHERE p.supplier_id IS NOT NULL
        AND TRIM(p.supplier_id) != ''
        AND COALESCE(p.paid_amount, 0) > 0;
      ''',
    );
  }

  Future<void> _dropTableBestEffort(Database database, String tableName) async {
    try {
      await database.execute('DROP TABLE $tableName;');
    } on DatabaseException catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('no such table') ||
          message.contains('sql logic error')) {
        return;
      }
      rethrow;
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
        payment_method TEXT CHECK (
          payment_method IS NULL OR payment_method IN (
            '${PaymentMethod.cash}',
            '${PaymentMethod.card}',
            '${PaymentMethod.bank}',
            '${PaymentMethod.credit}'
          )
        ),
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
      // Supports getAvailableImeis filtering and created_at ordering.
      'CREATE INDEX IF NOT EXISTS idx_serialized_stock_product_status_created ON ${TableNames.serializedStock}(product_model_id, stock_status, created_at);',
    ],
    4: <String>[
      'CREATE INDEX IF NOT EXISTS idx_inventory_stock_low_threshold ON ${TableNames.inventoryStock}(quantity, min_quantity);',
      'CREATE INDEX IF NOT EXISTS idx_sale_items_serialized_stock_id ON ${TableNames.saleItems}(serialized_stock_id);',
      'CREATE INDEX IF NOT EXISTS idx_sales_pending_balance ON ${TableNames.sales}(total, paid_amount);',
    ],
    5: <String>[
      '''
      CREATE TABLE ${TableNames.printJobs} (
        id TEXT PRIMARY KEY NOT NULL,
        sale_id TEXT NOT NULL UNIQUE,
        invoice_number TEXT NOT NULL,
        document_json TEXT NOT NULL,
        status TEXT NOT NULL CHECK (
          status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')
        ),
        retry_count INTEGER NOT NULL DEFAULT 0 CHECK (retry_count >= 0),
        last_error TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
      ''',
      'CREATE INDEX IF NOT EXISTS idx_print_jobs_status_updated ON ${TableNames.printJobs}(status, updated_at DESC);',
      'CREATE INDEX IF NOT EXISTS idx_print_jobs_created_at ON ${TableNames.printJobs}(created_at DESC);',
      'CREATE INDEX IF NOT EXISTS idx_print_jobs_invoice_number ON ${TableNames.printJobs}(invoice_number);',
      'CREATE INDEX IF NOT EXISTS idx_serialized_stock_product_status_imei1 ON ${TableNames.serializedStock}(product_model_id, stock_status, imei1);',
      'CREATE INDEX IF NOT EXISTS idx_serialized_stock_product_status_imei2 ON ${TableNames.serializedStock}(product_model_id, stock_status, imei2);',
      'CREATE INDEX IF NOT EXISTS idx_suppliers_name ON ${TableNames.suppliers}(name);',
      'CREATE INDEX IF NOT EXISTS idx_customers_name_phone ON ${TableNames.customers}(name, phone);',
    ],

    // ── v6: master-data management — brands, extended fields ─────────────
    6: <String>[
      '''
      CREATE TABLE ${TableNames.brands} (
        id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL UNIQUE,
        is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
      ''',
      'ALTER TABLE ${TableNames.productModels} ADD COLUMN barcode TEXT;',
      'ALTER TABLE ${TableNames.productModels} ADD COLUMN min_stock_alert INTEGER NOT NULL DEFAULT 0;',
      'ALTER TABLE ${TableNames.customers} ADD COLUMN notes TEXT;',
      'ALTER TABLE ${TableNames.customers} ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1;',
      'ALTER TABLE ${TableNames.suppliers} ADD COLUMN notes TEXT;',
      'ALTER TABLE ${TableNames.suppliers} ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1;',
      'CREATE INDEX IF NOT EXISTS idx_brands_name ON ${TableNames.brands}(name);',
      'CREATE INDEX IF NOT EXISTS idx_brands_is_active ON ${TableNames.brands}(is_active);',
      'CREATE INDEX IF NOT EXISTS idx_product_models_barcode ON ${TableNames.productModels}(barcode);',
      'CREATE INDEX IF NOT EXISTS idx_customers_is_active ON ${TableNames.customers}(is_active);',
      'CREATE INDEX IF NOT EXISTS idx_suppliers_is_active ON ${TableNames.suppliers}(is_active);',
    ],
    7: <String>[],
    8: <String>[
      '''
      CREATE TABLE IF NOT EXISTS ${TableNames.appSettings} (
        key TEXT PRIMARY KEY NOT NULL,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
      ''',
    ],
    9: <String>[],
    10: <String>[
      '''
      CREATE TABLE IF NOT EXISTS ${TableNames.salePayments} (
        id TEXT PRIMARY KEY NOT NULL,
        sale_id TEXT NOT NULL,
        amount REAL NOT NULL CHECK (amount > 0),
        payment_method TEXT NOT NULL CHECK (
          payment_method IN (
            '${PaymentMethod.cash}',
            '${PaymentMethod.card}',
            '${PaymentMethod.bank}'
          )
        ),
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES ${TableNames.sales}(id)
          ON UPDATE CASCADE
          ON DELETE CASCADE
      );
      ''',
      '''
      CREATE TABLE IF NOT EXISTS ${TableNames.saleReturns} (
        id TEXT PRIMARY KEY NOT NULL,
        sale_id TEXT NOT NULL,
        sale_item_id TEXT NOT NULL,
        product_model_id TEXT NOT NULL,
        serialized_stock_id TEXT,
        return_type TEXT NOT NULL CHECK (return_type IN ('imei', 'quantity')),
        return_qty INTEGER NOT NULL CHECK (return_qty > 0),
        return_amount REAL NOT NULL DEFAULT 0,
        reason TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES ${TableNames.sales}(id)
          ON UPDATE CASCADE
          ON DELETE CASCADE,
        FOREIGN KEY (sale_item_id) REFERENCES ${TableNames.saleItems}(id)
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
      CREATE TABLE IF NOT EXISTS ${TableNames.stockAdjustments} (
        id TEXT PRIMARY KEY NOT NULL,
        product_model_id TEXT NOT NULL,
        serialized_stock_id TEXT,
        adjustment_type TEXT NOT NULL CHECK (
          adjustment_type IN ('increase', 'decrease', 'write_off')
        ),
        quantity_delta INTEGER NOT NULL,
        reason TEXT NOT NULL CHECK (reason IN ('damage', 'theft', 'correction')),
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (product_model_id) REFERENCES ${TableNames.productModels}(id)
          ON UPDATE CASCADE
          ON DELETE RESTRICT,
        FOREIGN KEY (serialized_stock_id) REFERENCES ${TableNames.serializedStock}(id)
          ON UPDATE CASCADE
          ON DELETE SET NULL
      );
      ''',
      'CREATE INDEX IF NOT EXISTS idx_sale_payments_sale_created ON ${TableNames.salePayments}(sale_id, created_at DESC);',
      'CREATE INDEX IF NOT EXISTS idx_sale_returns_sale_item ON ${TableNames.saleReturns}(sale_id, sale_item_id);',
      'CREATE INDEX IF NOT EXISTS idx_sale_returns_serialized ON ${TableNames.saleReturns}(serialized_stock_id);',
      'CREATE INDEX IF NOT EXISTS idx_stock_adjustments_created ON ${TableNames.stockAdjustments}(created_at DESC);',
      'CREATE INDEX IF NOT EXISTS idx_stock_adjustments_product ON ${TableNames.stockAdjustments}(product_model_id);',
    ],
    11: <String>[
      // Refund Model: sale_returns now stores the unit cost at return time so
      // that profit reports can correctly reverse the cost component.
      'ALTER TABLE ${TableNames.saleReturns} ADD COLUMN cost_price REAL NOT NULL DEFAULT 0;',
    ],
    // v12 is handled by the dedicated _applyMigrationV12 method above.
    // The empty list is kept here so that all version numbers are represented
    // in the map for documentation purposes (consistent with v7 and v9).
    12: <String>[],
    // v16: add seller_phone to serialized_stock for used-phone seller contact.
    16: <String>[
      'ALTER TABLE ${TableNames.serializedStock} ADD COLUMN seller_phone TEXT;',
    ],
    // v17 and v18 are handled by dedicated methods above.
    // The empty lists are kept here so that all version numbers are represented
    // in the map for documentation purposes (consistent with v7 and v9).
    17: <String>[],
    18: <String>[],
    // v19: add issue_type column to repair_jobs for structured issue categorisation.
    19: <String>[
      'ALTER TABLE ${TableNames.repairJobs} ADD COLUMN issue_type TEXT;',
    ],
    20: <String>[
      'ALTER TABLE ${TableNames.saleReturns} ADD COLUMN refunded_paid_amount REAL NOT NULL DEFAULT 0;',
      'ALTER TABLE ${TableNames.saleReturns} ADD COLUMN refunded_cash_amount REAL NOT NULL DEFAULT 0;',
      'CREATE INDEX IF NOT EXISTS idx_sale_returns_created_at ON ${TableNames.saleReturns}(created_at);',
    ],
    21: <String>[],
    // v22 is handled by inline code in _applyMigration above.
    22: <String>[],
    // v23 is handled by dedicated _applyMigrationV23 method.
    23: <String>[],
    // v24 is handled by dedicated _applyMigrationV24 method.
    24: <String>[],
  };

  /// Migration v23: upgrade expenses table with structured category/remarks/payment fields.
  ///
  /// Old schema: id, expense_date, category, amount, notes, created_at, updated_at, is_deleted
  /// New schema: + custom_category, remarks, payment_method; notes → remarks
  Future<void> _applyMigrationV23(Database database) async {
    await database.execute('PRAGMA foreign_keys = OFF;');
    await database.execute('PRAGMA legacy_alter_table = ON;');
    try {
      await database.execute(
        'ALTER TABLE ${TableNames.expenses} RENAME TO ${TableNames.expenses}_v22;',
      );
      await database.execute(
        '''
        CREATE TABLE ${TableNames.expenses} (
          id TEXT PRIMARY KEY NOT NULL,
          expense_date TEXT NOT NULL,
          category TEXT NOT NULL,
          custom_category TEXT,
          amount REAL NOT NULL CHECK(amount >= 0),
          remarks TEXT,
          notes TEXT,
          payment_method TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT,
          is_deleted INTEGER NOT NULL DEFAULT 0
        );
        ''',
      );
      // Migrate data: map old `notes` → `remarks`, custom_category and payment_method default NULL.
      await database.execute(
        '''
        INSERT INTO ${TableNames.expenses} (
          id,
          expense_date,
          category,
          custom_category,
          amount,
          remarks,
          notes,
          payment_method,
          created_at,
          updated_at,
          is_deleted
        )
        SELECT
          id,
          expense_date,
          category,
          NULL,
          MAX(0.0, amount),
          CASE WHEN TRIM(COALESCE(notes, '')) = '' THEN NULL ELSE TRIM(notes) END,
          CASE WHEN TRIM(COALESCE(notes, '')) = '' THEN NULL ELSE TRIM(notes) END,
          NULL,
          created_at,
          updated_at,
          is_deleted
        FROM ${TableNames.expenses}_v22;
        ''',
      );
      await _dropTableBestEffort(database, '${TableNames.expenses}_v22');
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_date ON ${TableNames.expenses}(expense_date);',
      );
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_category ON ${TableNames.expenses}(category);',
      );
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_payment ON ${TableNames.expenses}(payment_method);',
      );
      await database.execute(
        'CREATE INDEX IF NOT EXISTS idx_expenses_deleted ON ${TableNames.expenses}(is_deleted);',
      );
    } finally {
      await database.execute('PRAGMA legacy_alter_table = OFF;');
      await database.execute('PRAGMA foreign_keys = ON;');
    }
  }

  /// Migration v24: preserve nullable `notes` as a compatibility alias for
  /// integrations and older fixtures while `remarks` remains canonical.
  Future<void> _applyMigrationV24(Database database) async {
    final columns = await database.rawQuery(
      'PRAGMA table_info(${TableNames.expenses});',
    );
    final hasNotes = columns.any((row) => row['name'] == 'notes');
    if (!hasNotes) {
      await database.execute(
        'ALTER TABLE ${TableNames.expenses} ADD COLUMN notes TEXT;',
      );
      await database.execute(
        '''
        UPDATE ${TableNames.expenses}
        SET notes = remarks
        WHERE notes IS NULL
          AND remarks IS NOT NULL
        ''',
      );
    }
  }
}
