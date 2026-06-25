import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import 'package:phone_shop_pos/core/config/shop_profile_providers.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_print_models.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/printing_providers.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

class InvoicePrintPreviewDialog extends ConsumerStatefulWidget {
  const InvoicePrintPreviewDialog({
    super.key,
    required this.jobId,
    required this.job,
  });

  final String jobId;
  final InvoicePrintJob job;

  @override
  ConsumerState<InvoicePrintPreviewDialog> createState() =>
      _InvoicePrintPreviewDialogState();
}

class _InvoicePrintPreviewDialogState
    extends ConsumerState<InvoicePrintPreviewDialog> {
  InvoicePaperSize _paperSize = InvoicePaperSize.thermal80;
  bool _isPrinting = false;

  @override
  Widget build(BuildContext context) {
    InvoicePrintJob? latestJob;
    for (final item in ref.watch(invoicePrintQueueProvider)) {
      if (item.id == widget.jobId) {
        latestJob = item;
        break;
      }
    }
    final job = latestJob ?? widget.job;
    final renderer = ref.watch(invoicePrintRendererProvider);
    final preview = renderer.render(
      document: job.document,
      paperSize: _paperSize,
      shopProfile: ref.watch(shopProfileProvider),
    );

    return AlertDialog(
      title: Text('Invoice Preview - ${job.invoiceNumber}'),
      content: SizedBox(
        width: 820,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text('Layout'),
                const SizedBox(width: 8),
                DropdownButton<InvoicePaperSize>(
                  value: _paperSize,
                  onChanged: _isPrinting
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() => _paperSize = value);
                        },
                  items: InvoicePaperSize.values
                      .map(
                        (size) => DropdownMenuItem<InvoicePaperSize>(
                          value: size,
                          child: Text(size.label),
                        ),
                      )
                      .toList(growable: false),
                ),
                const Spacer(),
                if (job.lastError != null)
                  Tooltip(
                    message: job.lastError!,
                    child: Icon(
                      Icons.warning_amber,
                      color: Theme.of(context).semantic.warning,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: _isPrinting ? null : _printPdf,
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Print PDF'),
                ),
                OutlinedButton.icon(
                  onPressed: _isPrinting ? null : _savePdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Save PDF'),
                ),
                OutlinedButton.icon(
                  onPressed: _isPrinting ? null : _sharePdf,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share / WhatsApp'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: AppRadii.xsRadius,
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    preview,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isPrinting ? null : () => Navigator.of(context).pop(),
          child: const Text('Print Later'),
        ),
        FilledButton.icon(
          onPressed: _isPrinting ? null : _printNow,
          icon: const Icon(Icons.print_outlined),
          label: Text(_isPrinting ? 'Printing...' : 'Print'),
        ),
      ],
    );
  }

  Future<void> _printNow() async {
    setState(() => _isPrinting = true);
    final result = await ref.read(invoicePrintQueueProvider.notifier).printJob(
          jobId: widget.jobId,
          paperSize: _paperSize,
        );
    if (!mounted) {
      return;
    }
    setState(() => _isPrinting = false);
    if (result.isSuccess) {
      AppNotifier.success(
        'Print job spooled: ${result.asSuccess!.value.path}',
      );
      Navigator.of(context).pop();
      return;
    }
    final error = result.asFailure!.error;
    AppNotifier.error(
      'Printing failed: ${error.message}',
      action: SnackBarAction(
        label: 'Retry',
        onPressed: _printNow,
      ),
    );
  }

  String _safeInvoiceName() {
    return widget.job.invoiceNumber.replaceAll(
      RegExp(r'[<>:"/\\|?*\x00-\x1F]'),
      '_',
    );
  }

  Future<Uint8List?> _generatePdfBytes() async {
    try {
      final renderer = ref.read(invoicePdfRendererProvider);
      return await renderer.build(
        document: widget.job.document,
        paperSize: _paperSize,
        shopProfile: ref.read(shopProfileProvider),
      );
    } catch (_) {
      if (mounted) {
        AppNotifier.error('Could not generate the PDF receipt.');
      }
      return null;
    }
  }

  Future<void> _printPdf() async {
    setState(() => _isPrinting = true);
    final bytes = await _generatePdfBytes();
    try {
      if (bytes != null) {
        await Printing.layoutPdf(
          name: _safeInvoiceName(),
          onLayout: (_) async => bytes,
        );
      }
    } catch (_) {
      if (mounted) {
        AppNotifier.error('Could not open the print dialog.');
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  Future<void> _savePdf() async {
    setState(() => _isPrinting = true);
    final bytes = await _generatePdfBytes();
    try {
      if (bytes != null) {
        final documentsDir = await getApplicationDocumentsDirectory();
        final receiptsDir = Directory(p.join(documentsDir.path, 'receipts'));
        if (!await receiptsDir.exists()) {
          await receiptsDir.create(recursive: true);
        }
        final filePath =
            p.join(receiptsDir.path, '${_safeInvoiceName()}.pdf');
        await File(filePath).writeAsBytes(bytes, flush: true);
        if (mounted) {
          AppNotifier.success('PDF receipt saved: $filePath');
        }
      }
    } catch (_) {
      if (mounted) {
        AppNotifier.error('Could not save the PDF receipt.');
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  Future<void> _sharePdf() async {
    setState(() => _isPrinting = true);
    final bytes = await _generatePdfBytes();
    try {
      if (bytes != null) {
        await Printing.sharePdf(
          bytes: bytes,
          filename: '${_safeInvoiceName()}.pdf',
        );
      }
    } catch (_) {
      if (mounted) {
        AppNotifier.error('Could not share the PDF receipt.');
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }
}
