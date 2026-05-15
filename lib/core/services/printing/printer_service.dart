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

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = p.join(
        spoolDirectoryPath,
        '${job.invoiceNumber}_${paperSize.name}_$timestamp.txt',
      );
      final file = File(filePath);
      await file.writeAsString(renderedPayload);

      return Success<PrinterReceiptArtifact>(
        PrinterReceiptArtifact(path: filePath, createdAt: DateTime.now()),
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
