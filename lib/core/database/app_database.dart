import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:phone_shop_pos/core/database/database_constants.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';

class AppDatabase {
  AppDatabase({
    required LocalDatabaseService localDatabaseService,
    required MigrationService migrationService,
  }) : _localDatabaseService = localDatabaseService,
       _migrationService = migrationService;

  final LocalDatabaseService _localDatabaseService;
  final MigrationService _migrationService;

  Database? _database;

  Future<Database> initialize({bool seedDemoData = false}) async {
    if (_database != null) {
      return _database!;
    }

    await _localDatabaseService.initialize();
    final opened = await _localDatabaseService.factory.openDatabase(
      _localDatabaseService.databasePath,
      options: OpenDatabaseOptions(
        version: _migrationService.latestVersion,
        onConfigure: _migrationService.onConfigure,
        onCreate: _migrationService.onCreate,
        onUpgrade: _migrationService.onUpgrade,
      ),
    );

    _database = opened;

    if (seedDemoData) {
      await seedDemoDataIfEmpty();
    }
    return opened;
  }

  Database get database {
    final db = _database;
    if (db == null) {
      throw StateError('Database is not initialized. Call initialize() first.');
    }
    return db;
  }

  Future<void> close() async {
    final db = _database;
    if (db == null) {
      return;
    }
    await db.close();
    _database = null;
  }

  Future<T> runInTransaction<T>(
    Future<T> Function(Transaction transaction) action,
  ) async {
    return database.transaction<T>((transaction) => action(transaction));
  }

  Future<List<Map<String, Object?>>> queryTable(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) {
    return database.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  Future<int> insert(
    String table,
    Map<String, Object?> values, {
    ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort,
  }) {
    return database.insert(table, values, conflictAlgorithm: conflictAlgorithm);
  }

  Future<int> update(
    String table,
    Map<String, Object?> values, {
    required String where,
    List<Object?>? whereArgs,
  }) {
    return database.update(table, values, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    required String where,
    List<Object?>? whereArgs,
  }) {
    return database.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<void> seedDemoDataIfEmpty() async {
    final usersCount = Sqflite.firstIntValue(
      await database.rawQuery('SELECT COUNT(*) FROM ${TableNames.users}'),
    );

    if ((usersCount ?? 0) > 0) {
      return;
    }

    final nowUtc = DateTimeHelpers.nowUtc();
    final now = DateTimeHelpers.toSql(nowUtc);

    await runInTransaction<void>((transaction) async {
      // ── Users ────────────────────────────────────────────────────────────
      final userId = IdHelpers.newId(prefix: 'usr');
      await transaction.insert(TableNames.users, <String, Object?>{
        'id': userId,
        'username': 'admin',
        'full_name': 'System Admin',
        'password_hash': null,
        'role': 'admin',
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });

      // ── Suppliers ────────────────────────────────────────────────────────
      final supplier1Id = IdHelpers.newId(prefix: 'sup');
      final supplier2Id = IdHelpers.newId(prefix: 'sup');
      await transaction.insert(TableNames.suppliers, <String, Object?>{
        'id': supplier1Id,
        'name': 'Demo Mobile Distributor',
        'contact_person': 'Ali Khan',
        'phone': '03001234567',
        'email': null,
        'address': 'Hall Road, Lahore',
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.suppliers, <String, Object?>{
        'id': supplier2Id,
        'name': 'Tech Galaxy Wholesale',
        'contact_person': 'Bilal Ahmed',
        'phone': '03219876543',
        'email': null,
        'address': 'Hafeez Centre, Lahore',
        'created_at': now,
        'updated_at': now,
      });

      // ── Customers ────────────────────────────────────────────────────────
      final customerWalkInId = IdHelpers.newId(prefix: 'cus');
      final customerRegularId = IdHelpers.newId(prefix: 'cus');
      final customerWholesaleId = IdHelpers.newId(prefix: 'cus');
      await transaction.insert(TableNames.customers, <String, Object?>{
        'id': customerWalkInId,
        'name': 'Walk-in Customer',
        'phone': null,
        'email': null,
        'address': null,
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.customers, <String, Object?>{
        'id': customerRegularId,
        'name': 'Usman Retail',
        'phone': '03111222333',
        'email': null,
        'address': 'Model Town, Lahore',
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.customers, <String, Object?>{
        'id': customerWholesaleId,
        'name': 'Hassan Mobile Store',
        'phone': '03334455667',
        'email': null,
        'address': 'DHA Phase 5, Lahore',
        'created_at': now,
        'updated_at': now,
      });

      // ── Products ─────────────────────────────────────────────────────────
      final prdA54Id = IdHelpers.newId(prefix: 'prd');
      final prdS23Id = IdHelpers.newId(prefix: 'prd');
      final prdIphone14Id = IdHelpers.newId(prefix: 'prd');
      final prdRedmi12Id = IdHelpers.newId(prefix: 'prd');
      final prdCableId = IdHelpers.newId(prefix: 'prd');
      final prdCharger25Id = IdHelpers.newId(prefix: 'prd');
      final prdScreenGuardId = IdHelpers.newId(prefix: 'prd');
      final prdCoverId = IdHelpers.newId(prefix: 'prd');
      final prdEarbudsId = IdHelpers.newId(prefix: 'prd');

      await transaction.insert(TableNames.productModels, <String, Object?>{
        'id': prdA54Id,
        'name': 'Samsung Galaxy A54 8/256',
        'brand': 'Samsung',
        'category': 'Phones',
        'sku': 'SAM-A54-8256',
        'purchase_price': 98000,
        'sale_price': 105000,
        'has_imei': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.productModels, <String, Object?>{
        'id': prdS23Id,
        'name': 'Samsung Galaxy S23 8/128',
        'brand': 'Samsung',
        'category': 'Phones',
        'sku': 'SAM-S23-8128',
        'purchase_price': 175000,
        'sale_price': 185000,
        'has_imei': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.productModels, <String, Object?>{
        'id': prdIphone14Id,
        'name': 'iPhone 14 128GB',
        'brand': 'Apple',
        'category': 'Phones',
        'sku': 'APL-IP14-128',
        'purchase_price': 220000,
        'sale_price': 235000,
        'has_imei': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.productModels, <String, Object?>{
        'id': prdRedmi12Id,
        'name': 'Redmi 12 4/128',
        'brand': 'Xiaomi',
        'category': 'Phones',
        'sku': 'XMI-RD12-4128',
        'purchase_price': 38000,
        'sale_price': 42000,
        'has_imei': 1,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.productModels, <String, Object?>{
        'id': prdCableId,
        'name': 'Type-C Data Cable',
        'brand': 'Anker',
        'category': 'Accessories',
        'sku': 'ACC-CABLE-001',
        'purchase_price': 300,
        'sale_price': 500,
        'has_imei': 0,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.productModels, <String, Object?>{
        'id': prdCharger25Id,
        'name': 'Fast Charger 25W',
        'brand': 'Baseus',
        'category': 'Accessories',
        'sku': 'ACC-CHARGER-025',
        'purchase_price': 1200,
        'sale_price': 1800,
        'has_imei': 0,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.productModels, <String, Object?>{
        'id': prdScreenGuardId,
        'name': 'Tempered Glass Screen Guard',
        'brand': 'Nillkin',
        'category': 'Accessories',
        'sku': 'ACC-TG-UNI',
        'purchase_price': 150,
        'sale_price': 300,
        'has_imei': 0,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.productModels, <String, Object?>{
        'id': prdCoverId,
        'name': 'Silicone Back Cover',
        'brand': 'Generic',
        'category': 'Accessories',
        'sku': 'ACC-COVER-UNI',
        'purchase_price': 80,
        'sale_price': 150,
        'has_imei': 0,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.productModels, <String, Object?>{
        'id': prdEarbudsId,
        'name': 'TWS Earbuds A6',
        'brand': 'Baseus',
        'category': 'Accessories',
        'sku': 'ACC-TWS-A6',
        'purchase_price': 1800,
        'sale_price': 2500,
        'has_imei': 0,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });

      // ── Inventory Stock (accessories) ──────────────────────────────────
      await transaction.insert(TableNames.inventoryStock, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'stk'),
        'product_model_id': prdCableId,
        'quantity': 45,
        'min_quantity': 5,
        'max_quantity': 200,
        'unit_cost': 300,
        'unit_price': 500,
        'location': 'Rack A',
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.inventoryStock, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'stk'),
        'product_model_id': prdCharger25Id,
        'quantity': 30,
        'min_quantity': 4,
        'max_quantity': 100,
        'unit_cost': 1200,
        'unit_price': 1800,
        'location': 'Rack B',
        'created_at': now,
        'updated_at': now,
      });
      // Low-stock item to test low-stock tracking
      await transaction.insert(TableNames.inventoryStock, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'stk'),
        'product_model_id': prdScreenGuardId,
        'quantity': 3,
        'min_quantity': 10,
        'max_quantity': 200,
        'unit_cost': 150,
        'unit_price': 300,
        'location': 'Rack A',
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.inventoryStock, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'stk'),
        'product_model_id': prdCoverId,
        'quantity': 60,
        'min_quantity': 10,
        'max_quantity': 300,
        'unit_cost': 80,
        'unit_price': 150,
        'location': 'Rack C',
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.inventoryStock, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'stk'),
        'product_model_id': prdEarbudsId,
        'quantity': 12,
        'min_quantity': 3,
        'max_quantity': 50,
        'unit_cost': 1800,
        'unit_price': 2500,
        'location': 'Shelf D',
        'created_at': now,
        'updated_at': now,
      });

      // ── Serialized Stock (phones) ──────────────────────────────────────
      // Samsung A54 – 3 in_stock, 1 sold
      await transaction.insert(TableNames.serializedStock, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'ser'),
        'product_model_id': prdA54Id,
        'imei1': '356789101234561',
        'imei2': '356789101234579',
        'serial_number': 'SAMA54A001',
        'cost_price': 98000,
        'selling_price': 105000,
        'stock_status': 'in_stock',
        'supplier_id': supplier1Id,
        'notes': null,
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.serializedStock, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'ser'),
        'product_model_id': prdA54Id,
        'imei1': '356789101234587',
        'imei2': '356789101234595',
        'serial_number': 'SAMA54A002',
        'cost_price': 98000,
        'selling_price': 105000,
        'stock_status': 'in_stock',
        'supplier_id': supplier1Id,
        'notes': null,
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.serializedStock, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'ser'),
        'product_model_id': prdA54Id,
        'imei1': '356789101234603',
        'imei2': null,
        'serial_number': 'SAMA54A003',
        'cost_price': 98000,
        'selling_price': 105000,
        'stock_status': 'in_stock',
        'supplier_id': supplier1Id,
        'notes': null,
        'created_at': now,
        'updated_at': now,
      });
      final soldA54StockId = IdHelpers.newId(prefix: 'ser');
      await transaction.insert(TableNames.serializedStock, <String, Object?>{
        'id': soldA54StockId,
        'product_model_id': prdA54Id,
        'imei1': '356789101234611',
        'imei2': '356789101234629',
        'serial_number': 'SAMA54A004',
        'cost_price': 97000,
        'selling_price': 104000,
        'stock_status': 'sold',
        'supplier_id': supplier1Id,
        'notes': null,
        'created_at': now,
        'updated_at': now,
      });

      // Samsung S23 – 2 in_stock, 1 reserved
      await transaction.insert(TableNames.serializedStock, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'ser'),
        'product_model_id': prdS23Id,
        'imei1': '490154203237518',
        'imei2': '490154203237526',
        'serial_number': 'SAMS23B001',
        'cost_price': 175000,
        'selling_price': 185000,
        'stock_status': 'in_stock',
        'supplier_id': supplier1Id,
        'notes': null,
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.serializedStock, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'ser'),
        'product_model_id': prdS23Id,
        'imei1': '490154203237534',
        'imei2': null,
        'serial_number': 'SAMS23B002',
        'cost_price': 175000,
        'selling_price': 185000,
        'stock_status': 'in_stock',
        'supplier_id': supplier2Id,
        'notes': null,
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.serializedStock, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'ser'),
        'product_model_id': prdS23Id,
        'imei1': '490154203237542',
        'imei2': '490154203237559',
        'serial_number': 'SAMS23B003',
        'cost_price': 175000,
        'selling_price': 183000,
        'stock_status': 'reserved',
        'supplier_id': supplier2Id,
        'notes': 'Reserved for Hassan Mobile',
        'created_at': now,
        'updated_at': now,
      });

      // iPhone 14 – 1 in_stock, 1 sold
      await transaction.insert(TableNames.serializedStock, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'ser'),
        'product_model_id': prdIphone14Id,
        'imei1': '353879100123456',
        'imei2': null,
        'serial_number': 'F2LNMC9PLV',
        'cost_price': 220000,
        'selling_price': 235000,
        'stock_status': 'in_stock',
        'supplier_id': supplier2Id,
        'notes': null,
        'created_at': now,
        'updated_at': now,
      });
      final soldIphoneStockId = IdHelpers.newId(prefix: 'ser');
      await transaction.insert(TableNames.serializedStock, <String, Object?>{
        'id': soldIphoneStockId,
        'product_model_id': prdIphone14Id,
        'imei1': '353879100123464',
        'imei2': null,
        'serial_number': 'F2LNMC9PLW',
        'cost_price': 218000,
        'selling_price': 232000,
        'stock_status': 'sold',
        'supplier_id': supplier2Id,
        'notes': null,
        'created_at': now,
        'updated_at': now,
      });

      // ── Sales History (realistic demo for dashboard/reports) ─────────────
      final saleToday1Id = IdHelpers.newId(prefix: 'sal');
      final saleToday2Id = IdHelpers.newId(prefix: 'sal');
      final saleYesterdayId = IdHelpers.newId(prefix: 'sal');
      final saleTwoDaysAgoId = IdHelpers.newId(prefix: 'sal');
      final saleThreeDaysAgoId = IdHelpers.newId(prefix: 'sal');
      final saleFiveDaysAgoId = IdHelpers.newId(prefix: 'sal');

      final todayAt1030 = DateTimeHelpers.toSql(
        nowUtc.subtract(const Duration(hours: 2)),
      );
      final todayAt1400 = DateTimeHelpers.toSql(
        nowUtc.subtract(const Duration(hours: 1)),
      );
      final yesterday = DateTimeHelpers.toSql(
        nowUtc.subtract(const Duration(days: 1)),
      );
      final twoDaysAgo = DateTimeHelpers.toSql(
        nowUtc.subtract(const Duration(days: 2)),
      );
      final threeDaysAgo = DateTimeHelpers.toSql(
        nowUtc.subtract(const Duration(days: 3)),
      );
      final fiveDaysAgo = DateTimeHelpers.toSql(
        nowUtc.subtract(const Duration(days: 5)),
      );

      await transaction.insert(TableNames.sales, <String, Object?>{
        'id': saleToday1Id,
        'invoice_number': 'SAL-${nowUtc.year}-0001',
        'customer_id': customerRegularId,
        'user_id': userId,
        'sale_date': todayAt1030,
        'subtotal': 105800,
        'discount': 0,
        'tax': 0,
        'total': 105800,
        'paid_amount': 100000,
        'payment_method': 'cash',
        'notes': 'Partial payment from regular customer',
        'created_at': now,
        'updated_at': now,
      });

      await transaction.insert(TableNames.saleItems, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'sli'),
        'sale_id': saleToday1Id,
        'product_model_id': prdA54Id,
        'serialized_stock_id': soldA54StockId,
        'quantity': 1,
        'unit_price': 104000,
        'discount': 0,
        'line_total': 104000,
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.saleItems, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'sli'),
        'sale_id': saleToday1Id,
        'product_model_id': prdCharger25Id,
        'serialized_stock_id': null,
        'quantity': 1,
        'unit_price': 1800,
        'discount': 0,
        'line_total': 1800,
        'created_at': now,
        'updated_at': now,
      });

      await transaction.insert(TableNames.sales, <String, Object?>{
        'id': saleToday2Id,
        'invoice_number': 'SAL-${nowUtc.year}-0002',
        'customer_id': customerWalkInId,
        'user_id': userId,
        'sale_date': todayAt1400,
        'subtotal': 1300,
        'discount': 0,
        'tax': 0,
        'total': 1300,
        'paid_amount': 1300,
        'payment_method': 'card',
        'notes': 'Walk-in accessories sale',
        'created_at': now,
        'updated_at': now,
      });

      await transaction.insert(TableNames.saleItems, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'sli'),
        'sale_id': saleToday2Id,
        'product_model_id': prdCableId,
        'serialized_stock_id': null,
        'quantity': 2,
        'unit_price': 500,
        'discount': 0,
        'line_total': 1000,
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.saleItems, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'sli'),
        'sale_id': saleToday2Id,
        'product_model_id': prdScreenGuardId,
        'serialized_stock_id': null,
        'quantity': 1,
        'unit_price': 300,
        'discount': 0,
        'line_total': 300,
        'created_at': now,
        'updated_at': now,
      });

      await transaction.insert(TableNames.sales, <String, Object?>{
        'id': saleYesterdayId,
        'invoice_number': 'SAL-${nowUtc.year}-0003',
        'customer_id': customerWholesaleId,
        'user_id': userId,
        'sale_date': yesterday,
        'subtotal': 5000,
        'discount': 0,
        'tax': 0,
        'total': 5000,
        'paid_amount': 2500,
        'payment_method': 'bank_transfer',
        'notes': 'Wholesale order, remaining due',
        'created_at': now,
        'updated_at': now,
      });

      await transaction.insert(TableNames.saleItems, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'sli'),
        'sale_id': saleYesterdayId,
        'product_model_id': prdEarbudsId,
        'serialized_stock_id': null,
        'quantity': 2,
        'unit_price': 2500,
        'discount': 0,
        'line_total': 5000,
        'created_at': now,
        'updated_at': now,
      });

      await transaction.insert(TableNames.sales, <String, Object?>{
        'id': saleTwoDaysAgoId,
        'invoice_number': 'SAL-${nowUtc.year}-0004',
        'customer_id': customerRegularId,
        'user_id': userId,
        'sale_date': twoDaysAgo,
        'subtotal': 232000,
        'discount': 0,
        'tax': 0,
        'total': 232000,
        'paid_amount': 232000,
        'payment_method': 'cash',
        'notes': 'High-value phone sale',
        'created_at': now,
        'updated_at': now,
      });

      await transaction.insert(TableNames.saleItems, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'sli'),
        'sale_id': saleTwoDaysAgoId,
        'product_model_id': prdIphone14Id,
        'serialized_stock_id': soldIphoneStockId,
        'quantity': 1,
        'unit_price': 232000,
        'discount': 0,
        'line_total': 232000,
        'created_at': now,
        'updated_at': now,
      });

      await transaction.insert(TableNames.sales, <String, Object?>{
        'id': saleThreeDaysAgoId,
        'invoice_number': 'SAL-${nowUtc.year}-0005',
        'customer_id': customerRegularId,
        'user_id': userId,
        'sale_date': threeDaysAgo,
        'subtotal': 2550,
        'discount': 0,
        'tax': 0,
        'total': 2550,
        'paid_amount': 2000,
        'payment_method': 'cash',
        'notes': 'Small mixed sale',
        'created_at': now,
        'updated_at': now,
      });

      await transaction.insert(TableNames.saleItems, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'sli'),
        'sale_id': saleThreeDaysAgoId,
        'product_model_id': prdCoverId,
        'serialized_stock_id': null,
        'quantity': 5,
        'unit_price': 150,
        'discount': 0,
        'line_total': 750,
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.saleItems, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'sli'),
        'sale_id': saleThreeDaysAgoId,
        'product_model_id': prdCharger25Id,
        'serialized_stock_id': null,
        'quantity': 1,
        'unit_price': 1800,
        'discount': 0,
        'line_total': 1800,
        'created_at': now,
        'updated_at': now,
      });

      await transaction.insert(TableNames.sales, <String, Object?>{
        'id': saleFiveDaysAgoId,
        'invoice_number': 'SAL-${nowUtc.year}-0006',
        'customer_id': customerWalkInId,
        'user_id': userId,
        'sale_date': fiveDaysAgo,
        'subtotal': 5000,
        'discount': 500,
        'tax': 0,
        'total': 4500,
        'paid_amount': 4500,
        'payment_method': 'cash',
        'notes': 'Promotional accessories bundle',
        'created_at': now,
        'updated_at': now,
      });

      await transaction.insert(TableNames.saleItems, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'sli'),
        'sale_id': saleFiveDaysAgoId,
        'product_model_id': prdCableId,
        'serialized_stock_id': null,
        'quantity': 10,
        'unit_price': 500,
        'discount': 500,
        'line_total': 4500,
        'created_at': now,
        'updated_at': now,
      });

      // Redmi 12 – 4 in_stock
      await transaction.insert(TableNames.serializedStock, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'ser'),
        'product_model_id': prdRedmi12Id,
        'imei1': '869274057231846',
        'imei2': '869274057231853',
        'serial_number': 'RD12X001',
        'cost_price': 38000,
        'selling_price': 42000,
        'stock_status': 'in_stock',
        'supplier_id': supplier1Id,
        'notes': null,
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.serializedStock, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'ser'),
        'product_model_id': prdRedmi12Id,
        'imei1': '869274057231861',
        'imei2': '869274057231879',
        'serial_number': 'RD12X002',
        'cost_price': 38000,
        'selling_price': 42000,
        'stock_status': 'in_stock',
        'supplier_id': supplier1Id,
        'notes': null,
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.serializedStock, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'ser'),
        'product_model_id': prdRedmi12Id,
        'imei1': '869274057231887',
        'imei2': null,
        'serial_number': 'RD12X003',
        'cost_price': 37500,
        'selling_price': 41500,
        'stock_status': 'in_stock',
        'supplier_id': supplier1Id,
        'notes': null,
        'created_at': now,
        'updated_at': now,
      });
      await transaction.insert(TableNames.serializedStock, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'ser'),
        'product_model_id': prdRedmi12Id,
        'imei1': '869274057231895',
        'imei2': '869274057231903',
        'serial_number': 'RD12X004',
        'cost_price': 37500,
        'selling_price': 41500,
        'stock_status': 'in_stock',
        'supplier_id': supplier1Id,
        'notes': null,
        'created_at': now,
        'updated_at': now,
      });
    });
  }

  bool get isInitialized => _database != null;

  String get filePath => _localDatabaseService.databasePath;

  int get version => DatabaseConstants.databaseVersion;
}
