import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_print_models.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/printing_providers.dart';

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
            Flexible(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
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
}
