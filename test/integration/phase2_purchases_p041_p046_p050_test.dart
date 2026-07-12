import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/services/backup/database_backup_service.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/data/repositories/sqlite_product_repository.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/data/repositories/sqlite_purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/reports/services/operations_workflow_service.dart';

void main() {
  group('PHASE 2 Purchases P-041..P-050', () {
    test('P-041 Very large quantity purchase updates stock correctly',
        () async {
      final context = await _P2DContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p041_bulk',
        name: 'P041 Bulk Cable',
        sku: 'P041-ACC-001',
        purchasePrice: 12.5,
        salePrice: 25,
        hasImei: false,
      );

      final completion = _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p041_bulk',
              productName: 'P041 Bulk Cable',
              hasImei: false,
              quantity: 50000,
              unitCost: 12.5,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 625000,
        ),
      );

      final stock = await context.fetchInventoryStock('prd_p041_bulk');
      expect(completion.quantityItemCount, 1);
      expect(stock['quantity'], 50000);
      expect((stock['unit_cost'] as num).toDouble(), closeTo(12.5, 0.0001));
    });

    test('P-042 Urdu supplier name searches and links correctly', () async {
      final context = await _P2DContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p042_phone',
        name: 'P042 Phone',
        sku: 'P042-PHONE-001',
        purchasePrice: 41000,
        salePrice: 47000,
        hasImei: true,
      );
      await context.createSupplier(
        id: 'sup_p042_urdu',
        name: 'درزی موبائل سپلائر',
        phone: '03001234567',
      );

      final search = await context.purchaseRepository.searchSuppliers('موبائل');
      expect(search.isSuccess, isTrue);
      expect(search.asSuccess!.value.single.id, 'sup_p042_urdu');

      final completion = _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p042_phone',
              productName: 'P042 Phone',
              hasImei: true,
              imeiEntries: <ImeiEntry>[
                ImeiEntry(imei1: '356789101234610', costPrice: 41000),
              ],
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 41000,
          supplierId: 'sup_p042_urdu',
        ),
      );

      final purchase = await context.fetchPurchase(completion.purchaseId);
      expect(purchase['supplier_id'], 'sup_p042_urdu');
    });

    test('P-043 Long supplier name remains searchable and linkable', () async {
      final context = await _P2DContext.createTemporary();
      addTearDown(context.dispose);

      final longName = 'Long Supplier Name ${'A' * 180}';

      await context.createProduct(
        id: 'prd_p043_phone',
        name: 'P043 Phone',
        sku: 'P043-PHONE-001',
        purchasePrice: 52000,
        salePrice: 58000,
        hasImei: true,
      );
      await context.createSupplier(
        id: 'sup_p043_long',
        name: longName,
      );

      final search =
          await context.purchaseRepository.searchSuppliers('Long Supplier');
      expect(search.isSuccess, isTrue);
      expect(search.asSuccess!.value.single.id, 'sup_p043_long');

      final completion = _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p043_phone',
              productName: 'P043 Phone',
              hasImei: true,
              imeiEntries: <ImeiEntry>[
                ImeiEntry(imei1: '356789101234611', costPrice: 52000),
              ],
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 52000,
          supplierId: 'sup_p043_long',
        ),
      );

      final purchase = await context.fetchPurchase(completion.purchaseId);
      expect(purchase['supplier_id'], 'sup_p043_long');
    });

    test('P-044 Rapid repeated searching stays fast and accurate', () async {
      final context = await _P2DContext.createTemporary();
      addTearDown(context.dispose);

      for (var index = 0; index < 40; index++) {
        await context.createSupplier(
          id: 'sup_p044_$index',
          name: 'Rapid Search Supplier $index',
          phone: '0314000${index.toString().padLeft(3, '0')}',
        );
        await context.createProduct(
          id: 'prd_p044_$index',
          name: 'Rapid Search Product $index',
          sku: 'P044-$index',
          purchasePrice: (100 + index).toDouble(),
          salePrice: (150 + index).toDouble(),
          hasImei: false,
        );
      }

      final stopwatch = Stopwatch()..start();
      for (var index = 0; index < 250; index++) {
        final suppliers = await context.purchaseRepository.searchSuppliers(
          'Rapid Search',
          limit: 20,
        );
        final products = await context.purchaseRepository.searchProducts(
          'Rapid Search',
          limit: 20,
        );

        expect(suppliers.isSuccess, isTrue);
        expect(products.isSuccess, isTrue);
      }
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(4500));
    });

    test('P-045 Repeated purchases preserve weighted average cost', () async {
      final context = await _P2DContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p045_acc',
        name: 'P045 Accessory',
        sku: 'P045-ACC-001',
        purchasePrice: 100,
        salePrice: 180,
        hasImei: false,
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p045_acc',
              productName: 'P045 Accessory',
              hasImei: false,
              quantity: 8,
              unitCost: 110,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 880,
        ),
      );
      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p045_acc',
              productName: 'P045 Accessory',
              hasImei: false,
              quantity: 12,
              unitCost: 250,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 3000,
        ),
      );
      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p045_acc',
              productName: 'P045 Accessory',
              hasImei: false,
              quantity: 5,
              unitCost: 170,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 850,
        ),
      );

      final stock = await context.fetchInventoryStock('prd_p045_acc');
      expect(stock['quantity'], 25);
      expect((stock['unit_cost'] as num).toDouble(), closeTo(189.2, 0.0001));
    });

    test('P-046 Multi-line mixed purchase stress stays consistent', () async {
      final context = await _P2DContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p046_phone_a',
        name: 'P046 Phone A',
        sku: 'P046-PHONE-A',
        purchasePrice: 40000,
        salePrice: 46000,
        hasImei: true,
      );
      await context.createProduct(
        id: 'prd_p046_phone_b',
        name: 'P046 Phone B',
        sku: 'P046-PHONE-B',
        purchasePrice: 45000,
        salePrice: 51000,
        hasImei: true,
      );
      await context.createProduct(
        id: 'prd_p046_acc_a',
        name: 'P046 Cable',
        sku: 'P046-ACC-A',
        purchasePrice: 150,
        salePrice: 250,
        hasImei: false,
      );
      await context.createProduct(
        id: 'prd_p046_acc_b',
        name: 'P046 Charger',
        sku: 'P046-ACC-B',
        purchasePrice: 90,
        salePrice: 180,
        hasImei: false,
      );

      final completion = _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p046_phone_a',
              productName: 'P046 Phone A',
              hasImei: true,
              imeiEntries: <ImeiEntry>[
                ImeiEntry(imei1: '356789101234612', costPrice: 40000),
              ],
            ),
            PurchaseFormItem(
              productModelId: 'prd_p046_phone_b',
              productName: 'P046 Phone B',
              hasImei: true,
              imeiEntries: <ImeiEntry>[
                ImeiEntry(imei1: '356789101234613', costPrice: 45000),
              ],
            ),
            PurchaseFormItem(
              productModelId: 'prd_p046_acc_a',
              productName: 'P046 Cable',
              hasImei: false,
              quantity: 12,
              unitCost: 150,
            ),
            PurchaseFormItem(
              productModelId: 'prd_p046_acc_b',
              productName: 'P046 Charger',
              hasImei: false,
              quantity: 7,
              unitCost: 90,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 0,
        ),
      );

      expect(completion.serializedItemCount, 2);
      expect(completion.quantityItemCount, 2);

      expect((await context.fetchInventoryStock('prd_p046_acc_a'))['quantity'],
          12);
      expect(
          (await context.fetchInventoryStock('prd_p046_acc_b'))['quantity'], 7);
      expect(await context.countRows(TableNames.serializedStock), 2);
      expect(await context.countRows(TableNames.purchaseItems), 4);
    });

    test('P-050 Post-restore purchases continue working correctly', () async {
      final context = await _P2DContext.createTemporary();
      addTearDown(context.dispose);

      await context.createProduct(
        id: 'prd_p050_acc',
        name: 'P050 Accessory',
        sku: 'P050-ACC-001',
        purchasePrice: 300,
        salePrice: 480,
        hasImei: false,
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p050_acc',
              productName: 'P050 Accessory',
              hasImei: false,
              quantity: 4,
              unitCost: 300,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 1200,
        ),
      );

      final backup = _expectSuccess(
        await context.backupService.createBackup(
          directoryPath: '${context.rootDirectory.path}/backups',
        ),
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p050_acc',
              productName: 'P050 Accessory',
              hasImei: false,
              quantity: 6,
              unitCost: 320,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 1920,
        ),
      );

      expect(
          (await context.fetchInventoryStock('prd_p050_acc'))['quantity'], 10);

      _expectSuccess(await context.backupService.restoreBackup(backup.path));

      expect(
          (await context.fetchInventoryStock('prd_p050_acc'))['quantity'], 4);
      expect(await context.countRows(TableNames.purchases), 1);

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_p050_acc',
              productName: 'P050 Accessory',
              hasImei: false,
              quantity: 2,
              unitCost: 310,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 620,
        ),
      );

      expect(
          (await context.fetchInventoryStock('prd_p050_acc'))['quantity'], 6);
      expect(await context.countRows(TableNames.purchases), 2);
    });
  });
}

class _P2DContext {
  _P2DContext._({
    required this.rootDirectory,
    required this.appDatabase,
  })  : productRepository = SqliteProductRepository(appDatabase: appDatabase),
        purchaseRepository = SqlitePurchaseRepository(appDatabase: appDatabase),
        operationsService = OperationsWorkflowService(appDatabase: appDatabase),
        backupService = DatabaseBackupService(appDatabase: appDatabase);

  final Directory rootDirectory;
  final AppDatabase appDatabase;
  final SqliteProductRepository productRepository;
  final SqlitePurchaseRepository purchaseRepository;
  final OperationsWorkflowService operationsService;
  final DatabaseBackupService backupService;

  static Future<_P2DContext> createTemporary() async {
    final rootDirectory = await Directory.systemTemp.createTemp(
      'phone_shop_pos_phase2_p041_p050_',
    );
    final appDatabase = AppDatabase(
      localDatabaseService: SqliteFfiDatabaseService(
        rootDirectory: rootDirectory.path,
      ),
      migrationService: const MigrationService(),
    );
    await appDatabase.initialize(seedDemoData: false);
    return _P2DContext._(
        rootDirectory: rootDirectory, appDatabase: appDatabase);
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

  Future<int> countRows(String tableName) async {
    final rows = await appDatabase.database.rawQuery(
      'SELECT COUNT(*) AS count FROM $tableName',
    );
    return (rows.single['count']! as num).toInt();
  }
}

T _expectSuccess<T>(Result<T> result) {
  expect(result.isSuccess, isTrue, reason: result.asFailure?.error.message);
  return result.asSuccess!.value;
}
