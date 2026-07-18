import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_print_models.dart';
import 'package:phone_shop_pos/core/services/printing/print_job_repository.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/printing_providers.dart';

/// Manages the invoice print queue (retry / cancel failed or pending receipts).
///
/// Opened from the "Pending prints" chip in the top bar. This lived on the
/// Settings screen before, which had nothing to do with settings — the queue is
/// an operational concern surfaced next to where the count is shown.
class PrintQueueDialog extends ConsumerStatefulWidget {
  const PrintQueueDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const PrintQueueDialog(),
    );
  }

  @override
  ConsumerState<PrintQueueDialog> createState() => _PrintQueueDialogState();
}

class _PrintQueueDialogState extends ConsumerState<PrintQueueDialog> {
  Future<void> _retryPrintJob(InvoicePrintJob job) async {
    final result = await ref.read(invoicePrintQueueProvider.notifier).printJob(
          jobId: job.id,
          paperSize: InvoicePaperSize.thermal80,
        );
    if (!mounted) {
      return;
    }
    final message = result.fold(
      onSuccess: (value) => 'Receipt queued to spool: ${value.path}',
      onFailure: (error) => 'Print retry failed: ${error.message}',
    );
    if (result.isSuccess) {
      AppNotifier.success(message);
    } else {
      AppNotifier.error(message);
    }
  }

  Future<void> _cancelPrintJob(InvoicePrintJob job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (context) => const AppConfirmationDialog(
        title: 'Cancel queued receipt?',
        message:
            'This will remove the receipt from the active print queue. Use this only if the receipt is no longer needed.',
        confirmLabel: 'Cancel Receipt',
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final result =
        await ref.read(invoicePrintQueueProvider.notifier).cancel(job.id);
    if (!mounted) {
      return;
    }
    if (result.isSuccess) {
      AppNotifier.info('Receipt removed from the active queue.');
    } else {
      AppNotifier.error(result.asFailure!.error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final printQueue = ref.watch(invoicePrintQueueProvider);
    return AlertDialog(
      title: const Text('Invoice Print Queue'),
      content: AppDialogContentBox(
        width: 560,
        child: printQueue.isEmpty
            ? const Text('No queued or failed receipts.')
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: printQueue.map(_buildJobTile).toList(growable: false),
                ),
              ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildJobTile(InvoicePrintJob job) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(job.invoiceNumber),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 2),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              AppStatusBadge(
                label: job.status.label,
                color: switch (job.status) {
                  InvoicePrintJobStatus.pending =>
                    Theme.of(context).colorScheme.onSurfaceVariant,
                  InvoicePrintJobStatus.processing =>
                    Theme.of(context).semantic.info,
                  InvoicePrintJobStatus.completed =>
                    Theme.of(context).semantic.success,
                  InvoicePrintJobStatus.failed =>
                    Theme.of(context).semantic.warning,
                  InvoicePrintJobStatus.cancelled =>
                    Theme.of(context).colorScheme.onSurfaceVariant,
                },
              ),
              Text(
                'Retries: ${job.retryCount}/${PrintJobRepository.retryLimit}',
              ),
            ],
          ),
          Text(
            'Queued: ${FormattingHelpers.dateYmdHm(job.createdAt)} • '
            'Updated: ${FormattingHelpers.dateYmdHm(job.updatedAt)}',
          ),
          if (job.lastError != null) Text('Operator note: ${job.lastError}'),
        ],
      ),
      trailing: Wrap(
        spacing: 4,
        children: <Widget>[
          IconButton(
            tooltip: 'Retry print',
            onPressed: !job.status.canRetry || job.retryLimitReached
                ? null
                : () => _retryPrintJob(job),
            icon: const Icon(Icons.print_outlined),
          ),
          IconButton(
            tooltip: 'Cancel queued receipt',
            onPressed: job.status == InvoicePrintJobStatus.processing ||
                    job.status == InvoicePrintJobStatus.completed ||
                    job.status == InvoicePrintJobStatus.cancelled
                ? null
                : () => _cancelPrintJob(job),
            icon: const Icon(Icons.cancel_outlined),
          ),
        ],
      ),
    );
  }
}
