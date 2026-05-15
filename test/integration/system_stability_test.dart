import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/services/backup/database_backup_service.dart';
import 'package:phone_shop_pos/modules/inventory/data/repositories/sqlite_product_repository.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/data/repositories/sqlite_purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/data/repositories/sqlite_sales_repository.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';

void main() {
  group('System stability hardening', () {
    test('covers purchase → stock → sale → restore lifecycle', () async {
      final context = await _TestContext.createTemporary();
      addTearDown(context.dispose);

      final phone = await context.createProduct(
        id: 'prd_phone_lifecycle',
        name: 'Lifecycle Phone',
        sku: 'PHONE-LIFE-001',
        purchasePrice: 50000,
        salePrice: 56000,
        hasImei: true,
      );
      final accessory = await context.createProduct(
        id: 'prd_accessory_lifecycle',
        name: 'Lifecycle Cable',
        sku: 'ACC-LIFE-001',
        purchasePrice: 200,
        salePrice: 350,
        hasImei: false,
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: <PurchaseFormItem>[
            const PurchaseFormItem(
              productModelId: 'prd_phone_lifecycle',
              productName: 'Lifecycle Phone',
              hasImei: true,
              imeiEntries: <ImeiEntry>[
                ImeiEntry(
                  imei1: '356789101234561',
                  imei2: '356789101234579',
                  serialNumber: 'PHONE-LIFE-001',
                  costPrice: 50000,
                  sellingPrice: 56000,
                ),
              ],
            ),
            const PurchaseFormItem(
              productModelId: 'prd_accessory_lifecycle',
              productName: 'Lifecycle Cable',
              hasImei: false,
              quantity: 5,
              unitCost: 200,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 51000,
        ),
      );

      final serializedBeforeSale = await context.fetchSerializedStock(phone.id);
      expect(serializedBeforeSale['stock_status'], 'in_stock');
      expect(await context.fetchInventoryQuantity(accessory.id), 5);

      final backup = _expectSuccess(
        await context.backupService.createBackup(
          directoryPath: '${context.rootDirectory.path}/backups',
        ),
      );

      _expectSuccess(
        await context.salesRepository.createSaleTransaction(
          items: <CartItemEntity>[
            CartItemEntity(
              productModelId: phone.id,
              productName: phone.name,
              hasImei: true,
              quantity: 1,
              unitPrice: 56000,
              serializedStockId: serializedBeforeSale['id']! as String,
              imei: serializedBeforeSale['imei1']! as String,
            ),
            CartItemEntity(
              productModelId: accessory.id,
              productName: accessory.name,
              hasImei: false,
              quantity: 2,
              unitPrice: 350,
            ),
          ],
          totals: const SaleTotalsEntity(
            subtotal: 56700,
            discount: 0,
            tax: 0,
            total: 56700,
            paidAmount: 56700,
          ),
          saleDate: DateTime.utc(2026, 5, 15),
        ),
      );

      expect((await context.fetchSerializedStock(phone.id))['stock_status'],
          'sold');
      expect(await context.fetchInventoryQuantity(accessory.id), 3);
      expect(await context.countRows(TableNames.sales), 1);
      expect(await context.countRows(TableNames.saleItems), 2);

      _expectSuccess(await context.backupService.restoreBackup(backup.path));

      expect((await context.fetchSerializedStock(phone.id))['stock_status'],
          'in_stock');
      expect(await context.fetchInventoryQuantity(accessory.id), 5);
      expect(await context.countRows(TableNames.sales), 0);
      expect(await context.countRows(TableNames.saleItems), 0);
      expect(await context.countRows(TableNames.purchases), 1);
      expect(await context.countRows(TableNames.purchaseItems), 2);
    });

    test('rolls back a mixed sale when a later line item fails', () async {
      final context = await _TestContext.createTemporary();
      addTearDown(context.dispose);

      final phone = await context.createProduct(
        id: 'prd_phone_rollback',
        name: 'Rollback Phone',
        sku: 'PHONE-ROLL-001',
        purchasePrice: 42000,
        salePrice: 47000,
        hasImei: true,
      );
      final accessory = await context.createProduct(
        id: 'prd_accessory_rollback',
        name: 'Rollback Charger',
        sku: 'ACC-ROLL-001',
        purchasePrice: 700,
        salePrice: 1200,
        hasImei: false,
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: <PurchaseFormItem>[
            const PurchaseFormItem(
              productModelId: 'prd_phone_rollback',
              productName: 'Rollback Phone',
              hasImei: true,
              imeiEntries: <ImeiEntry>[
                ImeiEntry(
                  imei1: '356789101234588',
                  costPrice: 42000,
                  sellingPrice: 47000,
                ),
              ],
            ),
            const PurchaseFormItem(
              productModelId: 'prd_accessory_rollback',
              productName: 'Rollback Charger',
              hasImei: false,
              quantity: 1,
              unitCost: 700,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 42700,
        ),
      );

      final serializedStock = await context.fetchSerializedStock(phone.id);
      final failedSale = await context.salesRepository.createSaleTransaction(
        items: <CartItemEntity>[
          CartItemEntity(
            productModelId: phone.id,
            productName: phone.name,
            hasImei: true,
            quantity: 1,
            unitPrice: 47000,
            serializedStockId: serializedStock['id']! as String,
            imei: serializedStock['imei1']! as String,
          ),
          CartItemEntity(
            productModelId: accessory.id,
            productName: accessory.name,
            hasImei: false,
            quantity: 2,
            unitPrice: 1200,
          ),
        ],
        totals: const SaleTotalsEntity(
          subtotal: 49400,
          discount: 0,
          tax: 0,
          total: 49400,
          paidAmount: 49400,
        ),
        saleDate: DateTime.utc(2026, 5, 15),
      );

      expect(failedSale.isFailure, isTrue);
      expect((await context.fetchSerializedStock(phone.id))['stock_status'],
          'in_stock');
      expect(await context.fetchInventoryQuantity(accessory.id), 1);
      expect(await context.countRows(TableNames.sales), 0);
      expect(await context.countRows(TableNames.saleItems), 0);
    });

    test('preserves stock invariants under concurrent sale contention',
        () async {
      final rootDirectory = await Directory.systemTemp.createTemp(
        'phone_shop_pos_concurrency_',
      );
      final primaryContext = await _TestContext.create(rootDirectory);
      final secondaryContext = await _TestContext.create(rootDirectory);
      addTearDown(() async {
        await secondaryContext.dispose(deleteRoot: false);
        await primaryContext.dispose();
      });

      final accessory = await primaryContext.createProduct(
        id: 'prd_accessory_concurrent',
        name: 'Concurrent Cable',
        sku: 'ACC-CON-001',
        purchasePrice: 150,
        salePrice: 250,
        hasImei: false,
      );

      _expectSuccess(
        await primaryContext.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_accessory_concurrent',
              productName: 'Concurrent Cable',
              hasImei: false,
              quantity: 1,
              unitCost: 150,
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 150,
        ),
      );

      final results =
          await Future.wait<Result<dynamic>>(<Future<Result<dynamic>>>[
        primaryContext.salesRepository.createSaleTransaction(
          items: <CartItemEntity>[
            CartItemEntity(
              productModelId: accessory.id,
              productName: accessory.name,
              hasImei: false,
              quantity: 1,
              unitPrice: 250,
            ),
          ],
          totals: const SaleTotalsEntity(
            subtotal: 250,
            discount: 0,
            tax: 0,
            total: 250,
            paidAmount: 250,
          ),
          saleDate: DateTime.utc(2026, 5, 15),
        ),
        secondaryContext.salesRepository.createSaleTransaction(
          items: <CartItemEntity>[
            CartItemEntity(
              productModelId: accessory.id,
              productName: accessory.name,
              hasImei: false,
              quantity: 1,
              unitPrice: 250,
            ),
          ],
          totals: const SaleTotalsEntity(
            subtotal: 250,
            discount: 0,
            tax: 0,
            total: 250,
            paidAmount: 250,
          ),
          saleDate: DateTime.utc(2026, 5, 15),
        ),
      ]);

      final successCount = results.where((result) => result.isSuccess).length;
      final failureCount = results.where((result) => result.isFailure).length;

      expect(successCount, 1);
      expect(failureCount, 1);
      expect(await primaryContext.fetchInventoryQuantity(accessory.id), 0);
      expect(await primaryContext.countRows(TableNames.sales), 1);
      expect(await primaryContext.countRows(TableNames.saleItems), 1);
    });

    test('rejects corrupted restore input without touching live data',
        () async {
      final context = await _TestContext.createTemporary();
      addTearDown(context.dispose);

      final phone = await context.createProduct(
        id: 'prd_phone_corrupt_restore',
        name: 'Corrupt Restore Phone',
        sku: 'PHONE-COR-001',
        purchasePrice: 61000,
        salePrice: 68000,
        hasImei: true,
      );

      _expectSuccess(
        await context.purchaseRepository.createPurchaseTransaction(
          items: const <PurchaseFormItem>[
            PurchaseFormItem(
              productModelId: 'prd_phone_corrupt_restore',
              productName: 'Corrupt Restore Phone',
              hasImei: true,
              imeiEntries: <ImeiEntry>[
                ImeiEntry(
                  imei1: '356789101234596',
                  costPrice: 61000,
                  sellingPrice: 68000,
                ),
              ],
            ),
          ],
          discount: 0,
          tax: 0,
          paidAmount: 61000,
        ),
      );

      final serializedStock = await context.fetchSerializedStock(phone.id);
      _expectSuccess(
        await context.salesRepository.createSaleTransaction(
          items: <CartItemEntity>[
            CartItemEntity(
              productModelId: phone.id,
              productName: phone.name,
              hasImei: true,
              quantity: 1,
              unitPrice: 68000,
              serializedStockId: serializedStock['id']! as String,
              imei: serializedStock['imei1']! as String,
            ),
          ],
          totals: const SaleTotalsEntity(
            subtotal: 68000,
            discount: 0,
            tax: 0,
            total: 68000,
            paidAmount: 68000,
          ),
          saleDate: DateTime.utc(2026, 5, 15),
        ),
      );

      final corruptBackupPath =
          '${context.rootDirectory.path}/corrupt_backup.db';
      await File(corruptBackupPath).writeAsBytes(<int>[1, 2, 3, 4, 5]);

      final restoreResult = await context.backupService.restoreBackup(
        corruptBackupPath,
      );

      expect(restoreResult.isFailure, isTrue);
      expect((await context.fetchSerializedStock(phone.id))['stock_status'],
          'sold');
      expect(await context.countRows(TableNames.sales), 1);
      expect(await context.countRows(TableNames.saleItems), 1);
    });
  });
}

class _TestContext {
  _TestContext._({
    required this.rootDirectory,
    required this.appDatabase,
  })  : productRepository = SqliteProductRepository(appDatabase: appDatabase),
        purchaseRepository = SqlitePurchaseRepository(appDatabase: appDatabase),
        salesRepository = SqliteSalesRepository(appDatabase: appDatabase),
        backupService = DatabaseBackupService(appDatabase: appDatabase);

  final Directory rootDirectory;
  final AppDatabase appDatabase;
  final SqliteProductRepository productRepository;
  final SqlitePurchaseRepository purchaseRepository;
  final SqliteSalesRepository salesRepository;
  final DatabaseBackupService backupService;

  static Future<_TestContext> createTemporary() async {
    final rootDirectory = await Directory.systemTemp.createTemp(
      'phone_shop_pos_system_',
    );
    return create(rootDirectory);
  }

  static Future<_TestContext> create(Directory rootDirectory) async {
    final appDatabase = AppDatabase(
      localDatabaseService: SqliteFfiDatabaseService(
        rootDirectory: rootDirectory.path,
      ),
      migrationService: const MigrationService(),
    );
    await appDatabase.initialize(seedDemoData: false);
    return _TestContext._(
      rootDirectory: rootDirectory,
      appDatabase: appDatabase,
    );
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
    final timestamp = DateTime.utc(2026, 5, 15);
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
          createdAt: timestamp,
          updatedAt: timestamp,
        ),
      ),
    );
  }

  Future<Map<String, Object?>> fetchSerializedStock(
      String productModelId) async {
    final rows = await appDatabase.queryTable(
      TableNames.serializedStock,
      where: 'product_model_id = ?',
      whereArgs: <Object?>[productModelId],
      limit: 1,
    );
    expect(rows, isNotEmpty);
    return rows.first;
  }

  Future<int> fetchInventoryQuantity(String productModelId) async {
    final rows = await appDatabase.queryTable(
      TableNames.inventoryStock,
      where: 'product_model_id = ?',
      whereArgs: <Object?>[productModelId],
      limit: 1,
    );
    expect(rows, isNotEmpty);
    return rows.first['quantity']! as int;
  }

  Future<int> countRows(String tableName) async {
    final rows = await appDatabase.database.rawQuery(
      'SELECT COUNT(*) AS count FROM $tableName',
    );
    return (rows.first['count']! as num).toInt();
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
