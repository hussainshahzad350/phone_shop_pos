import 'dart:convert';

import 'package:phone_shop_pos/core/database/app_database.dart';
import 'package:phone_shop_pos/core/database/base_repository.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_print_models.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';

class PrintJobRepository with BaseRepositoryGuard {
  PrintJobRepository({required AppDatabase appDatabase}) : _appDatabase = appDatabase;

  static const int retryLimit = 3;
  static const Duration staleProcessingWindow = Duration(minutes: 10);
  static const Duration completedRetention = Duration(days: 7);
  static const Duration cancelledRetention = Duration(days: 3);
  static const Duration failedRetention = Duration(days: 30);

  final AppDatabase _appDatabase;

  Future<Result<void>> recoverAndCleanup() {
    return guard<void>(() async {
      final now = DateTimeHelpers.nowUtc();
      await _recoverStaleProcessingJobs(now);
      await _cleanupTerminalJobs(now);
    }, operation: 'recover_print_queue');
  }

  Future<Result<List<InvoicePrintJob>>> loadJobs({int limit = 200}) {
    return guard<List<InvoicePrintJob>>(() async {
      final rows = await _appDatabase.database.rawQuery(
        '''
        SELECT *
        FROM ${TableNames.printJobs}
        ORDER BY
          CASE status
            WHEN 'processing' THEN 0
            WHEN 'failed' THEN 1
            WHEN 'pending' THEN 2
            WHEN 'cancelled' THEN 3
            ELSE 4
          END,
          updated_at DESC
        LIMIT ?
        ''',
        <Object?>[limit],
      );
      return rows.map(_jobFromRow).toList(growable: false);
    }, operation: 'load_print_jobs');
  }

  Future<Result<InvoicePrintJob?>> getJobById(String jobId) {
    return guard<InvoicePrintJob?>(() async {
      final rows = await _appDatabase.queryTable(
        TableNames.printJobs,
        where: 'id = ?',
        whereArgs: <Object?>[jobId],
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      return _jobFromRow(rows.first);
    }, operation: 'get_print_job');
  }

  Future<Result<InvoicePrintJob>> enqueue(InvoicePrintDocument document) {
    return guard<InvoicePrintJob>(() async {
      final saleId = document.saleId.trim();
      if (saleId.isEmpty) {
        throw StateError('Print job is missing sale id.');
      }
      final existingResult = await getBySaleId(saleId);
      if (existingResult.isFailure) {
        throw StateError(existingResult.asFailure!.error.message);
      }
      final existing = existingResult.asSuccess!.value;
      if (existing != null) {
        return existing;
      }

      final now = DateTimeHelpers.nowUtc();
      final job = InvoicePrintJob(
        id: 'prt_${now.microsecondsSinceEpoch}',
        invoiceNumber: document.invoiceNumber,
        document: document,
        createdAt: now,
        updatedAt: now,
      );
      await _appDatabase.insert(TableNames.printJobs, _serialize(job));
      return job;
    }, operation: 'enqueue_print_job');
  }

  Future<Result<InvoicePrintJob?>> getBySaleId(String saleId) {
    return guard<InvoicePrintJob?>(() async {
      final rows = await _appDatabase.queryTable(
        TableNames.printJobs,
        where: 'sale_id = ?',
        whereArgs: <Object?>[saleId],
        limit: 1,
      );
      if (rows.isEmpty) {
        return null;
      }
      return _jobFromRow(rows.first);
    }, operation: 'get_print_job_by_sale');
  }

  Future<Result<InvoicePrintJob>> markProcessing(String jobId) {
    return guard<InvoicePrintJob>(() async {
      final job = await _requireJob(jobId);
      if (job.status == InvoicePrintJobStatus.completed) {
        throw StateError('Receipt already printed for this sale.');
      }
      if (!job.status.canRetry) {
        throw StateError('This print job cannot be retried.');
      }
      if (job.retryLimitReached) {
        throw StateError('Retry limit reached. Review the printer before retrying.');
      }
      final updated = job.copyWith(
        status: InvoicePrintJobStatus.processing,
        updatedAt: DateTimeHelpers.nowUtc(),
        clearLastError: true,
      );
      await _appDatabase.update(
        TableNames.printJobs,
        _serialize(updated),
        where: 'id = ?',
        whereArgs: <Object?>[jobId],
      );
      return updated;
    }, operation: 'mark_print_job_processing');
  }

  Future<Result<InvoicePrintJob>> markCompleted(String jobId) {
    return guard<InvoicePrintJob>(() async {
      final job = await _requireJob(jobId);
      final updated = job.copyWith(
        status: InvoicePrintJobStatus.completed,
        updatedAt: DateTimeHelpers.nowUtc(),
        clearLastError: true,
      );
      await _appDatabase.update(
        TableNames.printJobs,
        _serialize(updated),
        where: 'id = ?',
        whereArgs: <Object?>[jobId],
      );
      return updated;
    }, operation: 'mark_print_job_completed');
  }

  Future<Result<InvoicePrintJob>> markFailed({
    required String jobId,
    required String message,
  }) {
    return guard<InvoicePrintJob>(() async {
      final job = await _requireJob(jobId);
      final updated = job.copyWith(
        status: InvoicePrintJobStatus.failed,
        retryCount: job.retryCount + 1,
        updatedAt: DateTimeHelpers.nowUtc(),
        lastError: message,
      );
      await _appDatabase.update(
        TableNames.printJobs,
        _serialize(updated),
        where: 'id = ?',
        whereArgs: <Object?>[jobId],
      );
      return updated;
    }, operation: 'mark_print_job_failed');
  }

  Future<Result<InvoicePrintJob>> cancel(String jobId) {
    return guard<InvoicePrintJob>(() async {
      final job = await _requireJob(jobId);
      final updated = job.copyWith(
        status: InvoicePrintJobStatus.cancelled,
        updatedAt: DateTimeHelpers.nowUtc(),
        lastError: 'Cancelled by operator.',
      );
      await _appDatabase.update(
        TableNames.printJobs,
        _serialize(updated),
        where: 'id = ?',
        whereArgs: <Object?>[jobId],
      );
      return updated;
    }, operation: 'cancel_print_job');
  }

  Future<InvoicePrintJob> _requireJob(String jobId) async {
    final rows = await _appDatabase.queryTable(
      TableNames.printJobs,
      where: 'id = ?',
      whereArgs: <Object?>[jobId],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Print job not found.');
    }
    return _jobFromRow(rows.first);
  }

  Future<void> _recoverStaleProcessingJobs(DateTime now) async {
    final staleThreshold = DateTimeHelpers.toSql(now.subtract(staleProcessingWindow));
    final rows = await _appDatabase.queryTable(
      TableNames.printJobs,
      where: 'status = ? AND updated_at <= ?',
      whereArgs: <Object?>[
        InvoicePrintJobStatus.processing.value,
        staleThreshold,
      ],
    );
    for (final row in rows) {
      final job = _jobFromRow(row);
      final updated = job.copyWith(
        status: InvoicePrintJobStatus.failed,
        updatedAt: now,
        lastError:
            'The app restarted while this receipt was printing. Check the printer before retrying.',
      );
      await _appDatabase.update(
        TableNames.printJobs,
        _serialize(updated),
        where: 'id = ?',
        whereArgs: <Object?>[job.id],
      );
    }
  }

  Future<void> _cleanupTerminalJobs(DateTime now) async {
    await _appDatabase.delete(
      TableNames.printJobs,
      where: 'status = ? AND updated_at <= ?',
      whereArgs: <Object?>[
        InvoicePrintJobStatus.completed.value,
        DateTimeHelpers.toSql(now.subtract(completedRetention)),
      ],
    );
    await _appDatabase.delete(
      TableNames.printJobs,
      where: 'status = ? AND updated_at <= ?',
      whereArgs: <Object?>[
        InvoicePrintJobStatus.cancelled.value,
        DateTimeHelpers.toSql(now.subtract(cancelledRetention)),
      ],
    );
    await _appDatabase.delete(
      TableNames.printJobs,
      where: 'status = ? AND updated_at <= ?',
      whereArgs: <Object?>[
        InvoicePrintJobStatus.failed.value,
        DateTimeHelpers.toSql(now.subtract(failedRetention)),
      ],
    );
  }

  Map<String, Object?> _serialize(InvoicePrintJob job) {
    return <String, Object?>{
      'id': job.id,
      'sale_id': job.saleId,
      'invoice_number': job.invoiceNumber,
      'document_json': jsonEncode(job.document.toMap()),
      'status': job.status.value,
      'retry_count': job.retryCount,
      'last_error': job.lastError,
      'created_at': DateTimeHelpers.toSql(job.createdAt),
      'updated_at': DateTimeHelpers.toSql(job.updatedAt),
    };
  }

  InvoicePrintJob _jobFromRow(Map<String, Object?> row) {
    final decoded = jsonDecode(row['document_json'] as String? ?? '{}');
    final documentMap = Map<String, Object?>.from(decoded as Map);
    return InvoicePrintJob(
      id: row['id'] as String? ?? '',
      invoiceNumber: row['invoice_number'] as String? ?? '',
      document: InvoicePrintDocument.fromMap(documentMap),
      createdAt: DateTimeHelpers.fromSql(
        row['created_at'] as String? ?? DateTimeHelpers.toSql(DateTimeHelpers.nowUtc()),
      ),
      updatedAt: DateTimeHelpers.fromSql(
        row['updated_at'] as String? ?? DateTimeHelpers.toSql(DateTimeHelpers.nowUtc()),
      ),
      status: InvoicePrintJobStatusParser.fromValue(
        row['status'] as String? ?? InvoicePrintJobStatus.pending.value,
      ),
      retryCount: (row['retry_count'] as num?)?.toInt() ?? 0,
      lastError: row['last_error'] as String?,
    );
  }
}
