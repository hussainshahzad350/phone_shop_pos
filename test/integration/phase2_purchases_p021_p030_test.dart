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
import 'package:phone_shop_pos/modules/reports/services/operations_workflow_service.dart';

void main() {
  group('PHASE 2 Purchases P-021..P-030', () {
    test('P-021 App restart after purchase keeps stock persisted', () async {
      final rootDirectory = await Directory.systemTemp.createTemp(
        'phone_shop_pos_phase2_p021_',
      );
      final first = await _P2BContext.create(rootDirectory);

      await first.createProduct(
        id: 'prd_p021_accessory',
        name: 'P021 Accessory',
        sku: 'P021-ACC-001',
        purchasePrice: 200,
        salePrice: 260,
        hasImei: false,
      );

      _expectSuccess(
        await first.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p021_accessory',
              productName: 'P021 Accessory',
              hasImei: false,
              quantity: 9,
              unitCost: 200,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 1800,
        ),
      );

      await first.dispose(deleteRoot: false);

      final second = await _P2BContext.create(rootDirectory);
      addTearDown(second.dispose);

      final stock = await second.fetchInventoryStock('prd_p021_accessory');
      expect(stock['quantity'], 9);
      expect(await second.countRows(TableNames.purchases), 1);
    });

    test('P-022 Duplicate save spam results in one purchase only', () async {
      final rootDirectory = await Directory.systemTemp.createTemp(
        'phone_shop_pos_phase2_p022_',
      );
      final primary = await _P2BContext.create(rootDirectory);
      final secondary = await _P2BContext.create(rootDirectory);
      addTearDown(() async {
        await secondary.dispose(deleteRoot: false);
        await primary.dispose();
      });

      await primary.createProduct(
        id: 'prd_p022_phone',
        name: 'P022 Phone',
        sku: 'P022-PHONE-001',
        purchasePrice: 42000,
        salePrice: 47000,
        hasImei: true,
      );

      final results = await Future.wait<Result<dynamic>>(
        <Future<Result<dynamic>>>[
          primary.purchaseRepository.createPurchaseTransaction(
            items: const <PurchaseFormItem>[
              PurchaseFormItem(
                productModelId: 'prd_p022_phone',
                productName: 'P022 Phone',
                hasImei: true,
                imeiEntries: <ImeiEntry>[
                  ImeiEntry(imei1: '356789101234601', costPrice: 42000),
                ],
              ),
            ],
            discount: 0,
            tax: 0,
            paidAmount: 42000,
          ),
          secondary.purchaseRepository.createPurchaseTransaction(
            items: const <PurchaseFormItem>[
              PurchaseFormItem(
                productModelId: 'prd_p022_phone',
                productName: 'P022 Phone',
                hasImei: true,
                imeiEntries: <ImeiEntry>[
                  ImeiEntry(imei1: '356789101234601', costPrice: 42000),
                ],
              ),
            ],
            discount: 0,
            tax: 0,
            paidAmount: 42000,
          ),
        ],
      );

      final successCount = results.where((result) => result.isSuccess).length;
      final failureCount = results.where((result) => result.isFailure).length;

      expect(successCount, 1);
      expect(failureCount, 1);
      expect(await primary.countRows(TableNames.purchases), 1);
      expect(await primary.countRows(TableNames.purchaseItems), 1);
    });

    test('P-023 Save interruption before save causes no corruption', () async {
      final rootDirectory = await Directory.systemTemp.createTemp(
        'phone_shop_pos_phase2_p023_',
      );
      final first = await _P2BContext.create(rootDirectory);

      await first.createProduct(
        id: 'prd_p023_accessory',
        name: 'P023 Accessory',
        sku: 'P023-ACC-001',
        purchasePrice: 100,
        salePrice: 150,
        hasImei: false,
      );

      await first.dispose(deleteRoot: false);

      final second = await _P2BContext.create(rootDirectory);
      addTearDown(second.dispose);

      expect(await second.countRows(TableNames.purchases), 0);
      expect(await second.countRows(TableNames.purchaseItems), 0);
      expect(
        await second.countRowsWhere(
          TableNames.inventoryStock,
          where: 'product_model_id = ?',
          whereArgs: const <Object?>['prd_p023_accessory'],
        ),
        0,
      );
    });

    test('P-024 Purchase with supplier is linked correctly', () async {
      final context = await _P2BContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p024_phone',
        name: 'P024 Phone',
        sku: 'P024-PHONE-001',
        purchasePrice: 50000,
        salePrice: 56000,
        hasImei: true,
      );
      await context.createSupplier(id: 'sup_p024', name: 'Supplier P024');

      final completion = _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p024_phone',
              productName: 'P024 Phone',
              hasImei: true,
              imeiEntries: <ImeiEntry>[
                ImeiEntry(imei1: '356789101234602', costPrice: 50000),
              ],
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 50000,
          supplierId: 'sup_p024',
        ),
      );

      final purchase = await context.fetchPurchase(completion.purchaseId);
      final serialized = await context.fetchSerializedByImei('356789101234602');

      expect(purchase['supplier_id'], 'sup_p024');
      expect(serialized['supplier_id'], 'sup_p024');
    });

    test('P-025 Purchase without supplier follows intentional behavior',
        () async {
      final context = await _P2BContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p025_phone',
        name: 'P025 Phone',
        sku: 'P025-PHONE-001',
        purchasePrice: 47000,
        salePrice: 52000,
        hasImei: true,
      );

      final completion = _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p025_phone',
              productName: 'P025 Phone',
              hasImei: true,
              imeiEntries: <ImeiEntry>[
                ImeiEntry(imei1: '356789101234603', costPrice: 47000),
              ],
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 47000,
          supplierId: null,
        ),
      );

      final purchase = await context.fetchPurchase(completion.purchaseId);
      final serialized = await context.fetchSerializedByImei('356789101234603');

      expect(purchase['supplier_id'], isNull);
      expect(serialized['supplier_id'], isNull);
    });

    test('P-026 Same-name suppliers keep correct linkage by id', () async {
      final context = await _P2BContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p026_phone',
        name: 'P026 Phone',
        sku: 'P026-PHONE-001',
        purchasePrice: 43000,
        salePrice: 49000,
        hasImei: true,
      );
      await context.createSupplier(
        id: 'sup_p026_a',
        name: 'Same Name Supplier',
        phone: '03000000001',
      );
      await context.createSupplier(
        id: 'sup_p026_b',
        name: 'Same Name Supplier',
        phone: '03000000002',
      );

      final first = _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p026_phone',
              productName: 'P026 Phone',
              hasImei: true,
              imeiEntries: <ImeiEntry>[
                ImeiEntry(imei1: '356789101234604', costPrice: 43000),
              ],
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 43000,
          supplierId: 'sup_p026_a',
        ),
      );

      final second = _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p026_phone',
              productName: 'P026 Phone',
              hasImei: true,
              imeiEntries: <ImeiEntry>[
                ImeiEntry(imei1: '356789101234605', costPrice: 43000),
              ],
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 43000,
          supplierId: 'sup_p026_b',
        ),
      );

      final firstPurchase = await context.fetchPurchase(first.purchaseId);
      final secondPurchase = await context.fetchPurchase(second.purchaseId);

      expect(firstPurchase['supplier_id'], 'sup_p026_a');
      expect(secondPurchase['supplier_id'], 'sup_p026_b');
    });

    test('P-027 Supplier search/filter returns expected matches', () async {
      final context = await _P2BContext.createTemporary();
      addTearDown(context.dispose);

      await context.createSupplier(
        id: 'sup_p027_a',
        name: 'Alpha Mobiles',
        phone: '03110000001',
      );
      await context.createSupplier(
        id: 'sup_p027_b',
        name: 'Beta Traders',
        phone: '03110000002',
      );

      final byName = await context.purchaseRepository.searchSuppliers('Alpha');
      final byPhonePrefix =
          await context.purchaseRepository.searchSuppliers('03110000002');

      expect(byName.isSuccess, isTrue);
      expect(byPhonePrefix.isSuccess, isTrue);
      expect(byName.asSuccess!.value.length, 1);
      expect(byName.asSuccess!.value.single.id, 'sup_p027_a');
      expect(byPhonePrefix.asSuccess!.value.length, 1);
      expect(byPhonePrefix.asSuccess!.value.single.id, 'sup_p027_b');
    });

    test('P-028 Purchase history search by supplier is correct', () async {
      final context = await _P2BContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p028_accessory',
        name: 'P028 Accessory',
        sku: 'P028-ACC-001',
        purchasePrice: 100,
        salePrice: 150,
        hasImei: false,
      );
      await context.createSupplier(id: 'sup_p028_alpha', name: 'Alpha Supply');
      await context.createSupplier(id: 'sup_p028_beta', name: 'Beta Supply');

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p028_accessory',
              productName: 'P028 Accessory',
              hasImei: false,
              quantity: 3,
              unitCost: 100,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 300,
          supplierId: 'sup_p028_alpha',
        ),
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p028_accessory',
              productName: 'P028 Accessory',
              hasImei: false,
              quantity: 2,
              unitCost: 100,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 200,
          supplierId: 'sup_p028_beta',
        ),
      );

      final result = _expectSuccess(
        await context.operationsService.searchPurchaseHistory(
          supplierQuery: 'Alpha',
          startDate: null,
          endDate: null,
          limit: 50,
          offset: 0,
        ),
      );

      expect(result, isNotEmpty);
      expect(result.every((row) => row.supplierName.contains('Alpha')), isTrue);
    });

    test('P-029 Purchase history date filter returns accurate rows', () async {
      final context = await _P2BContext.createTemporary();
      addTearDown(context.dispose);

      await context.insertManualPurchase(
        id: 'pur_p029_old',
        purchaseDateUtc: DateTime.utc(2026, 5, 1, 12),
        total: 100,
      );
      await context.insertManualPurchase(
        id: 'pur_p029_new',
        purchaseDateUtc: DateTime.utc(2026, 5, 17, 12),
        total: 200,
      );

      final filtered = _expectSuccess(
        await context.operationsService.searchPurchaseHistory(
          supplierQuery: '',
          startDate: DateTime.utc(2026, 5, 17),
          endDate: DateTime.utc(2026, 5, 17),
          limit: 50,
          offset: 0,
        ),
      );

      final ids = filtered.map((row) => row.purchaseId).toSet();
      expect(ids.contains('pur_p029_new'), isTrue);
      expect(ids.contains('pur_p029_old'), isFalse);
    });

    test('P-030 Reopen purchase details keeps historical accuracy', () async {
      final context = await _P2BContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p030_phone',
        name: 'P030 Phone',
        sku: 'P030-PHONE-001',
        purchasePrice: 39000,
        salePrice: 45000,
        hasImei: true,
      );
      await context.createProduct(
        id: 'prd_p030_acc',
        name: 'P030 Accessory',
        sku: 'P030-ACC-001',
        purchasePrice: 150,
        salePrice: 220,
        hasImei: false,
      );
      await context.createSupplier(id: 'sup_p030', name: 'Supplier P030');

      final completion = _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p030_phone',
              productName: 'P030 Phone',
              hasImei: true,
              imeiEntries: <ImeiEntry>[
                ImeiEntry(imei1: '356789101234606', costPrice: 39000),
              ],
            ),
            PurchaseFormItem(
              productModelId: 'prd_p030_acc',
              productName: 'P030 Accessory',
              hasImei: false,
              quantity: 4,
              unitCost: 150,
            ),
          ],
          discount: 100,
          tax: 50,
          paidAmount: 39550,
          supplierId: 'sup_p030',
          invoiceNumber: 'INV-P030-001',
          notes: 'P030 note',
        ),
      );

      final detail = _expectSuccess(
        await context.operationsService
            .getPurchaseHistoryDetail(completion.purchaseId),
      );

      expect(detail, isNotNull);
      expect(detail!.purchase.purchaseId, completion.purchaseId);
      expect(detail.purchase.invoiceNumber, 'INV-P030-001');
      expect(detail.purchase.supplierName, 'Supplier P030');
      expect(detail.purchase.total, closeTo(39550, 0.0001));
      expect(detail.items.length, 2);

      final hasPhoneLine = detail.items.any(
        (item) =>
            item.productName == 'P030 Phone' && item.imei == '356789101234606',
      );
      final hasAccessoryLine = detail.items.any(
        (item) => item.productName == 'P030 Accessory' && item.quantity == 4,
      );
      expect(hasPhoneLine, isTrue);
      expect(hasAccessoryLine, isTrue);
    });
  });
}

class _P2BContext {
  _P2BContext._({
    required this.rootDirectory,
    required this.appDatabase,
  })  : productRepository = SqliteProductRepository(appDatabase: appDatabase),
        purchaseRepository = SqlitePurchaseRepository(appDatabase: appDatabase),
        operationsService = OperationsWorkflowService(appDatabase: appDatabase);

  final Directory rootDirectory;
  final AppDatabase appDatabase;
  final SqliteProductRepository productRepository;
  final SqlitePurchaseRepository purchaseRepository;
  final OperationsWorkflowService operationsService;

  static Future<_P2BContext> createTemporary() async {
    final rootDirectory = await Directory.systemTemp.createTemp(
      'phone_shop_pos_phase2_p021_p030_',
    );
    return create(rootDirectory);
  }

  static Future<_P2BContext> create(Directory rootDirectory) async {
    final appDatabase = AppDatabase(
      localDatabaseService: SqliteFfiDatabaseService(
        rootDirectory: rootDirectory.path,
      ),
      migrationService: const MigrationService(),
    );
    await appDatabase.initialize(seedDemoData: false);
    return _P2BContext._(
        rootDirectory: rootDirectory, appDatabase: appDatabase);
  }

  Future<void> dispose({bool deleteRoot = true}) async {
    await appDatabase.close();
    if (deleteRoot && await rootDirectory.exists()) {
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

  Future<void> createSupplier({
    required String id,
    required String name,
    String? phone,
  }) async {
    final now = DateTimeHelpers.toSql(DateTime.utc(2026, 5, 17));
    await appDatabase.insert(TableNames.suppliers, <String, Object?>{
      'id': id,
      'name': name,
      'contact_person': null,
      'phone': phone,
      'email': null,
      'address': null,
      'created_at': now,
      'updated_at': now,
      'notes': null,
      'is_active': 1,
    });
  }

  Future<void> insertManualPurchase({
    required String id,
    required DateTime purchaseDateUtc,
    required double total,
  }) async {
    final timestamp = DateTimeHelpers.toSql(purchaseDateUtc);
    await appDatabase.insert(TableNames.purchases, <String, Object?>{
      'id': id,
      'supplier_id': null,
      'invoice_number': 'INV-$id',
      'purchase_date': timestamp,
      'subtotal': total,
      'discount': 0,
      'tax': 0,
      'total': total,
      'paid_amount': total,
      'notes': null,
      'created_at': timestamp,
      'updated_at': timestamp,
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
