import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/party_summary_card_entity.dart';
import 'package:phone_shop_pos/modules/ledger/presentation/ledger_timeline_labels.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_ledger_overview.dart';

class SupplierLedgerTab extends ConsumerWidget {
  const SupplierLedgerTab({
    super.key,
    required this.onOpenLedger,
  });

  final Future<void> Function(PartySummaryCardEntity summary) onOpenLedger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(supplierLedgerSummaryProvider);

    return summaryAsync.when(
      data: (rows) => ReportLedgerOverview(
        title: 'Outstanding supplier balances',
        tableTitle: 'Supplier Ledger',
        partyHeader: 'Supplier',
        openLabel: 'Open supplier account',
        summaries: rows,
        displayName: normalizeSupplierLedgerName,
        onOpenLedger: (summary) => onOpenLedger(summary),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, __) => _TabErrorView(
        message: 'Failed to load supplier ledgers.',
        error: error,
        onRetry: () => ref.invalidate(supplierLedgerSummaryProvider),
      ),
    );
  }
}

class _TabErrorView extends StatelessWidget {
  const _TabErrorView({
    required this.message,
    required this.error,
    required this.onRetry,
  });

  final String message;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final details = error is AppError ? (error as AppError).message : '$error';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(message),
          const SizedBox(height: 6),
          Text(details, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
