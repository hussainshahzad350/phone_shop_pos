import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_print_models.dart';

class PrinterReceiptArtifact {
  const PrinterReceiptArtifact({
    required this.path,
    required this.createdAt,
  });

  final String path;
  final DateTime createdAt;
}

abstract class PrinterService {
  Future<Result<PrinterReceiptArtifact>> printInvoice({
    required String renderedPayload,
    required InvoicePrintJob job,
    required InvoicePaperSize paperSize,
  });
}

class FileSpoolPrinterService implements PrinterService {
  const FileSpoolPrinterService({
    required this.spoolDirectoryPath,
  });

  final String spoolDirectoryPath;

  @override
  Future<Result<PrinterReceiptArtifact>> printInvoice({
    required String renderedPayload,
    required InvoicePrintJob job,
    required InvoicePaperSize paperSize,
  }) async {
    try {
      if (renderedPayload.trim().isEmpty) {
        return const Failure<PrinterReceiptArtifact>(
          AppError(
            code: 'print_payload_empty',
            message: 'Invoice preview is empty and cannot be printed.',
          ),
        );
      }

      final directory = Directory(spoolDirectoryPath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final nowUtc = DateTime.now().toUtc();
      final timestamp = nowUtc.millisecondsSinceEpoch;
      final safeInvoiceNumber = job.invoiceNumber.replaceAll(
        RegExp(r'[<>:"/\\|?*\x00-\x1F]'),
        '_',
      );
      final filePath = p.join(
        spoolDirectoryPath,
        '${safeInvoiceNumber}_${paperSize.name}_$timestamp.txt',
      );
      final tempPath = '$filePath.tmp';
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      await tempFile.writeAsString(renderedPayload, flush: true);
      await tempFile.rename(filePath);

      return Success<PrinterReceiptArtifact>(
        PrinterReceiptArtifact(path: filePath, createdAt: nowUtc),
      );
    } catch (error) {
      return Failure<PrinterReceiptArtifact>(
        AppError(
          code: 'printer_spool_failed',
          message: 'Could not write print job to local spool directory.',
          details: error,
        ),
      );
    }
  }
}
