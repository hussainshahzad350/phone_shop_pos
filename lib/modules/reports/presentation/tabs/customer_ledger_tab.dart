import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/party_summary_card_entity.dart';
import 'package:phone_shop_pos/modules/ledger/presentation/ledger_timeline_labels.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_ledger_overview.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_tab_error_view.dart';

class CustomerLedgerTab extends ConsumerWidget {
  const CustomerLedgerTab({
    super.key,
    required this.onOpenLedger,
  });

  final Future<void> Function(PartySummaryCardEntity summary) onOpenLedger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(customerLedgerSummaryProvider);

    return summaryAsync.when(
      data: (rows) => ReportLedgerOverview(
        title: 'Outstanding customer balances',
        tableTitle: 'Customer Ledger',
        partyHeader: 'Customer',
        openLabel: 'Open customer account',
        summaries: rows,
        displayName: normalizeCustomerLedgerName,
        onOpenLedger: (summary) => onOpenLedger(summary),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, __) => ReportTabErrorView(
        message: 'Failed to load customer ledgers.',
        error: error,
        onRetry: () => ref.invalidate(customerLedgerSummaryProvider),
      ),
    );
  }
}
