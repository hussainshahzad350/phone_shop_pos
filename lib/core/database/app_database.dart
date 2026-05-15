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
      await transaction.insert(TableNames.users, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'usr'),
        'username': 'admin',
        'full_name': 'System Admin',
        'password_hash': null,
        'role': 'admin',
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });

      await transaction.insert(TableNames.productModels, <String, Object?>{
        'id': IdHelpers.newId(prefix: 'prd'),
        'name': 'Demo Accessory',
        'brand': 'Demo',
        'category': 'Accessories',
        'sku': 'DEMO-ACC-001',
        'purchase_price': 500,
        'sale_price': 700,
        'has_imei': 0,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
    });
  }

  bool get isInitialized => _database != null;

  String get filePath => _localDatabaseService.databasePath;

  int get version => DatabaseConstants.databaseVersion;
}
