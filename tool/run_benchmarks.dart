import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/migration_service.dart';
import 'package:phone_shop_pos/core/database/sqlite_service.dart';
import 'package:phone_shop_pos/core/services/backup/database_backup_service.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/data/repositories/sqlite_inventory_repository.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/report_filter_entity.dart';
import 'package:phone_shop_pos/modules/reports/services/inventory_report_service.dart';
import 'package:phone_shop_pos/modules/reports/services/profit_report_service.dart';
import 'package:phone_shop_pos/modules/reports/services/sales_report_service.dart';
import 'package:phone_shop_pos/modules/sales/data/repositories/sqlite_sales_repository.dart';

Future<void> main(List<String> arguments) async {
  final rootDirectory = _readValue(arguments, 'root') ?? Directory.current.path;
  final outputPath =
      _readValue(arguments, 'out') ??
      p.join(rootDirectory, 'benchmark_summary.json');

  final startupWatch = Stopwatch()..start();
  final appDatabase = AppDatabase(
    localDatabaseService: SqliteFfiDatabaseService(rootDirectory: rootDirectory),
    migrationService: const MigrationService(),
  );
  await appDatabase.initialize(seedDemoData: false);
  startupWatch.stop();

  final memoryBefore = ProcessInfo.currentRss;
  final salesRepository = SqliteSalesRepository(appDatabase: appDatabase);
  final inventoryRepository = SqliteInventoryRepository(appDatabase: appDatabase);
  final salesReportService = SalesReportService(appDatabase: appDatabase);
  final inventoryReportService = InventoryReportService(appDatabase: appDatabase);
  final profitReportService = ProfitReportService(appDatabase: appDatabase);
  final backupService = DatabaseBackupService(appDatabase: appDatabase);

  final metrics = <String, Object?>{
    'startupMs': startupWatch.elapsedMilliseconds,
    'imeiSearchMs': await _measure(() async {
      await inventoryRepository.searchSerializedByImei('35678910', limit: 50);
    }),
    'availableImeiSearchMs': await _measure(() async {
      await salesRepository.getAvailableImeis('prd_phone_1', query: '35678910');
    }),
    'inventoryRowsMs': await _measure(() async {
      await inventoryRepository.getStockRows(searchQuery: 'PHONE-1', limit: 100);
    }),
    'dailySalesReportMs': await _measure(() async {
      await salesReportService.getDailySalesReport(const ReportFilterEntity());
    }),
    'currentStockReportMs': await _measure(() async {
      await inventoryReportService.getCurrentStockReport(const ReportFilterEntity());
    }),
    'profitReportMs': await _measure(() async {
      await profitReportService.getProfitReport(const ReportFilterEntity());
    }),
  };

  metrics['backupMs'] = await _measure(() async {
    await backupService.createBackup(
      directoryPath: p.join(rootDirectory, 'benchmark_backups'),
    );
  });

  final backupDirectory = Directory(p.join(rootDirectory, 'benchmark_backups'));
  final backups = await backupDirectory
      .list()
      .where((entity) => entity is File && p.basename(entity.path).startsWith('backup_'))
      .cast<File>()
      .toList();
  backups.sort((a, b) => b.path.compareTo(a.path));
  final latestBackup = backups.isEmpty ? null : backups.first;

  if (latestBackup != null) {
    metrics['restoreMs'] = await _measure(() async {
      final restoreRoot = await Directory.systemTemp.createTemp(
        'phone_shop_pos_restore_benchmark_',
      );
      final databasePath = p.join(rootDirectory, 'phone_shop_pos.db');
      await File(databasePath).copy(p.join(restoreRoot.path, 'phone_shop_pos.db'));
      final restoreDatabase = AppDatabase(
        localDatabaseService: SqliteFfiDatabaseService(rootDirectory: restoreRoot.path),
        migrationService: const MigrationService(),
      );
      await restoreDatabase.initialize(seedDemoData: false);
      try {
        final restoreService = DatabaseBackupService(appDatabase: restoreDatabase);
        await restoreService.restoreBackup(latestBackup.path);
      } finally {
        await restoreDatabase.close();
        await restoreRoot.delete(recursive: true);
      }
    });
  }

  metrics['memoryBeforeBytes'] = memoryBefore;
  metrics['memoryAfterBytes'] = ProcessInfo.currentRss;
  metrics['memoryGrowthBytes'] =
      (metrics['memoryAfterBytes'] as int) - (metrics['memoryBeforeBytes'] as int);
  metrics['generatedAt'] = DateTime.now().toUtc().toIso8601String();

  final outputFile = File(outputPath);
  await outputFile.writeAsString(const JsonEncoder.withIndent('  ').convert(metrics));

  stdout.writeln('Benchmark summary written to ${outputFile.path}');
  stdout.writeln('Startup: ${metrics['startupMs']} ms');
  stdout.writeln('IMEI search: ${metrics['imeiSearchMs']} ms');
  stdout.writeln('Inventory rows: ${metrics['inventoryRowsMs']} ms');
  stdout.writeln(
    'Memory growth: ${FormattingHelpers.decimal((metrics['memoryGrowthBytes'] as int) / (1024 * 1024))} MB',
  );

  await appDatabase.close();
}

Future<int> _measure(Future<void> Function() action) async {
  final stopwatch = Stopwatch()..start();
  await action();
  stopwatch.stop();
  return stopwatch.elapsedMilliseconds;
}

String? _readValue(List<String> arguments, String key) {
  for (final argument in arguments) {
    if (!argument.startsWith('--$key=')) {
      continue;
    }
    return argument.substring(key.length + 3);
  }
  return null;
}
