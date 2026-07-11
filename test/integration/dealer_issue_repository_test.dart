import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/modules/dealer_issue/data/repositories/sqlite_dealer_issue_repository.dart';
import 'package:phone_shop_pos/modules/dealer_issue/data/repositories/sqlite_dealer_repository.dart';
import 'package:phone_shop_pos/modules/dealer_issue/domain/entities/dealer_entity.dart';
import 'package:phone_shop_pos/modules/dealer_issue/domain/entities/dealer_issue_entity.dart';
import 'package:phone_shop_pos/modules/inventory/data/repositories/sqlite_product_repository.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/data/repositories/sqlite_purchase_repository.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';

/// Behavioural coverage for the previously untested dealer_issue module
/// (dealer CRUD + the issue lifecycle that moves serialized stock between
/// `in_stock` and `with_dealer`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Ctx ctx;

  setUp(() async {
    ctx = await _Ctx.fresh();
  });

  tearDown(() async {
    await ctx.dispose();
  });

  DealerEntity dealer(String id, String name) {
    final now = DateTimeHelpers.nowUtc();
    return DealerEntity(id: id, name: name, createdAt: now, updatedAt: now);
  }

  DealerIssueEntity issue(String id, String dealerId, List<String> imeis) {
    final now = DateTimeHelpers.nowUtc();
    return DealerIssueEntity(
      issueId: id,
      dealerId: dealerId,
      imeiList: imeis,
      issueDate: now,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('SqliteDealerRepository', () {
    test('creates dealers and lists active ones sorted by name', () async {
      _ok(await ctx.dealers.createDealer(dealer('d-b', 'Bravo')));
      _ok(await ctx.dealers.createDealer(dealer('d-a', 'Alpha')));

      final all = _ok(await ctx.dealers.getAllDealers());
      expect(all.map((d) => d.name), <String>['Alpha', 'Bravo']);
    });

    test('updateDealer persists changes', () async {
      _ok(await ctx.dealers.createDealer(dealer('d-1', 'Original')));
      final changed = _ok(await ctx.dealers.getAllDealers())
          .first
          .copyWith(name: 'Renamed', phone: '0300');
      expect(_ok(await ctx.dealers.updateDealer(changed)), isTrue);

      final reloaded = _ok(await ctx.dealers.getAllDealers()).first;
      expect(reloaded.name, 'Renamed');
      expect(reloaded.phone, '0300');
    });

    test('deleteDealer soft-deletes so it drops out of the active list',
        () async {
      _ok(await ctx.dealers.createDealer(dealer('d-1', 'Gone')));
      expect(_ok(await ctx.dealers.deleteDealer('d-1')), isTrue);
      expect(_ok(await ctx.dealers.getAllDealers()), isEmpty);
    });
  });

  group('SqliteDealerIssueRepository — issue lifecycle', () {
    const imei = '111111111111111';

    test('createIssue moves an in-stock IMEI to with_dealer', () async {
      await ctx.setupPhone(id: 'ph-1', imei: imei, cost: 40000, price: 50000);
      _ok(await ctx.dealers.createDealer(dealer('dlr-1', 'Dealer One')));

      // The IMEI is available before issuing.
      expect(
        _ok(await ctx.issues.getAvailableImeisForIssue('dlr-1')),
        contains(imei),
      );

      _ok(await ctx.issues.createIssue(issue('iss-1', 'dlr-1', <String>[imei])));

      final fetched = _ok(await ctx.issues.getIssueById('iss-1'));
      expect(fetched.imeiList, <String>[imei]);
      expect(fetched.returnStatus, isFalse);

      // Now with the dealer: no longer available, and not unique-for-dealer.
      expect(
        _ok(await ctx.issues.getAvailableImeisForIssue('dlr-1')),
        isNot(contains(imei)),
      );
      expect(
        _ok(await ctx.issues.isImeiUniqueForDealer(imei, 'dlr-1')),
        isFalse,
      );
    });

    test('createIssue rejects an IMEI that is not in stock', () async {
      _ok(await ctx.dealers.createDealer(dealer('dlr-1', 'Dealer One')));

      final result = await ctx.issues
          .createIssue(issue('iss-x', 'dlr-1', <String>['999999999999999']));
      expect(result.isFailure, isTrue);

      // Nothing should have been persisted for the failed issue.
      final byId = await ctx.issues.getIssueById('iss-x');
      expect(byId.isFailure, isTrue);
    });

    test('markAsReturned restores the IMEI to stock', () async {
      await ctx.setupPhone(id: 'ph-1', imei: imei, cost: 40000, price: 50000);
      _ok(await ctx.dealers.createDealer(dealer('dlr-1', 'Dealer One')));
      _ok(await ctx.issues.createIssue(issue('iss-1', 'dlr-1', <String>[imei])));

      expect(_ok(await ctx.issues.markAsReturned('iss-1')), isTrue);

      final fetched = _ok(await ctx.issues.getIssueById('iss-1'));
      expect(fetched.returnStatus, isTrue);
      expect(fetched.returnedAt, isNotNull);
      // Stock is back in the available pool.
      expect(
        _ok(await ctx.issues.getAvailableImeisForIssue('dlr-1')),
        contains(imei),
      );
    });

    test('markAsSold flips sold_status and surfaces via status query', () async {
      await ctx.setupPhone(id: 'ph-1', imei: imei, cost: 40000, price: 50000);
      _ok(await ctx.dealers.createDealer(dealer('dlr-1', 'Dealer One')));
      _ok(await ctx.issues.createIssue(issue('iss-1', 'dlr-1', <String>[imei])));

      expect(_ok(await ctx.issues.markAsSold('iss-1')), isTrue);

      final sold = _ok(await ctx.issues.getIssuesByStatus('Sold'));
      expect(sold.map((i) => i.issueId), <String>['iss-1']);
      expect(sold.first.soldStatus, isTrue);
    });

    test('deleteIssue on an open issue restores stock and removes the row',
        () async {
      await ctx.setupPhone(id: 'ph-1', imei: imei, cost: 40000, price: 50000);
      _ok(await ctx.dealers.createDealer(dealer('dlr-1', 'Dealer One')));
      _ok(await ctx.issues.createIssue(issue('iss-1', 'dlr-1', <String>[imei])));

      expect(_ok(await ctx.issues.deleteIssue('iss-1')), isTrue);
      expect((await ctx.issues.getIssueById('iss-1')).isFailure, isTrue);
      expect(
        _ok(await ctx.issues.getAvailableImeisForIssue('dlr-1')),
        contains(imei),
      );
    });

    test('getIssuesByDealer filters to the requested dealer', () async {
      await ctx.setupPhone(id: 'ph-1', imei: imei, cost: 40000, price: 50000);
      await ctx.setupPhone(
          id: 'ph-2', imei: '222222222222222', cost: 30000, price: 40000);
      _ok(await ctx.dealers.createDealer(dealer('dlr-1', 'Dealer One')));
      _ok(await ctx.dealers.createDealer(dealer('dlr-2', 'Dealer Two')));
      _ok(await ctx.issues.createIssue(issue('iss-1', 'dlr-1', <String>[imei])));
      _ok(await ctx.issues
          .createIssue(issue('iss-2', 'dlr-2', <String>['222222222222222'])));

      final forDealerOne = _ok(await ctx.issues.getIssuesByDealer('dlr-1'));
      expect(forDealerOne.map((i) => i.issueId), <String>['iss-1']);
    });
  });
}

class _Ctx {
  _Ctx({required Directory dir, required this.db})
      : _dir = dir,
        products = SqliteProductRepository(appDatabase: db),
        purchases = SqlitePurchaseRepository(appDatabase: db),
        dealers = SqliteDealerRepository(appDatabase: db),
        issues = SqliteDealerIssueRepository(appDatabase: db);

  final Directory _dir;
  final AppDatabase db;
  final SqliteProductRepository products;
  final SqlitePurchaseRepository purchases;
  final SqliteDealerRepository dealers;
  final SqliteDealerIssueRepository issues;

  static Future<_Ctx> fresh() async {
    final dir =
        await Directory.systemTemp.createTemp('phone_shop_pos_dealer_issue_');
    final db = AppDatabase(
      localDatabaseService: SqliteFfiDatabaseService(rootDirectory: dir.path),
      migrationService: const MigrationService(),
    );
    await db.initialize(seedDemoData: false);
    return _Ctx(dir: dir, db: db);
  }

  Future<void> dispose() async {
    await db.close();
    if (await _dir.exists()) {
      await _dir.delete(recursive: true);
    }
  }

  Future<void> setupPhone({
    required String id,
    required String imei,
    required double cost,
    required double price,
  }) async {
    final now = DateTimeHelpers.nowUtc();
    _ok(
      await products.createProduct(
        ProductEntity(
          id: id,
          name: 'Phone $id',
          sku: 'SKU-$id',
          purchasePrice: cost,
          salePrice: price,
          hasImei: true,
          isActive: true,
          createdAt: now,
          updatedAt: now,
        ),
      ),
    );
    _ok(
      await purchases.createPurchaseTransaction(
        items: <PurchaseFormItem>[
          PurchaseFormItem(
            productModelId: id,
            productName: 'Phone $id',
            hasImei: true,
            imeiEntries: <ImeiEntry>[
              ImeiEntry(imei1: imei, costPrice: cost),
            ],
          ),
        ],
        discount: 0,
        tax: 0,
        paidAmount: cost,
      ),
    );
  }
}

T _ok<T>(Result<T> result) {
  expect(
    result.isSuccess,
    isTrue,
    reason: result.isFailure ? result.asFailure!.error.message : '',
  );
  return result.asSuccess!.value;
}
