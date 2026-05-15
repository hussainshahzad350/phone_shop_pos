import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_print_models.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_print_renderer.dart';
import 'package:phone_shop_pos/core/services/printing/printer_service.dart';

class InvoicePrintQueueNotifier extends StateNotifier<List<InvoicePrintJob>> {
  InvoicePrintQueueNotifier(this._ref) : super(const <InvoicePrintJob>[]);

  final Ref _ref;

  String enqueue(InvoicePrintDocument document) {
    final nowUtc = DateTime.now().toUtc();
    final id = '${document.saleId}_${nowUtc.microsecondsSinceEpoch}';
    final job = InvoicePrintJob(
      id: id,
      invoiceNumber: document.invoiceNumber,
      document: document,
      createdAt: nowUtc,
    );
    state = <InvoicePrintJob>[job, ...state];
    return id;
  }

  Future<Result<PrinterReceiptArtifact>> printJob({
    required String jobId,
    required InvoicePaperSize paperSize,
  }) async {
    final job = findById(jobId);
    if (job == null) {
      return const Failure<PrinterReceiptArtifact>(
        AppError(code: 'print_job_not_found', message: 'Print job not found.'),
      );
    }

    final renderer = _ref.read(invoicePrintRendererProvider);
    final printerService = await _ref.read(printerServiceProvider.future);
    final renderedPayload = renderer.render(
      document: job.document,
      paperSize: paperSize,
    );

    final result = await printerService.printInvoice(
      renderedPayload: renderedPayload,
      job: job,
      paperSize: paperSize,
    );

    if (result.isSuccess) {
      state = state.where((item) => item.id != jobId).toList(growable: false);
      return result;
    }

    final failed = job.copyWith(
      attempts: job.attempts + 1,
      lastError: result.asFailure!.error.message,
    );
    state = state
        .map((item) => item.id == jobId ? failed : item)
        .toList(growable: false);
    return result;
  }

  void remove(String jobId) {
    state = state.where((item) => item.id != jobId).toList(growable: false);
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

final printerServiceProvider = FutureProvider<PrinterService>((ref) async {
  final appSupportDir = await getApplicationSupportDirectory();
  final spoolDirectoryPath = p.join(appSupportDir.path, 'print_spool');
  return FileSpoolPrinterService(spoolDirectoryPath: spoolDirectoryPath);
});

final invoicePrintQueueProvider =
    StateNotifierProvider<InvoicePrintQueueNotifier, List<InvoicePrintJob>>(
      (ref) => InvoicePrintQueueNotifier(ref),
    );
