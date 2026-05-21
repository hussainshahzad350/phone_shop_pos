import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('migration v14 sales FK repair', () {
    test('repairs sale_items foreign key if it references sales_old', () async {
      final rootDirectory = await Directory.systemTemp.createTemp(
        'phone_shop_pos_migration_v14_',
      );

      try {
        final v13Database = AppDatabase(
          localDatabaseService: SqliteFfiDatabaseService(
            rootDirectory: rootDirectory.path,
          ),
          migrationService: const _MigrationServiceV13(),
        );
        await v13Database.initialize(seedDemoData: false);

        final db = v13Database.database;
        await db.execute('PRAGMA foreign_keys = OFF;');
        try {
          await db.execute(
            'ALTER TABLE ${TableNames.saleItems} RENAME TO ${TableNames.saleItems}_broken;',
          );
          await db.execute(
            '''
            CREATE TABLE ${TableNames.saleItems} (
              id TEXT PRIMARY KEY NOT NULL,
              sale_id TEXT NOT NULL,
              product_model_id TEXT NOT NULL,
              serialized_stock_id TEXT,
              quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
              unit_price REAL NOT NULL DEFAULT 0,
              discount REAL NOT NULL DEFAULT 0,
              line_total REAL NOT NULL DEFAULT 0,
              cost_price REAL NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              FOREIGN KEY (sale_id) REFERENCES ${TableNames.sales}_old(id)
                ON UPDATE CASCADE
                ON DELETE CASCADE,
              FOREIGN KEY (product_model_id) REFERENCES ${TableNames.productModels}(id)
                ON UPDATE CASCADE
                ON DELETE RESTRICT,
              FOREIGN KEY (serialized_stock_id) REFERENCES ${TableNames.serializedStock}(id)
                ON UPDATE CASCADE
                ON DELETE SET NULL
            );
            ''',
          );
          await db.execute(
            '''
            INSERT INTO ${TableNames.saleItems} (
              id,
              sale_id,
              product_model_id,
              serialized_stock_id,
              quantity,
              unit_price,
              discount,
              line_total,
              cost_price,
              created_at,
              updated_at
            )
            SELECT
              id,
              sale_id,
              product_model_id,
              serialized_stock_id,
              quantity,
              unit_price,
              discount,
              line_total,
              cost_price,
              created_at,
              updated_at
            FROM ${TableNames.saleItems}_broken;
            ''',
          );
          await db.execute('DROP TABLE ${TableNames.saleItems}_broken;');
        } finally {
          await db.execute('PRAGMA foreign_keys = ON;');
        }

        final beforeRows = await db.rawQuery(
          'PRAGMA foreign_key_list(${TableNames.saleItems});',
        );
        final beforeParents = beforeRows
            .map((row) => row['table']?.toString())
            .whereType<String>()
            .toSet();
        expect(beforeParents.contains('${TableNames.sales}_old'), isTrue);

        await v13Database.close();

        final upgradedDatabase = AppDatabase(
          localDatabaseService: SqliteFfiDatabaseService(
            rootDirectory: rootDirectory.path,
          ),
          migrationService: const MigrationService(),
        );
        await upgradedDatabase.initialize(seedDemoData: false);

        final afterRows = await upgradedDatabase.database.rawQuery(
          'PRAGMA foreign_key_list(${TableNames.saleItems});',
        );
        final afterParents = afterRows
            .map((row) => row['table']?.toString())
            .whereType<String>()
            .toSet();

        expect(afterParents.contains(TableNames.sales), isTrue);
        expect(afterParents.contains('${TableNames.sales}_old'), isFalse);

        await upgradedDatabase.close();
      } finally {
        if (await rootDirectory.exists()) {
          await rootDirectory.delete(recursive: true);
        }
      }
    });
  });
}

class _MigrationServiceV13 extends MigrationService {
  const _MigrationServiceV13();

  @override
  int get latestVersion => 13;
}
