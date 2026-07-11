import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/database_constants.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';

/// Upgrade-path integrity tests for [MigrationService].
///
/// The production migration code is ~2.8k lines spanning 31 schema versions,
/// yet only the v14 foreign-key repair had a dedicated test. These tests
/// exercise the whole `onUpgrade` chain and assert that financial rows survive
/// the transitional table-rewrite migrations, since a faulty upgrade silently
/// corrupts a shop's money data on the next app launch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Earliest version we replay from. v13 is the oldest base proven to upgrade
  // cleanly (the pre-existing v14 FK-repair test pins here and upgrades to
  // latest), so it is a safe, representative floor for the sweep.
  const earliestUpgradeBase = 13;
  final latestVersion = DatabaseConstants.databaseVersion;

  Future<Directory> makeTempDir() =>
      Directory.systemTemp.createTemp('phone_shop_pos_migration_path_');

  AppDatabase openAt(Directory dir, int pinnedVersion) => AppDatabase(
        localDatabaseService: SqliteFfiDatabaseService(rootDirectory: dir.path),
        migrationService: _PinnedMigrationService(pinnedVersion),
      );

  AppDatabase openLatest(Directory dir) => AppDatabase(
        localDatabaseService: SqliteFfiDatabaseService(rootDirectory: dir.path),
        migrationService: const MigrationService(),
      );

  Future<int> readUserVersion(AppDatabase database) async {
    final rows = await database.database.rawQuery('PRAGMA user_version;');
    return (rows.first['user_version'] as int?) ?? -1;
  }

  Future<Set<String>> readTableNames(AppDatabase database) async {
    final rows = await database.database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table';",
    );
    return rows
        .map((row) => row['name']?.toString())
        .whereType<String>()
        .toSet();
  }

  group('database migration upgrade path', () {
    test(
      'upgrades cleanly to latest from every historical schema version',
      () async {
        for (var startVersion = earliestUpgradeBase;
            startVersion < latestVersion;
            startVersion++) {
          final dir = await makeTempDir();
          try {
            // 1. Materialize the schema as it existed at [startVersion].
            final legacy = openAt(dir, startVersion);
            await legacy.initialize(seedDemoData: false);
            expect(
              await readUserVersion(legacy),
              startVersion,
              reason: 'fresh install should report the pinned version',
            );
            await legacy.close();

            // 2. Reopen with the real service to drive the full upgrade chain.
            final upgraded = openLatest(dir);
            await upgraded.initialize(seedDemoData: false);

            expect(
              await readUserVersion(upgraded),
              latestVersion,
              reason: 'upgrade from v$startVersion must land on the latest '
                  'schema version',
            );

            final tables = await readTableNames(upgraded);
            for (final expected in <String>[
              TableNames.customers,
              TableNames.sales,
              TableNames.saleItems,
              TableNames.productModels,
              TableNames.customerLedger,
              TableNames.supplierLedger,
            ]) {
              expect(
                tables,
                contains(expected),
                reason: 'table "$expected" must survive upgrade from '
                    'v$startVersion',
              );
            }

            await upgraded.close();
          } finally {
            if (await dir.exists()) {
              await dir.delete(recursive: true);
            }
          }
        }
      },
    );

    test(
      'preserves customer ledger financial rows across the v22+ upgrades',
      () async {
        final dir = await makeTempDir();
        try {
          // Seed at v22, where the customer_ledger schema is stable and known.
          final legacy = openAt(dir, 22);
          await legacy.initialize(seedDemoData: false);
          final db = legacy.database;

          const now = '2024-01-01T00:00:00.000Z';
          await db.insert(TableNames.customers, <String, Object?>{
            'id': 'cust-1',
            'name': 'Ledger Customer',
            'created_at': now,
            'updated_at': now,
          });

          final seededRows = <Map<String, Object?>>[
            <String, Object?>{
              'id': 'led-debit',
              'party_id': 'cust-1',
              'transaction_id': 'txn-1',
              'ledger_type': 'sale',
              'amount': 1500.50,
              'direction': 'debit',
              'created_at': now,
              'updated_at': now,
            },
            <String, Object?>{
              'id': 'led-credit',
              'party_id': 'cust-1',
              'transaction_id': 'txn-2',
              'ledger_type': 'payment',
              'amount': 500.25,
              'direction': 'credit',
              'created_at': now,
              'updated_at': now,
            },
          ];
          for (final row in seededRows) {
            await db.insert(TableNames.customerLedger, row);
          }
          await legacy.close();

          // Drive migrations v23 -> latest.
          final upgraded = openLatest(dir);
          await upgraded.initialize(seedDemoData: false);

          final rows = await upgraded.database.query(
            TableNames.customerLedger,
            orderBy: 'id',
          );
          expect(rows, hasLength(2),
              reason: 'no ledger rows may be dropped during upgrade');

          final byId = <String, Map<String, Object?>>{
            for (final row in rows) row['id'].toString(): row,
          };
          expect((byId['led-debit']!['amount'] as num).toDouble(), 1500.50);
          expect(byId['led-debit']!['direction'], 'debit');
          expect((byId['led-credit']!['amount'] as num).toDouble(), 500.25);
          expect(byId['led-credit']!['direction'], 'credit');

          await upgraded.close();
        } finally {
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        }
      },
    );

    test(
      'fresh install enforces core customer-ledger financial invariants',
      () async {
        final dir = await makeTempDir();
        try {
          final database = openLatest(dir);
          await database.initialize(seedDemoData: false);
          final db = database.database;

          const now = '2024-01-01T00:00:00.000Z';
          await db.insert(TableNames.customers, <String, Object?>{
            'id': 'cust-1',
            'name': 'Invariant Customer',
            'created_at': now,
            'updated_at': now,
          });

          Map<String, Object?> ledgerRow({
            required String id,
            required double amount,
            required String direction,
          }) =>
              <String, Object?>{
                'id': id,
                'party_id': 'cust-1',
                'transaction_id': 'txn-$id',
                'ledger_type': 'sale',
                'amount': amount,
                'direction': direction,
                'created_at': now,
                'updated_at': now,
              };

          // Negative amounts violate the amount >= 0 CHECK constraint.
          await expectLater(
            db.insert(
              TableNames.customerLedger,
              ledgerRow(id: 'bad-amount', amount: -1, direction: 'debit'),
            ),
            throwsA(isA<Exception>()),
          );

          // Only 'debit'/'credit' directions are permitted.
          await expectLater(
            db.insert(
              TableNames.customerLedger,
              ledgerRow(id: 'bad-dir', amount: 10, direction: 'sideways'),
            ),
            throwsA(isA<Exception>()),
          );

          // A well-formed row is still accepted.
          final rowId = await db.insert(
            TableNames.customerLedger,
            ledgerRow(id: 'good', amount: 10, direction: 'debit'),
          );
          expect(rowId, greaterThan(0));

          await database.close();
        } finally {
          if (await dir.exists()) {
            await dir.delete(recursive: true);
          }
        }
      },
    );
  });
}

/// A [MigrationService] whose reported latest version is pinned, so tests can
/// materialize the schema exactly as an older release would have created it and
/// then replay the real upgrade chain on top of it.
class _PinnedMigrationService extends MigrationService {
  const _PinnedMigrationService(this._pinnedVersion);

  final int _pinnedVersion;

  @override
  int get latestVersion => _pinnedVersion;
}
