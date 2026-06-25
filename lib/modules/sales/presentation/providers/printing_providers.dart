import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:phone_shop_pos/core/config/shop_profile_providers.dart';
import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/services/operations/operation_manager.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_pdf_renderer.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_print_models.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_print_renderer.dart';
import 'package:phone_shop_pos/core/services/printing/print_job_repository.dart';
import 'package:phone_shop_pos/core/services/printing/printer_service.dart';

class InvoicePrintQueueNotifier extends StateNotifier<List<InvoicePrintJob>> {
  InvoicePrintQueueNotifier(this._ref) : super(const <InvoicePrintJob>[]) {
    _bootstrap();
  }

  final Ref _ref;

  Future<void> _bootstrap() async {
    final repository = await _ref.read(printJobRepositoryProvider.future);
    await repository.recoverAndCleanup();
    await refresh();
  }

  Future<void> refresh() async {
    final repository = await _ref.read(printJobRepositoryProvider.future);
    final jobsResult = await repository.loadJobs();
    if (jobsResult.isSuccess) {
      state = jobsResult.asSuccess!.value;
    }
  }

  Future<Result<String>> enqueue(InvoicePrintDocument document) async {
    final repository = await _ref.read(printJobRepositoryProvider.future);
    final result = await repository.enqueue(document);
    if (result.isSuccess) {
      await refresh();
      return Success<String>(result.asSuccess!.value.id);
    }
    return Failure<String>(result.asFailure!.error);
  }

  Future<Result<PrinterReceiptArtifact>> printJob({
    required String jobId,
    required InvoicePaperSize paperSize,
  }) async {
    final repository = await _ref.read(printJobRepositoryProvider.future);
    final currentJob = await repository.getJobById(jobId);
    if (currentJob.isFailure || currentJob.asSuccess?.value == null) {
      return const Failure<PrinterReceiptArtifact>(
        AppError(code: 'print_job_not_found', message: 'Receipt job not found.'),
      );
    }

    final job = currentJob.asSuccess!.value!;
    if (job.retryLimitReached) {
      return const Failure<PrinterReceiptArtifact>(
        AppError(
          code: 'print_retry_limit_reached',
          message: 'Retry limit reached. Fix the printer issue before retrying.',
        ),
      );
    }

    return _ref.read(operationManagerProvider.notifier).track<
      Result<PrinterReceiptArtifact>
    >(
      code: 'print_receipt',
      label: 'Printing receipt ${job.invoiceNumber}',
      progressLabel: 'Writing receipt to local print spool',
      action: (_) async {
        final markProcessingResult = await repository.markProcessing(jobId);
        if (markProcessingResult.isFailure) {
          return Failure<PrinterReceiptArtifact>(markProcessingResult.asFailure!.error);
        }
        await refresh();

        final renderer = _ref.read(invoicePrintRendererProvider);
        final printerService = await _ref.read(printerServiceProvider.future);
        final renderedPayload = renderer.render(
          document: job.document,
          paperSize: paperSize,
          shopProfile: _ref.read(shopProfileProvider),
        );

        final result = await printerService.printInvoice(
          renderedPayload: renderedPayload,
          job: job,
          paperSize: paperSize,
        );

        if (result.isSuccess) {
          await repository.markCompleted(jobId);
        } else {
          await repository.markFailed(
            jobId: jobId,
            message: result.asFailure!.error.message,
          );
        }
        await refresh();
        return result;
      },
    );
  }

  Future<Result<void>> cancel(String jobId) async {
    final repository = await _ref.read(printJobRepositoryProvider.future);
    final result = await repository.cancel(jobId);
    if (result.isSuccess) {
      await refresh();
      return const Success<void>(null);
    }
    return Failure<void>(result.asFailure!.error);
  }

  InvoicePrintJob? findById(String jobId) {
    for (final item in state) {
      if (item.id == jobId) {
        return item;
      }
    }
    return null;
  }
}

final invoicePrintRendererProvider = Provider<InvoicePrintRenderer>(
  (ref) => const InvoicePrintRenderer(),
);

final invoicePdfRendererProvider = Provider<InvoicePdfRenderer>(
  (ref) => const InvoicePdfRenderer(),
);

final printerServiceProvider = FutureProvider<PrinterService>((ref) async {
  final appSupportDir = await getApplicationSupportDirectory();
  final spoolDirectoryPath = p.join(appSupportDir.path, 'print_spool');
  return FileSpoolPrinterService(spoolDirectoryPath: spoolDirectoryPath);
});

final printJobRepositoryProvider = FutureProvider<PrintJobRepository>((ref) async {
  final appDatabase = await ref.watch(appDatabaseProvider.future);
  return PrintJobRepository(appDatabase: appDatabase);
});

final invoicePrintQueueProvider =
    StateNotifierProvider<InvoicePrintQueueNotifier, List<InvoicePrintJob>>(
      (ref) => InvoicePrintQueueNotifier(ref),
    );

final actionablePrintJobsProvider = Provider<List<InvoicePrintJob>>((ref) {
  return ref
      .watch(invoicePrintQueueProvider)
      .where(
        (job) =>
            job.status == InvoicePrintJobStatus.pending ||
            job.status == InvoicePrintJobStatus.processing ||
            job.status == InvoicePrintJobStatus.failed,
      )
      .toList(growable: false);
});

final pendingPrintJobCountProvider = Provider<int>((ref) {
  return ref.watch(actionablePrintJobsProvider).length;
});
