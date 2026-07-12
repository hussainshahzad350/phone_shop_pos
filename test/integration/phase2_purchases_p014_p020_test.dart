import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/inventory/data/repositories/sqlite_product_repository.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/data/repositories/sqlite_purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';

void main() {
  group('PHASE 2 Purchases P-014..P-020', () {
    test('P-014 Weighted average cost update is correct', () async {
      final context = await _P2Context.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p014_accessory',
        name: 'P014 Accessory',
        sku: 'P014-ACC-001',
        purchasePrice: 100,
        salePrice: 180,
        hasImei: false,
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p014_accessory',
              productName: 'P014 Accessory',
              hasImei: false,
              quantity: 10,
              unitCost: 100,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 1000,
        ),
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p014_accessory',
              productName: 'P014 Accessory',
              hasImei: false,
              quantity: 10,
              unitCost: 200,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 2000,
        ),
      );

      final stock = await context.fetchInventoryStock('prd_p014_accessory');
      expect(stock['quantity'], 20);
      expect((stock['unit_cost'] as num).toDouble(), closeTo(150, 0.0001));
    });

    test('P-015 Serialized phone cost remains per-device purchase cost',
        () async {
      final context = await _P2Context.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p015_phone',
        name: 'P015 Phone',
        sku: 'P015-PHONE-001',
        purchasePrice: 30000,
        salePrice: 35000,
        hasImei: true,
      );

      final completion = _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p015_phone',
              productName: 'P015 Phone',
              hasImei: true,
              imeiEntries: <ImeiEntry>[
                ImeiEntry(imei1: '356789101234581', costPrice: 30000),
                ImeiEntry(imei1: '356789101234582', costPrice: 32000),
              ],
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 62000,
        ),
      );

      final imeiA = await context.fetchSerializedByImei('356789101234581');
      final imeiB = await context.fetchSerializedByImei('356789101234582');
      final itemRows = await context.fetchPurchaseItems(completion.purchaseId);

      expect((imeiA['cost_price'] as num).toDouble(), closeTo(30000, 0.0001));
      expect((imeiB['cost_price'] as num).toDouble(), closeTo(32000, 0.0001));
      expect(itemRows.length, 2);
      expect(
        itemRows.map((row) => (row['unit_cost'] as num).toDouble()).toSet(),
        equals(<double>{30000, 32000}),
      );
    });

    test('P-016 Zero cost purchase has intentional handling', () async {
      final context = await _P2Context.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p016_accessory',
        name: 'P016 Accessory',
        sku: 'P016-ACC-001',
        purchasePrice: 50,
        salePrice: 100,
        hasImei: false,
      );

      final result = await context.purchaseRepository.createPurchaseTransaction(
        items: const <PurchaseFormItem>[
          PurchaseFormItem(
            productModelId: 'prd_p016_accessory',
            productName: 'P016 Accessory',
            hasImei: false,
            quantity: 2,
            unitCost: 0,
          ),
        ],
        discount: 0,
        tax: 0,
        paidAmount: 0,
      );

      if (result.isSuccess) {
        final stock = await context.fetchInventoryStock('prd_p016_accessory');
        expect(stock['quantity'], 2);
        expect((stock['unit_cost'] as num).toDouble(), closeTo(0, 0.0001));
      } else {
        expect(result.isFailure, isTrue);
      }
    });

    test('P-017 Negative cost attempt is blocked', () async {
      final context = await _P2Context.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p017_accessory',
        name: 'P017 Accessory',
        sku: 'P017-ACC-001',
        purchasePrice: 100,
        salePrice: 150,
        hasImei: false,
      );

      final result = await context.purchaseRepository.createPurchaseTransaction(
        items: const <PurchaseFormItem>[
          PurchaseFormItem(
            productModelId: 'prd_p017_accessory',
            productName: 'P017 Accessory',
            hasImei: false,
            quantity: 1,
            unitCost: -1,
          ),
        ],
        discount: 0,
        tax: 0,
        paidAmount: 0,
      );

      expect(result.isFailure, isTrue);
      expect(await context.countRows(TableNames.purchases), 0);
      expect(await context.countRows(TableNames.purchaseItems), 0);
    });

    test('P-018 High-value purchase avoids overflow and stores correct total',
        () async {
      final context = await _P2Context.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p018_accessory',
        name: 'P018 Accessory',
        sku: 'P018-ACC-001',
        purchasePrice: 5000000,
        salePrice: 5500000,
        hasImei: false,
      );

      final completion = _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p018_accessory',
              productName: 'P018 Accessory',
              hasImei: false,
              quantity: 2,
              unitCost: 5000000,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 10000000,
        ),
      );

      final purchase = await context.fetchPurchase(completion.purchaseId);
      expect((purchase['total'] as num).toDouble(), closeTo(10000000, 0.0001));
      expect(
          (purchase['subtotal'] as num).toDouble(), closeTo(10000000, 0.0001));
    });

    test('P-019 Purchase adds stock immediately', () async {
      final context = await _P2Context.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p019_accessory',
        name: 'P019 Accessory',
        sku: 'P019-ACC-001',
        purchasePrice: 200,
        salePrice: 300,
        hasImei: false,
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p019_accessory',
              productName: 'P019 Accessory',
              hasImei: false,
              quantity: 7,
              unitCost: 200,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 1400,
        ),
      );

      final stock = await context.fetchInventoryStock('prd_p019_accessory');
      expect(stock['quantity'], 7);
    });

    test('P-020 Purchase rollback on failure saves nothing', () async {
      final context = await _P2Context.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p020_accessory',
        name: 'P020 Accessory',
        sku: 'P020-ACC-001',
        purchasePrice: 100,
        salePrice: 160,
        hasImei: false,
      );
      await context.createProduct(
        id: 'prd_p020_phone',
        name: 'P020 Phone',
        sku: 'P020-PHONE-001',
        purchasePrice: 35000,
        salePrice: 41000,
        hasImei: true,
      );

      final result = await context.purchaseRepository.createPurchaseTransaction(
        items: const <PurchaseFormItem>[
          PurchaseFormItem(
            productModelId: 'prd_p020_accessory',
            productName: 'P020 Accessory',
            hasImei: false,
            quantity: 4,
            unitCost: 100,
          ),
          PurchaseFormItem(
            productModelId: 'prd_p020_phone',
            productName: 'P020 Phone',
            hasImei: true,
            imeiEntries: <ImeiEntry>[
              ImeiEntry(imei1: 'INVALID-IMEI', costPrice: 35000),
            ],
          ),
        ],
        discount: 0,
        tax: 0,
        paidAmount: 35400,
      );

      expect(result.isFailure, isTrue);
      expect(await context.countRows(TableNames.purchases), 0);
      expect(await context.countRows(TableNames.purchaseItems), 0);
      expect(
        await context.countRowsWhere(
          TableNames.inventoryStock,
          where: 'product_model_id = ?',
          whereArgs: const <Object?>['prd_p020_accessory'],
        ),
        0,
      );
      expect(
        await context.countRowsWhere(
          TableNames.serializedStock,
          where: 'product_model_id = ?',
          whereArgs: const <Object?>['prd_p020_phone'],
        ),
        0,
      );
    });
  });
}

class _P2Context {
  _P2Context._({
    required this.rootDirectory,
    required this.appDatabase,
  })  : productRepository = SqliteProductRepository(appDatabase: appDatabase),
        purchaseRepository = SqlitePurchaseRepository(appDatabase: appDatabase);

  final Directory rootDirectory;
  final AppDatabase appDatabase;
  final SqliteProductRepository productRepository;
  final SqlitePurchaseRepository purchaseRepository;

  static Future<_P2Context> createTemporary() async {
    final rootDirectory = await Directory.systemTemp.createTemp(
      'phone_shop_pos_phase2_p014_p020_',
    );
    final appDatabase = AppDatabase(
      localDatabaseService: SqliteFfiDatabaseService(
        rootDirectory: rootDirectory.path,
      ),
      migrationService: const MigrationService(),
    );
    await appDatabase.initialize(seedDemoData: false);
    return _P2Context._(rootDirectory: rootDirectory, appDatabase: appDatabase);
  }

  Future<void> dispose() async {
    await appDatabase.close();
    if (await rootDirectory.exists()) {
      await rootDirectory.delete(recursive: true);
    }
  }

  Future<ProductEntity> createProduct({
    required String id,
    required String name,
    required String sku,
    required double purchasePrice,
    required double salePrice,
    required bool hasImei,
  }) async {
    final now = DateTime.utc(2026, 5, 17);
    return _expectSuccess(
      await productRepository.createProduct(
        ProductEntity(
          id: id,
          name: name,
          purchasePrice: purchasePrice,
          salePrice: salePrice,
          hasImei: hasImei,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      ),
    );
  }

  Future<Map<String, Object?>> fetchPurchase(String purchaseId) async {
    final rows = await appDatabase.queryTable(
      TableNames.purchases,
      where: 'id = ?',
      whereArgs: <Object?>[purchaseId],
      limit: 1,
    );
    expect(rows, isNotEmpty);
    return rows.single;
  }

  Future<Map<String, Object?>> fetchInventoryStock(
      String productModelId) async {
    final rows = await appDatabase.queryTable(
      TableNames.inventoryStock,
      where: 'product_model_id = ?',
      whereArgs: <Object?>[productModelId],
      limit: 1,
    );
    expect(rows, isNotEmpty);
    return rows.single;
  }

  Future<Map<String, Object?>> fetchSerializedByImei(String imei) async {
    final rows = await appDatabase.queryTable(
      TableNames.serializedStock,
      where: 'imei1 = ?',
      whereArgs: <Object?>[imei],
      limit: 1,
    );
    expect(rows, isNotEmpty);
    return rows.single;
  }

  Future<List<Map<String, Object?>>> fetchPurchaseItems(String purchaseId) {
    return appDatabase.queryTable(
      TableNames.purchaseItems,
      where: 'purchase_id = ?',
      whereArgs: <Object?>[purchaseId],
      orderBy: 'unit_cost ASC',
    );
  }

  Future<int> countRows(String tableName) async {
    final rows = await appDatabase.database.rawQuery(
      'SELECT COUNT(*) AS count FROM $tableName',
    );
    return (rows.single['count']! as num).toInt();
  }

  Future<int> countRowsWhere(
    String tableName, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    final rows = await appDatabase.database.rawQuery(
      'SELECT COUNT(*) AS count FROM $tableName WHERE $where',
      whereArgs,
    );
    return (rows.single['count']! as num).toInt();
  }
}

T _expectSuccess<T>(Result<T> result) {
  expect(result.isSuccess, isTrue, reason: result.asFailure?.error.message);
  return result.asSuccess!.value;
}
