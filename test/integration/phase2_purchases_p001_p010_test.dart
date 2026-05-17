import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/data/repositories/sqlite_product_repository.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/data/repositories/sqlite_purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/purchases/services/purchase_service.dart';

void main() {
  group('PHASE 2 Purchases P-001..P-010', () {
    test('P-001 Simple phone purchase (single IMEI)', () async {
      final context = await _Phase2BatchContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p001_phone',
        name: 'P001 Phone',
        sku: 'P001-PHONE-001',
        purchasePrice: 50000,
        salePrice: 56000,
        hasImei: true,
      );
      await context.createSupplier(
        id: 'sup_p001',
        name: 'Supplier P001',
      );

      final completion = _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p001_phone',
              productName: 'P001 Phone',
              hasImei: true,
              imeiEntries: <ImeiEntry>[
                ImeiEntry(
                  imei1: '356789101234561',
                  costPrice: 50000,
                  sellingPrice: 56000,
                ),
              ],
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 50000,
          supplierId: 'sup_p001',
        ),
      );

      final purchaseRow = await context.fetchPurchase(completion.purchaseId);
      final serializedRows = await context.fetchSerializedStockRows(
        'prd_p001_phone',
      );

      expect(purchaseRow['supplier_id'], 'sup_p001');
      expect(serializedRows.length, 1);
      expect(serializedRows.single['imei1'], '356789101234561');
      expect(serializedRows.single['stock_status'], 'in_stock');
      expect(await context.countRows(TableNames.purchases), 1);
      expect(await context.countRows(TableNames.purchaseItems), 1);
    });

    test('P-002 Accessory purchase (quantity stock)', () async {
      final context = await _Phase2BatchContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p002_accessory',
        name: 'P002 Cable',
        sku: 'P002-ACC-001',
        purchasePrice: 100,
        salePrice: 150,
        hasImei: false,
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p002_accessory',
              productName: 'P002 Cable',
              hasImei: false,
              quantity: 10,
              unitCost: 120,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 1200,
        ),
      );

      final stock = await context.fetchInventoryStock('prd_p002_accessory');
      expect(stock['quantity'], 10);
      expect((stock['unit_cost'] as num).toDouble(), closeTo(120, 0.0001));
    });

    test('P-003 Mixed purchase (phone + accessory)', () async {
      final context = await _Phase2BatchContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p003_phone',
        name: 'P003 Phone',
        sku: 'P003-PHONE-001',
        purchasePrice: 42000,
        salePrice: 47000,
        hasImei: true,
      );
      await context.createProduct(
        id: 'prd_p003_acc',
        name: 'P003 Charger',
        sku: 'P003-ACC-001',
        purchasePrice: 300,
        salePrice: 500,
        hasImei: false,
      );

      final completion = _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p003_phone',
              productName: 'P003 Phone',
              hasImei: true,
              imeiEntries: <ImeiEntry>[
                ImeiEntry(imei1: '356789101234562', costPrice: 42000),
              ],
            ),
            PurchaseFormItem(
              productModelId: 'prd_p003_acc',
              productName: 'P003 Charger',
              hasImei: false,
              quantity: 5,
              unitCost: 300,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 43500,
        ),
      );

      expect(completion.serializedItemCount, 1);
      expect(completion.quantityItemCount, 1);
      expect(await context.countRows(TableNames.purchases), 1);
      expect(await context.countRows(TableNames.purchaseItems), 2);
      expect(
          (await context.fetchSerializedStockRows('prd_p003_phone')).length, 1);
      expect(
          (await context.fetchInventoryStock('prd_p003_acc'))['quantity'], 5);
    });

    test('P-004 Multiple phones in one purchase', () async {
      final context = await _Phase2BatchContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p004_phone',
        name: 'P004 Phone',
        sku: 'P004-PHONE-001',
        purchasePrice: 38000,
        salePrice: 43000,
        hasImei: true,
      );

      final completion = _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p004_phone',
              productName: 'P004 Phone',
              hasImei: true,
              imeiEntries: <ImeiEntry>[
                ImeiEntry(imei1: '356789101234563', costPrice: 38000),
                ImeiEntry(imei1: '356789101234564', costPrice: 38000),
                ImeiEntry(imei1: '356789101234565', costPrice: 38000),
              ],
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 114000,
        ),
      );

      final purchase = await context.fetchPurchase(completion.purchaseId);
      final rows = await context.fetchSerializedStockRows('prd_p004_phone');
      final imeis = rows.map((row) => row['imei1']! as String).toSet();

      expect(rows.length, 3);
      expect(imeis.length, 3);
      expect((purchase['total'] as num).toDouble(), closeTo(114000, 0.0001));
    });

    test('P-005 Multi-item accessory purchase totals', () async {
      final context = await _Phase2BatchContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p005_acc_a',
        name: 'P005 Charger',
        sku: 'P005-ACC-A',
        purchasePrice: 200,
        salePrice: 280,
        hasImei: false,
      );
      await context.createProduct(
        id: 'prd_p005_acc_b',
        name: 'P005 Cable',
        sku: 'P005-ACC-B',
        purchasePrice: 80,
        salePrice: 140,
        hasImei: false,
      );

      final completion = _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p005_acc_a',
              productName: 'P005 Charger',
              hasImei: false,
              quantity: 10,
              unitCost: 200,
            ),
            PurchaseFormItem(
              productModelId: 'prd_p005_acc_b',
              productName: 'P005 Cable',
              hasImei: false,
              quantity: 5,
              unitCost: 80,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 2400,
        ),
      );

      final purchase = await context.fetchPurchase(completion.purchaseId);
      final itemRows = await context.fetchPurchaseItems(completion.purchaseId);

      expect(itemRows.length, 2);
      expect(
          (itemRows[0]['line_total'] as num).toDouble(), closeTo(2000, 0.0001));
      expect(
          (itemRows[1]['line_total'] as num).toDouble(), closeTo(400, 0.0001));
      expect((purchase['subtotal'] as num).toDouble(), closeTo(2400, 0.0001));
      expect((purchase['total'] as num).toDouble(), closeTo(2400, 0.0001));
    });

    test('P-006 Duplicate IMEI within same purchase is blocked immediately',
        () {
      const baseItem = PurchaseFormItem(
        productModelId: 'prd_p006_phone',
        productName: 'P006 Phone',
        hasImei: true,
        imeiEntries: <ImeiEntry>[
          ImeiEntry(imei1: '356789101234566', costPrice: 41000),
        ],
      );
      final service = PurchaseService(
        repository: SqlitePurchaseRepository(
          appDatabase: AppDatabase(
            localDatabaseService: SqliteFfiDatabaseService(
              rootDirectory: Directory.systemTemp.path,
            ),
            migrationService: const MigrationService(),
          ),
        ),
      );

      final result = service.addImeiEntry(
        items: const <PurchaseFormItem>[baseItem],
        index: 0,
        entry: const ImeiEntry(imei1: '356789101234566', costPrice: 41000),
      );

      expect(result.isFailure, isTrue);
      expect(result.asFailure?.error.code, 'duplicate_imei');
    });

    test('P-007 Duplicate IMEI across database is blocked', () async {
      final context = await _Phase2BatchContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p007_phone',
        name: 'P007 Phone',
        sku: 'P007-PHONE-001',
        purchasePrice: 45000,
        salePrice: 50000,
        hasImei: true,
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p007_phone',
              productName: 'P007 Phone',
              hasImei: true,
              imeiEntries: <ImeiEntry>[
                ImeiEntry(imei1: '356789101234567', costPrice: 45000),
              ],
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 45000,
        ),
      );

      final secondAttempt =
          await context.purchaseRepository.createPurchaseTransaction(
        items: const <PurchaseFormItem>[
          PurchaseFormItem(
            productModelId: 'prd_p007_phone',
            productName: 'P007 Phone',
            hasImei: true,
            imeiEntries: <ImeiEntry>[
              ImeiEntry(imei1: '356789101234567', costPrice: 45000),
            ],
          ),
        ],
        discount: 0,
        tax: 0,
        paidAmount: 45000,
      );

      expect(secondAttempt.isFailure, isTrue);
      expect(await context.countRows(TableNames.purchases), 1);
    });

    test('P-008 IMEI1 == IMEI2 validation is blocked', () async {
      final context = await _Phase2BatchContext.createTemporary();
      addTearDown(context.dispose);

      final service = PurchaseService(repository: context.purchaseRepository);
      final result = await service.validateImeiEntry(
        entry: const ImeiEntry(
          imei1: '356789101234568',
          imei2: '356789101234568',
          costPrice: 45000,
        ),
        currentItems: const <PurchaseFormItem>[],
      );

      expect(result.isFailure, isTrue);
      expect(result.asFailure?.error.code, 'duplicate_imei_pair');
    });

    test('P-009 Empty IMEI attempt is blocked', () async {
      final context = await _Phase2BatchContext.createTemporary();
      addTearDown(context.dispose);

      final service = PurchaseService(repository: context.purchaseRepository);
      final result = await service.validateImei(
        imei: '   ',
        currentItems: const <PurchaseFormItem>[],
      );

      expect(result.isFailure, isTrue);
      expect(result.asFailure?.error.code, 'empty_imei');
    });

    test('P-010 Invalid IMEI format attempts are blocked', () async {
      final context = await _Phase2BatchContext.createTemporary();
      addTearDown(context.dispose);

      final service = PurchaseService(repository: context.purchaseRepository);

      final tooShort = await service.validateImei(
        imei: '12345',
        currentItems: const <PurchaseFormItem>[],
      );
      final alphabetic = await service.validateImei(
        imei: '35678910ABCD123',
        currentItems: const <PurchaseFormItem>[],
      );
      final malformed = await service.validateImei(
        imei: '35678-910123456',
        currentItems: const <PurchaseFormItem>[],
      );

      expect(tooShort.isFailure, isTrue);
      expect(alphabetic.isFailure, isTrue);
      expect(malformed.isFailure, isTrue);
      expect(tooShort.asFailure?.error.code, 'invalid_imei_format');
      expect(alphabetic.asFailure?.error.code, 'invalid_imei_format');
      expect(malformed.asFailure?.error.code, 'invalid_imei_format');
    });
  });
}

class _Phase2BatchContext {
  _Phase2BatchContext._({
    required this.rootDirectory,
    required this.appDatabase,
  })  : productRepository = SqliteProductRepository(appDatabase: appDatabase),
        purchaseRepository = SqlitePurchaseRepository(appDatabase: appDatabase);

  final Directory rootDirectory;
  final AppDatabase appDatabase;
  final SqliteProductRepository productRepository;
  final SqlitePurchaseRepository purchaseRepository;

  static Future<_Phase2BatchContext> createTemporary() async {
    final rootDirectory = await Directory.systemTemp.createTemp(
      'phone_shop_pos_phase2_p001_p010_',
    );
    final appDatabase = AppDatabase(
      localDatabaseService: SqliteFfiDatabaseService(
        rootDirectory: rootDirectory.path,
      ),
      migrationService: const MigrationService(),
    );
    await appDatabase.initialize(seedDemoData: false);
    return _Phase2BatchContext._(
      rootDirectory: rootDirectory,
      appDatabase: appDatabase,
    );
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
          sku: sku,
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

  Future<void> createSupplier({
    required String id,
    required String name,
  }) async {
    final now = DateTimeHelpers.toSql(DateTime.utc(2026, 5, 17));
    await appDatabase.insert(TableNames.suppliers, <String, Object?>{
      'id': id,
      'name': name,
      'contact_person': null,
      'phone': null,
      'email': null,
      'address': null,
      'created_at': now,
      'updated_at': now,
      'notes': null,
      'is_active': 1,
    });
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

  Future<List<Map<String, Object?>>> fetchPurchaseItems(
      String purchaseId) async {
    return appDatabase.queryTable(
      TableNames.purchaseItems,
      where: 'purchase_id = ?',
      whereArgs: <Object?>[purchaseId],
      orderBy: 'line_total DESC',
    );
  }

  Future<List<Map<String, Object?>>> fetchSerializedStockRows(
    String productModelId,
  ) {
    return appDatabase.queryTable(
      TableNames.serializedStock,
      where: 'product_model_id = ?',
      whereArgs: <Object?>[productModelId],
      orderBy: 'imei1 ASC',
    );
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

  Future<int> countRows(String tableName) async {
    final rows = await appDatabase.database.rawQuery(
      'SELECT COUNT(*) AS count FROM $tableName',
    );
    return (rows.single['count']! as num).toInt();
  }
}

T _expectSuccess<T>(Result<T> result) {
  expect(
    result.isSuccess,
    isTrue,
    reason: result.asFailure?.error.message,
  );
  return result.asSuccess!.value;
}
