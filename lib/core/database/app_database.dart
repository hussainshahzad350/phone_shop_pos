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

    final now = DateTimeHelpers.toSql(DateTimeHelpers.nowUtc());

    await runInTransaction<void>((transaction) async {
      final userId = IdHelpers.newId(prefix: 'usr');
      final customerWalkInId = IdHelpers.newId(prefix: 'cus');
      final customerRegularId = IdHelpers.newId(prefix: 'cus');
      final supplierId = IdHelpers.newId(prefix: 'sup');
      final serializedProductId = IdHelpers.newId(prefix: 'prd');
      final accessoryProductId = IdHelpers.newId(prefix: 'prd');
      final chargerProductId = IdHelpers.newId(prefix: 'prd');

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

      await transaction.insert(TableNames.suppliers, <String, Object?>{
        'id': supplierId,
        'name': 'Demo Mobile Distributor',
        'contact_person': 'Ali Khan',
        'phone': '03001234567',
        'email': null,
        'address': 'Hall Road, Lahore',
        'created_at': now,
        'updated_at': now,
      });

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

      await transaction.insert(TableNames.productModels, <String, Object?>{
        'id': serializedProductId,
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
        'id': accessoryProductId,
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
        'id': chargerProductId,
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

      await transaction.insert(TableNames.inventoryStock, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'stk'),
        'product_model_id': accessoryProductId,
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
        'product_model_id': chargerProductId,
        'quantity': 30,
        'min_quantity': 4,
        'max_quantity': 100,
        'unit_cost': 1200,
        'unit_price': 1800,
        'location': 'Rack B',
        'created_at': now,
        'updated_at': now,
      });

      await transaction.insert(TableNames.serializedStock, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'ser'),
        'product_model_id': serializedProductId,
        'imei1': '356789101234561',
        'imei2': '356789101234579',
        'serial_number': 'SAMA54A001',
        'cost_price': 98000,
        'selling_price': 105000,
        'stock_status': 'in_stock',
        'supplier_id': supplierId,
        'notes': null,
        'created_at': now,
        'updated_at': now,
      });

      await transaction.insert(TableNames.serializedStock, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'ser'),
        'product_model_id': serializedProductId,
        'imei1': '356789101234587',
        'imei2': '356789101234595',
        'serial_number': 'SAMA54A002',
        'cost_price': 98000,
        'selling_price': 105000,
        'stock_status': 'in_stock',
        'supplier_id': supplierId,
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
