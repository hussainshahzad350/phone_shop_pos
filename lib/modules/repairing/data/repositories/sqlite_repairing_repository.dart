import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/query_diagnostics.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:phone_shop_pos/modules/ledger/services/ledger_posting_service.dart';
import 'package:phone_shop_pos/modules/repairing/domain/entities/repair_analytics_entity.dart';
import 'package:phone_shop_pos/modules/repairing/domain/entities/repair_job_entity.dart';
import 'package:phone_shop_pos/modules/repairing/domain/repositories/repairing_repository.dart';

class SqliteRepairingRepository
    with BaseRepositoryGuard
    implements RepairingRepository {
  SqliteRepairingRepository({required AppDatabase appDatabase})
      : this.withLedger(appDatabase: appDatabase, ledgerPostingService: null);

  SqliteRepairingRepository.withLedger({
    required AppDatabase appDatabase,
    required LedgerPostingService? ledgerPostingService,
  })  : _appDatabase = appDatabase,
        _ledgerPostingService = ledgerPostingService;

  final AppDatabase _appDatabase;
  final LedgerPostingService? _ledgerPostingService;

  static const String _table = TableNames.repairJobs;

  @override
  Future<Result<List<RepairJobEntity>>> getRepairJobs({
    String? searchQuery,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    bool includeArchived = false,
  }) {
    return guard<List<RepairJobEntity>>(() async {
      final whereClauses = <String>[];
      if (includeArchived) {
        whereClauses.add('is_deleted = 1');
      } else {
        whereClauses.add('is_deleted = 0');
      }
      final args = <Object?>[];

      final query = searchQuery?.trim() ?? '';
      if (query.isNotEmpty) {
        final like = '%$query%';
        whereClauses.add(
          '(customer_name LIKE ? OR phone_model LIKE ? OR imei LIKE ? OR customer_phone LIKE ?)',
        );
        args
          ..add(like)
          ..add(like)
          ..add(like)
          ..add(like);
      }

      if (status != null && status.isNotEmpty) {
        whereClauses.add('status = ?');
        args.add(status);
      }

      if (startDate != null) {
        final startUtc =
            DateTime.utc(startDate.year, startDate.month, startDate.day);
        whereClauses.add('repair_date >= ?');
        args.add(DateTimeHelpers.toSql(startUtc));
      }

      if (endDate != null) {
        final endUtc = DateTime.utc(endDate.year, endDate.month, endDate.day)
            .add(const Duration(days: 1));
        whereClauses.add('repair_date < ?');
        args.add(DateTimeHelpers.toSql(endUtc));
      }

      final where = whereClauses.join(' AND ');
      final whereSql = where.isEmpty ? '' : 'WHERE $where';

      final rows = await QueryDiagnostics.trace(
        label: 'repairing.get_jobs',
        action: () => _appDatabase.database.rawQuery(
          'SELECT * FROM $_table $whereSql ORDER BY repair_date DESC, created_at DESC',
          args,
        ),
      );

      return rows.map(_rowToEntity).toList(growable: false);
    }, operation: 'get_repair_jobs');
  }

  @override
  Future<Result<RepairJobEntity?>> getRepairJobById(String id) {
    return guard<RepairJobEntity?>(() async {
      final rows = await _appDatabase.database.rawQuery(
        'SELECT * FROM $_table WHERE id = ? AND is_deleted = 0',
        <Object?>[id],
      );
      if (rows.isEmpty) {
        return null;
      }
      return _rowToEntity(rows.first);
    }, operation: 'get_repair_job_by_id');
  }

  @override
  Future<Result<void>> addRepairJob(RepairJobEntity job) {
    return guard<void>(() async {
      final id = job.id.isEmpty ? IdHelpers.newId(prefix: 'rep') : job.id;
      final now = DateTimeHelpers.toSql(DateTimeHelpers.nowUtc());
      await _appDatabase.runInTransaction<void>((transaction) async {
        await transaction.rawInsert(
          '''
          INSERT INTO $_table (
            id, created_at, updated_at, repair_date,
            customer_name, customer_phone, phone_model, imei,
            problem_description, issue_type, accessories, technician_name,
            estimated_cost, advance_received, final_cost, repair_expense,
            status, notes, is_deleted
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
          ''',
          <Object?>[
            id,
            now,
            null,
            DateTimeHelpers.toSql(
              DateTime.utc(
                job.repairDate.year,
                job.repairDate.month,
                job.repairDate.day,
              ),
            ),
            job.customerName,
            job.customerPhone,
            job.phoneModel,
            job.imei,
            job.problemDescription,
            job.issueType,
            job.accessories,
            job.technicianName,
            job.estimatedCost,
            job.advanceReceived,
            job.finalCost,
            job.repairExpense,
            job.status,
            job.notes,
          ],
        );

        if (_ledgerPostingService == null) {
          return;
        }
        final customerId =
            await _findCustomerIdByPhone(transaction, job.customerPhone);
        if (customerId == null) {
          return;
        }
        final nowUtc = DateTimeHelpers.fromSql(now);
        final dueAmount = (job.finalCost ?? 0).clamp(0, double.infinity);
        if (dueAmount > 0) {
          final dueResult = await _ledgerPostingService!.postRepairDue(
            repairId: id,
            customerId: customerId,
            amount: dueAmount,
            createdAt: nowUtc,
            note: job.notes,
            executor: transaction,
          );
          if (dueResult.isFailure) {
            throw StateError(dueResult.asFailure!.error.message);
          }
        }
        if (job.advanceReceived > 0) {
          final paymentResult = await _ledgerPostingService!.postRepairPayment(
            repairId: id,
            customerId: customerId,
            amount: job.advanceReceived,
            paymentMethod: PaymentMethod.cash,
            createdAt: nowUtc,
            note: job.notes,
            executor: transaction,
          );
          if (paymentResult.isFailure) {
            throw StateError(paymentResult.asFailure!.error.message);
          }
        }
      });
    }, operation: 'add_repair_job');
  }

  @override
  Future<Result<void>> updateRepairJob(RepairJobEntity job) {
    return guard<void>(() async {
      final now = DateTimeHelpers.toSql(DateTimeHelpers.nowUtc());
      await _appDatabase.runInTransaction<void>((transaction) async {
        final existingRows = await transaction.query(
          _table,
          where: 'id = ? AND is_deleted = 0',
          whereArgs: <Object?>[job.id],
          limit: 1,
        );
        if (existingRows.isEmpty) {
          throw StateError('Repair job not found.');
        }
        final previous = _rowToEntity(existingRows.first);
        await transaction.rawUpdate(
          '''
          UPDATE $_table SET
            updated_at = ?,
            repair_date = ?,
            customer_name = ?,
            customer_phone = ?,
            phone_model = ?,
            imei = ?,
            problem_description = ?,
            issue_type = ?,
            accessories = ?,
            technician_name = ?,
            estimated_cost = ?,
            advance_received = ?,
            final_cost = ?,
            repair_expense = ?,
            status = ?,
            notes = ?
          WHERE id = ? AND is_deleted = 0
          ''',
          <Object?>[
            now,
            DateTimeHelpers.toSql(
              DateTime.utc(
                job.repairDate.year,
                job.repairDate.month,
                job.repairDate.day,
              ),
            ),
            job.customerName,
            job.customerPhone,
            job.phoneModel,
            job.imei,
            job.problemDescription,
            job.issueType,
            job.accessories,
            job.technicianName,
            job.estimatedCost,
            job.advanceReceived,
            job.finalCost,
            job.repairExpense,
            job.status,
            job.notes,
            job.id,
          ],
        );
        if (_ledgerPostingService == null) {
          return;
        }
        final customerId =
            await _findCustomerIdByPhone(transaction, job.customerPhone);
        if (customerId == null) {
          return;
        }
        final nowUtc = DateTimeHelpers.fromSql(now);
        final previousDue = (previous.finalCost ?? 0).clamp(0, double.infinity);
        final nextDue = (job.finalCost ?? 0).clamp(0, double.infinity);
        final dueDelta = nextDue - previousDue;
        if (dueDelta > 0) {
          final dueResult = await _ledgerPostingService!.postRepairDue(
            repairId: job.id,
            customerId: customerId,
            amount: dueDelta,
            createdAt: nowUtc,
            note: 'Repair due adjustment',
            executor: transaction,
          );
          if (dueResult.isFailure) {
            throw StateError(dueResult.asFailure!.error.message);
          }
        } else if (dueDelta < 0) {
          final reverseResult =
              await _ledgerPostingService!.postRepairDueReduction(
            repairId: job.id,
            customerId: customerId,
            amount: dueDelta.abs(),
            createdAt: nowUtc,
            note: 'Repair due reduction',
            executor: transaction,
          );
          if (reverseResult.isFailure) {
            throw StateError(reverseResult.asFailure!.error.message);
          }
        }
      });
    }, operation: 'update_repair_job');
  }

  @override
  Future<Result<void>> collectPayment(
    String id,
    double amount, {
    String? notes,
  }) {
    return guard<void>(() async {
      if (amount <= 0) {
        throw StateError('Collected amount must be greater than zero.');
      }

      final rows = await _appDatabase.database.query(
        _table,
        where: 'id = ? AND is_deleted = 0',
        whereArgs: <Object?>[id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Repair job not found.');
      }

      final job = _rowToEntity(rows.first);
      if (job.status == RepairJobEntity.statusDelivered) {
        throw StateError('Delivered repair jobs cannot collect more payment.');
      }

      final updatedReceived = job.advanceReceived + amount;
      final finalAmount = job.finalCost;
      if (finalAmount != null && finalAmount > 0.009) {
        if (updatedReceived > finalAmount + 0.009) {
          throw StateError('Collected amount cannot exceed the final cost.');
        }
      }

      final now = DateTimeHelpers.nowUtc();
      final nowSql = DateTimeHelpers.toSql(now);
      final trimmedNote = notes?.trim();
      final amountText = amount == amount.roundToDouble()
          ? amount.toStringAsFixed(0)
          : amount.toStringAsFixed(2);
      final paymentLine = [
        '[Payment ${nowSql.replaceFirst('T', ' ')}] Collected PKR $amountText',
        if (trimmedNote != null && trimmedNote.isNotEmpty) trimmedNote,
      ].join(' — ');
      final updatedNotes = [
        if (job.notes != null && job.notes!.trim().isNotEmpty)
          job.notes!.trim(),
        paymentLine,
      ].join('\n');

      await _appDatabase.runInTransaction<void>((transaction) async {
        await transaction.rawUpdate(
          '''
          UPDATE $_table SET
            advance_received = ?,
            notes = ?,
            updated_at = ?
          WHERE id = ? AND is_deleted = 0
          ''',
          <Object?>[
            updatedReceived,
            updatedNotes,
            nowSql,
            id,
          ],
        );
        if (_ledgerPostingService == null) {
          return;
        }
        final customerId =
            await _findCustomerIdByPhone(transaction, job.customerPhone);
        if (customerId == null) {
          return;
        }
        final ledgerResult = await _ledgerPostingService!.postRepairPayment(
          repairId: id,
          customerId: customerId,
          amount: amount,
          paymentMethod: PaymentMethod.cash,
          createdAt: now,
          note: trimmedNote,
          executor: transaction,
        );
        if (ledgerResult.isFailure) {
          throw StateError(ledgerResult.asFailure!.error.message);
        }
      });
    }, operation: 'collect_repair_payment');
  }

  @override
  Future<Result<void>> updateStatus(String id, String status) {
    return guard<void>(() async {
      if (status == RepairJobEntity.statusDelivered) {
        final rows = await _appDatabase.database.query(
          _table,
          where: 'id = ? AND is_deleted = 0',
          whereArgs: <Object?>[id],
          limit: 1,
        );
        if (rows.isEmpty) {
          throw StateError('Repair job not found.');
        }
        final job = _rowToEntity(rows.first);
        if (!job.canMarkDelivered) {
          throw StateError(
            'Set the final cost and clear all pending payment before marking this repair as delivered.',
          );
        }
      }

      final now = DateTimeHelpers.toSql(DateTimeHelpers.nowUtc());
      await _appDatabase.database.rawUpdate(
        'UPDATE $_table SET status = ?, updated_at = ? WHERE id = ? AND is_deleted = 0',
        <Object?>[status, now, id],
      );
    }, operation: 'update_repair_status');
  }

  @override
  Future<Result<void>> deleteRepairJob(String id) {
    return guard<void>(() async {
      final now = DateTimeHelpers.toSql(DateTimeHelpers.nowUtc());
      await _appDatabase.database.rawUpdate(
        'UPDATE $_table SET is_deleted = 1, updated_at = ? WHERE id = ?',
        <Object?>[now, id],
      );
    }, operation: 'delete_repair_job');
  }

  @override
  Future<Result<void>> restoreRepairJob(String id) {
    return guard<void>(() async {
      final now = DateTimeHelpers.toSql(DateTimeHelpers.nowUtc());
      await _appDatabase.database.rawUpdate(
        'UPDATE $_table SET is_deleted = 0, updated_at = ? WHERE id = ?',
        <Object?>[now, id],
      );
    }, operation: 'restore_repair_job');
  }

  @override
  Future<Result<RepairKpiEntity>> getRepairKpis() {
    return guard<RepairKpiEntity>(() async {
      final now = DateTimeHelpers.nowUtc();
      final todayStart = DateTime.utc(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      final todayStartSql = DateTimeHelpers.toSql(todayStart);
      final todayEndSql = DateTimeHelpers.toSql(todayEnd);

      final rows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          SUM(CASE WHEN repair_date >= ? AND repair_date < ? THEN 1 ELSE 0 END) AS received_today,
          SUM(CASE WHEN status = 'ready' THEN 1 ELSE 0 END) AS ready_for_delivery,
          SUM(CASE WHEN status IN ('received', 'diagnosing', 'repairing') THEN 1 ELSE 0 END) AS pending_repairs,
          SUM(CASE WHEN status = 'delivered' AND repair_date >= ? AND repair_date < ?
                   THEN COALESCE(final_cost, 0) - COALESCE(repair_expense, 0)
                   ELSE 0 END) AS today_earnings,
          SUM(CASE WHEN status = 'delivered'
                   THEN COALESCE(final_cost, 0) - COALESCE(repair_expense, 0)
                   ELSE 0 END) AS all_time_earnings,
          COUNT(CASE WHEN status = 'delivered' THEN 1 END) AS all_jobs_done
        FROM $_table
        WHERE is_deleted = 0
        ''',
        <Object?>[todayStartSql, todayEndSql, todayStartSql, todayEndSql],
      );

      final row = rows.first;
      return RepairKpiEntity(
        receivedToday: (row['received_today'] as num?)?.toInt() ?? 0,
        readyForDelivery: (row['ready_for_delivery'] as num?)?.toInt() ?? 0,
        pendingRepairs: (row['pending_repairs'] as num?)?.toInt() ?? 0,
        todayEarnings: (row['today_earnings'] as num?)?.toDouble() ?? 0,
        allTimeEarnings: (row['all_time_earnings'] as num?)?.toDouble() ?? 0,
        allJobsDone: (row['all_jobs_done'] as num?)?.toInt() ?? 0,
      );
    }, operation: 'get_repair_kpis');
  }

  @override
  Future<Result<RepairAnalyticsEntity>> getRepairAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return guard<RepairAnalyticsEntity>(() async {
      final whereClauses = <String>['is_deleted = 0'];
      final args = <Object?>[];

      if (startDate != null) {
        final startUtc =
            DateTime.utc(startDate.year, startDate.month, startDate.day);
        whereClauses.add('repair_date >= ?');
        args.add(DateTimeHelpers.toSql(startUtc));
      }

      if (endDate != null) {
        final endUtc = DateTime.utc(endDate.year, endDate.month, endDate.day)
            .add(const Duration(days: 1));
        whereClauses.add('repair_date < ?');
        args.add(DateTimeHelpers.toSql(endUtc));
      }

      final where = whereClauses.join(' AND ');

      final summaryRows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          COUNT(*) AS total,
          SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) AS delivered,
          SUM(CASE WHEN status NOT IN ('delivered', 'cancelled') THEN 1 ELSE 0 END) AS pending,
          SUM(CASE WHEN status = 'delivered'
                   THEN COALESCE(final_cost, 0) - COALESCE(repair_expense, 0)
                   ELSE 0 END) AS total_earnings,
          SUM(COALESCE(repair_expense, 0)) AS total_expenses
        FROM $_table
        WHERE $where
        ''',
        args,
      );

      final summary = summaryRows.first;
      final totalRepairs = (summary['total'] as num?)?.toInt() ?? 0;
      final deliveredRepairs = (summary['delivered'] as num?)?.toInt() ?? 0;
      final pendingRepairs = (summary['pending'] as num?)?.toInt() ?? 0;
      final totalEarnings =
          (summary['total_earnings'] as num?)?.toDouble() ?? 0;
      final totalExpenses =
          (summary['total_expenses'] as num?)?.toDouble() ?? 0;

      final modelRows = await _appDatabase.database.rawQuery(
        '''
        SELECT phone_model, COUNT(*) AS cnt
        FROM $_table
        WHERE $where
        GROUP BY phone_model
        ORDER BY cnt DESC
        LIMIT 20
        ''',
        args,
      );

      final topModels = modelRows
          .map(
            (r) => RepairModelCountEntity(
              model: (r['phone_model'] as String?) ?? 'Unknown',
              count: (r['cnt'] as num?)?.toInt() ?? 0,
            ),
          )
          .toList(growable: false);

      final monthlyArgs = List<Object?>.from(args);
      final monthlyRows = await _appDatabase.database.rawQuery(
        '''
        SELECT
          SUBSTR(repair_date, 1, 7) AS month,
          COUNT(*) AS repairs,
          SUM(CASE WHEN status = 'delivered'
                   THEN COALESCE(final_cost, 0) - COALESCE(repair_expense, 0)
                   ELSE 0 END) AS earnings
        FROM $_table
        WHERE $where
        GROUP BY SUBSTR(repair_date, 1, 7)
        ORDER BY month DESC
        ''',
        monthlyArgs,
      );

      final monthlyTrend = monthlyRows
          .map(
            (r) => RepairMonthlyRowEntity(
              month: (r['month'] as String?) ?? '',
              repairs: (r['repairs'] as num?)?.toInt() ?? 0,
              earnings: (r['earnings'] as num?)?.toDouble() ?? 0,
            ),
          )
          .toList(growable: false);

      final allJobs = await _appDatabase.database.rawQuery(
        'SELECT issue_type, problem_description FROM $_table WHERE $where',
        args,
      );

      // Use issue_type when set (clean data); fall back to keyword grouping
      // only for rows where issue_type is NULL (legacy / free-text only).
      final issueGroups = _groupIssues(allJobs);

      return RepairAnalyticsEntity(
        totalRepairs: totalRepairs,
        deliveredRepairs: deliveredRepairs,
        pendingRepairs: pendingRepairs,
        totalEarnings: totalEarnings,
        totalExpenses: totalExpenses,
        issueGroups: issueGroups,
        topModels: topModels,
        monthlyTrend: monthlyTrend,
      );
    }, operation: 'get_repair_analytics');
  }

  List<RepairIssueGroupEntity> _groupIssues(
    List<Map<String, Object?>> rows,
  ) {
    const issueKeywords = <String, List<String>>{
      'LCD / Display': <String>['lcd', 'display', 'screen', 'touch'],
      'Charging': <String>['charg', 'pin', 'port'],
      'Battery': <String>['battery', 'batt', 'backup'],
      'Speaker': <String>['speaker', 'audio', 'sound', 'loud'],
      'Mic': <String>['mic', 'voice', 'call'],
      'Camera': <String>['camera', 'cam'],
      'Network / SIM': <String>['network', 'sim', 'signal', 'no service'],
      'Water Damage': <String>['water', 'wet', 'damp'],
      'Back Cover': <String>['back', 'cover', 'glass'],
      'Software / Flash': <String>[
        'software',
        'flash',
        'hang',
        'restart',
        'format',
      ],
      'Power Button': <String>['power', 'on/off', 'button'],
      'Volume Button': <String>['volume'],
      'Dead': <String>['dead', 'not turn'],
    };

    final counts = <String, int>{};
    for (final row in rows) {
      // Prefer the structured issue_type when it has been set.
      final structured = (row['issue_type'] as String?)?.trim();
      if (structured != null && structured.isNotEmpty) {
        counts[structured] = (counts[structured] ?? 0) + 1;
        continue;
      }

      // Fall back to keyword grouping for legacy free-text descriptions.
      final desc = (row['problem_description'] as String?) ?? '';
      final lower = desc.toLowerCase();
      var matched = false;
      for (final entry in issueKeywords.entries) {
        for (final kw in entry.value) {
          if (lower.contains(kw)) {
            counts[entry.key] = (counts[entry.key] ?? 0) + 1;
            matched = true;
            break;
          }
        }
        if (matched) {
          break;
        }
      }
      if (!matched) {
        counts['Other'] = (counts['Other'] ?? 0) + 1;
      }
    }

    final sorted = counts.entries.toList(growable: false)
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted
        .where((e) => e.value > 0)
        .map((e) => RepairIssueGroupEntity(issue: e.key, count: e.value))
        .toList(growable: false);
  }

  RepairJobEntity _rowToEntity(Map<String, Object?> row) {
    return RepairJobEntity(
      id: row['id'] as String,
      createdAt: DateTimeHelpers.fromSql(row['created_at'] as String),
      updatedAt: row['updated_at'] != null
          ? DateTimeHelpers.fromSql(row['updated_at'] as String)
          : null,
      repairDate: DateTimeHelpers.fromSql(row['repair_date'] as String),
      customerName: row['customer_name'] as String?,
      customerPhone: row['customer_phone'] as String?,
      phoneModel: row['phone_model'] as String,
      imei: row['imei'] as String?,
      problemDescription: row['problem_description'] as String,
      issueType: row['issue_type'] as String?,
      accessories: row['accessories'] as String?,
      technicianName: row['technician_name'] as String?,
      estimatedCost: row['estimated_cost'] != null
          ? (row['estimated_cost'] as num).toDouble()
          : null,
      advanceReceived: ((row['advance_received'] as num?) ?? 0).toDouble(),
      finalCost: row['final_cost'] != null
          ? (row['final_cost'] as num).toDouble()
          : null,
      repairExpense: ((row['repair_expense'] as num?) ?? 0).toDouble(),
      status: row['status'] as String,
      isArchived: ((row['is_deleted'] as num?) ?? 0) == 1,
      notes: row['notes'] as String?,
    );
  }

  Future<String?> _findCustomerIdByPhone(
    DatabaseExecutor executor,
    String? customerPhone,
  ) async {
    final normalizedPhone = customerPhone?.trim();
    if (normalizedPhone == null || normalizedPhone.isEmpty) {
      return null;
    }
    final rows = await executor.query(
      TableNames.customers,
      columns: const <String>['id'],
      where: 'phone = ?',
      whereArgs: <Object?>[normalizedPhone],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['id'] as String?;
  }
}
