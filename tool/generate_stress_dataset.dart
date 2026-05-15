import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_print_models.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';

Future<void> main(List<String> arguments) async {
  final options = _CliOptions.parse(arguments);
  final rootDirectory = Directory(options.rootDirectory);
  await rootDirectory.create(recursive: true);

  if (options.resetDatabase) {
    final databasePath = p.join(rootDirectory.path, 'phone_shop_pos.db');
    for (final suffix in <String>['', '-wal', '-shm', '-journal']) {
      final file = File('$databasePath$suffix');
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  final appDatabase = AppDatabase(
    localDatabaseService: SqliteFfiDatabaseService(rootDirectory: rootDirectory.path),
    migrationService: const MigrationService(),
  );
  await appDatabase.initialize(seedDemoData: false);

  try {
    final generator = _StressDatasetGenerator(
      appDatabase: appDatabase,
      options: options,
    );
    await generator.run();
  } finally {
    await appDatabase.close();
  }
}

class _CliOptions {
  const _CliOptions({
    required this.rootDirectory,
    required this.resetDatabase,
    required this.serializedRows,
    required this.salesRows,
    required this.printJobs,
  });

  final String rootDirectory;
  final bool resetDatabase;
  final int serializedRows;
  final int salesRows;
  final int printJobs;

  static _CliOptions parse(List<String> arguments) {
    final values = <String, String>{};
    for (final argument in arguments) {
      if (!argument.startsWith('--') || !argument.contains('=')) {
        continue;
      }
      final parts = argument.substring(2).split('=');
      values[parts.first] = parts.sublist(1).join('=');
    }

    return _CliOptions(
      rootDirectory: values['root'] ?? Directory.current.path,
      resetDatabase: values['reset'] == 'true',
      serializedRows: int.tryParse(values['serialized'] ?? '') ?? 500000,
      salesRows: int.tryParse(values['sales'] ?? '') ?? 100000,
      printJobs: int.tryParse(values['print-jobs'] ?? '') ?? 5000,
    );
  }
}

class _StressDatasetGenerator {
  _StressDatasetGenerator({
    required this.appDatabase,
    required this.options,
  });

  final AppDatabase appDatabase;
  final _CliOptions options;

  static const int _serializedProductCount = 40;
  static const int _accessoryProductCount = 120;
  static const int _customerCount = 2500;
  static const int _supplierCount = 120;
  static const int _batchSize = 1000;

  Future<void> run() async {
    stdout.writeln('Seeding reference data...');
    final reference = await _seedReferenceData();

    stdout.writeln('Seeding ${options.serializedRows} serialized_stock rows...');
    await _seedSerializedStock(reference.serializedProductIds);

    stdout.writeln('Seeding accessory inventory...');
    await _seedInventory(reference.accessoryProductIds);

    stdout.writeln('Seeding ${options.salesRows} sales and sale items...');
    await _seedSales(reference);

    stdout.writeln('Seeding ${options.printJobs} durable print jobs...');
    await _seedPrintJobs(reference.serializedProductIds.first);

    stdout.writeln('Stress dataset generation complete.');
  }

  Future<_ReferenceData> _seedReferenceData() async {
    final now = DateTimeHelpers.toSql(DateTimeHelpers.nowUtc());
    final serializedProductIds = <String>[];
    final accessoryProductIds = <String>[];

    await appDatabase.runInTransaction<void>((transaction) async {
      final batch = transaction.batch();

      for (var index = 0; index < _supplierCount; index++) {
        batch.insert(TableNames.suppliers, <String, Object?>{
          'id': 'sup_${index + 1}',
          'name': 'Supplier ${index + 1}',
          'contact_person': 'Contact ${index + 1}',
          'phone': '0300${(1000000 + index).toString().padLeft(7, '0')}',
          'email': null,
          'address': 'Warehouse ${index + 1}',
          'created_at': now,
          'updated_at': now,
        });
      }

      for (var index = 0; index < _customerCount; index++) {
        batch.insert(TableNames.customers, <String, Object?>{
          'id': 'cus_${index + 1}',
          'name': 'Customer ${index + 1}',
          'phone': '0311${(1000000 + index).toString().padLeft(7, '0')}',
          'email': null,
          'address': 'Block ${index % 75}',
          'created_at': now,
          'updated_at': now,
        });
      }

      for (var index = 0; index < _serializedProductCount; index++) {
        final id = 'prd_phone_${index + 1}';
        serializedProductIds.add(id);
        batch.insert(TableNames.productModels, <String, Object?>{
          'id': id,
          'name': 'Phone Model ${index + 1}',
          'brand': 'Brand ${index % 8}',
          'category': 'Phones',
          'sku': 'PHONE-${index + 1}',
          'purchase_price': 50000 + (index * 500),
          'sale_price': 56000 + (index * 500),
          'has_imei': 1,
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        });
      }

      for (var index = 0; index < _accessoryProductCount; index++) {
        final id = 'prd_acc_${index + 1}';
        accessoryProductIds.add(id);
        batch.insert(TableNames.productModels, <String, Object?>{
          'id': id,
          'name': 'Accessory ${index + 1}',
          'brand': 'Accessory Brand ${index % 10}',
          'category': 'Accessories',
          'sku': 'ACC-${index + 1}',
          'purchase_price': 150 + (index % 40),
          'sale_price': 250 + (index % 80),
          'has_imei': 0,
          'is_active': 1,
          'created_at': now,
          'updated_at': now,
        });
      }

      await batch.commit(noResult: true);
    });

    return _ReferenceData(
      serializedProductIds: serializedProductIds,
      accessoryProductIds: accessoryProductIds,
    );
  }

  Future<void> _seedSerializedStock(List<String> productIds) async {
    final now = DateTimeHelpers.nowUtc();
    for (var start = 0; start < options.serializedRows; start += _batchSize) {
      final end =
          start + _batchSize > options.serializedRows
              ? options.serializedRows
              : start + _batchSize;
      await appDatabase.runInTransaction<void>((transaction) async {
        final batch = transaction.batch();
        for (var index = start; index < end; index++) {
          final createdAt = now.subtract(Duration(days: index % 1825));
          batch.insert(TableNames.serializedStock, <String, Object?>{
            'id': 'ser_${index + 1}',
            'product_model_id': productIds[index % productIds.length],
            'imei1': '35678910${(1000000 + index).toString().padLeft(7, '0')}',
            'imei2': null,
            'serial_number': 'SER-${index + 1}',
            'cost_price': 50000 + (index % 2500),
            'selling_price': 56000 + (index % 3500),
            'stock_status': index < (options.salesRows ~/ 2) ? 'sold' : 'in_stock',
            'supplier_id': 'sup_${(index % _supplierCount) + 1}',
            'notes': null,
            'created_at': DateTimeHelpers.toSql(createdAt),
            'updated_at': DateTimeHelpers.toSql(createdAt),
          });
        }
        await batch.commit(noResult: true);
      });
      stdout.writeln('  serialized_stock: $end/${options.serializedRows}');
    }
  }

  Future<void> _seedInventory(List<String> accessoryProductIds) async {
    final now = DateTimeHelpers.toSql(DateTimeHelpers.nowUtc());
    await appDatabase.runInTransaction<void>((transaction) async {
      final batch = transaction.batch();
      for (var index = 0; index < accessoryProductIds.length; index++) {
        batch.insert(TableNames.inventoryStock, <String, Object?>{
          'id': 'stk_${index + 1}',
          'product_model_id': accessoryProductIds[index],
          'quantity': 2500 + (index * 15),
          'min_quantity': 25,
          'max_quantity': 5000,
          'unit_cost': 150 + (index % 40),
          'unit_price': 250 + (index % 80),
          'location': 'Rack-${index % 30}',
          'created_at': now,
          'updated_at': now,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> _seedSales(_ReferenceData reference) async {
    final startDate = DateTime.utc(2021, 1, 1);
    for (var start = 0; start < options.salesRows; start += _batchSize) {
      final end =
          start + _batchSize > options.salesRows
              ? options.salesRows
              : start + _batchSize;
      await appDatabase.runInTransaction<void>((transaction) async {
        final batch = transaction.batch();
        for (var index = start; index < end; index++) {
          final saleDate = startDate.add(Duration(days: index % 1825));
          final isPhoneSale = index < (options.salesRows ~/ 2);
          final saleId = 'sal_${index + 1}';
          final productId = isPhoneSale
              ? reference.serializedProductIds[index % reference.serializedProductIds.length]
              : reference.accessoryProductIds[index % reference.accessoryProductIds.length];
          final quantity = isPhoneSale ? 1 : ((index % 4) + 1);
          final unitPrice = isPhoneSale ? 62000 + (index % 3000) : 350 + (index % 80);
          final total = unitPrice * quantity;
          final paidAmount = index % 7 == 0 ? total - 500 : total;

          batch.insert(TableNames.sales, <String, Object?>{
            'id': saleId,
            'invoice_number': 'INV-${saleDate.year}${saleDate.month.toString().padLeft(2, '0')}${saleDate.day.toString().padLeft(2, '0')}-${(index + 1).toString().padLeft(6, '0')}',
            'customer_id': 'cus_${(index % _customerCount) + 1}',
            'user_id': null,
            'sale_date': DateTimeHelpers.toSql(saleDate),
            'subtotal': total,
            'discount': 0,
            'tax': 0,
            'total': total,
            'paid_amount': paidAmount,
            'payment_method': index % 3 == 0 ? 'cash' : 'card',
            'notes': null,
            'created_at': DateTimeHelpers.toSql(saleDate),
            'updated_at': DateTimeHelpers.toSql(saleDate),
          });

          batch.insert(TableNames.saleItems, <String, Object?>{
            'id': 'sli_${index + 1}',
            'sale_id': saleId,
            'product_model_id': productId,
            'serialized_stock_id': isPhoneSale ? 'ser_${index + 1}' : null,
            'quantity': quantity,
            'unit_price': unitPrice,
            'discount': 0,
            'line_total': total,
            'cost_price': isPhoneSale ? 54000 + (index % 2400) : 180 + (index % 30),
            'created_at': DateTimeHelpers.toSql(saleDate),
            'updated_at': DateTimeHelpers.toSql(saleDate),
          });
        }
        await batch.commit(noResult: true);
      });
      stdout.writeln('  sales: $end/${options.salesRows}');
    }
  }

  Future<void> _seedPrintJobs(String productModelId) async {
    final now = DateTimeHelpers.nowUtc();
    for (var start = 0; start < options.printJobs; start += _batchSize) {
      final end =
          start + _batchSize > options.printJobs
              ? options.printJobs
              : start + _batchSize;
      await appDatabase.runInTransaction<void>((transaction) async {
        final batch = transaction.batch();
        for (var index = start; index < end; index++) {
          final createdAt = now.subtract(Duration(minutes: index * 3));
          final status = switch (index % 5) {
            0 => InvoicePrintJobStatus.pending,
            1 => InvoicePrintJobStatus.failed,
            2 => InvoicePrintJobStatus.completed,
            3 => InvoicePrintJobStatus.cancelled,
            _ => InvoicePrintJobStatus.processing,
          };
          final document = InvoicePrintDocument(
            saleId: 'print_sale_${index + 1}',
            invoiceNumber: 'PRINT-${index + 1}',
            saleDate: createdAt,
            items: <CartItemEntity>[
              CartItemEntity(
                productModelId: productModelId,
                productName: 'Phone Model 1',
                hasImei: true,
                quantity: 1,
                unitPrice: 62000,
                serializedStockId: 'ser_${index + 1}',
                imei: '35678910${(2000000 + index).toString().padLeft(7, '0')}',
              ),
            ],
            totals: const SaleTotalsEntity(
              subtotal: 62000,
              discount: 0,
              tax: 0,
              total: 62000,
              paidAmount: 62000,
            ),
            paymentMethod: 'cash',
          );

          batch.insert(TableNames.printJobs, <String, Object?>{
            'id': 'prt_${index + 1}',
            'sale_id': document.saleId,
            'invoice_number': document.invoiceNumber,
            'document_json': jsonEncode(document.toMap()),
            'status': status.value,
            'retry_count': status == InvoicePrintJobStatus.failed ? 2 : 0,
            'last_error': status == InvoicePrintJobStatus.failed
                ? 'Simulated printer offline state.'
                : null,
            'created_at': DateTimeHelpers.toSql(createdAt),
            'updated_at': DateTimeHelpers.toSql(createdAt),
          });
        }
        await batch.commit(noResult: true);
      });
      stdout.writeln('  print_jobs: $end/${options.printJobs}');
    }
  }
}

class _ReferenceData {
  const _ReferenceData({
    required this.serializedProductIds,
    required this.accessoryProductIds,
  });

  final List<String> serializedProductIds;
  final List<String> accessoryProductIds;
}
