import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/providers/dealer_issue_state_provider.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/widgets/dealer_issue_table_widget.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/widgets/dealer_issue_filter_widget.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/widgets/dealer_issue_dialog_widget.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/widgets/scan_return_dialog.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

class DealerIssueScreen extends ConsumerStatefulWidget {
  const DealerIssueScreen({super.key});

  @override
  ConsumerState<DealerIssueScreen> createState() => _DealerIssueScreenState();
}

class _DealerIssueScreenState extends ConsumerState<DealerIssueScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(dealerIssueStateProvider.notifier).loadIssues();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dealerIssueStateProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildHeader(),
            const SizedBox(height: AppSpacing.sm),
            DealerIssueFilterWidget(
              onDealerSelected: (dealerId) {
                ref.read(dealerIssueStateProvider.notifier).selectDealer(dealerId ?? '');
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: DealerIssueTableWidget(
                issues: state.issues,
                isLoading: state.isLoading,
                selectedDealerId: state.selectedDealerId,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: () async {
            final returned = await showDialog<bool>(
              context: context,
              builder: (_) => const ScanReturnDialog(),
            );
            if (returned == true) {
              ref.read(dealerIssueStateProvider.notifier).loadIssues();
            }
          },
          icon: const Icon(Icons.qr_code_scanner, size: 18),
          label: const Text('Scan Return'),
        ),
        const SizedBox(width: AppSpacing.sm),
        FilledButton.icon(
          onPressed: () async {
            final issued = await showDialog<bool>(
              context: context,
              builder: (context) => const DealerIssueDialogWidget(),
            );
            if (issued == true) {
              ref.read(dealerIssueStateProvider.notifier).loadIssues();
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('Issue Device'),
        ),
      ],
    );
  }
}