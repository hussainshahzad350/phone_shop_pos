import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/core/database/table_names.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/dealer_issue/domain/entities/dealer_entity.dart';
import 'package:phone_shop_pos/modules/dealer_issue/domain/entities/dealer_issue_entity.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/providers/dealer_issue_state_provider.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/providers/dealer_providers.dart';

class ScanReturnDialog extends ConsumerStatefulWidget {
  const ScanReturnDialog({super.key});

  @override
  ConsumerState<ScanReturnDialog> createState() => _ScanReturnDialogState();
}

class _ScanReturnDialogState extends ConsumerState<ScanReturnDialog> {
  final _imeiController = TextEditingController();
  final _focusNode = FocusNode();

  bool _searching = false;
  String? _errorMessage;
  _FoundIssue? _found;
  bool _returning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _imeiController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final imei = _imeiController.text.trim();
    if (imei.isEmpty) return;

    setState(() {
      _searching = true;
      _errorMessage = null;
      _found = null;
    });

    final db = ref.read(appDatabaseProvider).value;
    if (db == null) {
      setState(() {
        _searching = false;
        _errorMessage = 'Database not ready';
      });
      return;
    }

    final stockRows = await db.database.rawQuery('''
      SELECT s.id as stock_id, s.imei1, s.imei2
      FROM ${TableNames.serializedStock} s
      WHERE (s.imei1 = ? OR s.imei2 = ?) AND s.stock_status = 'with_dealer'
      LIMIT 1
    ''', [imei, imei]);

    if (stockRows.isEmpty) {
      setState(() {
        _searching = false;
        _errorMessage = 'IMEI $imei is not currently issued to any dealer';
      });
      return;
    }

    final issueRows = await db.database.rawQuery('''
      SELECT di.*
      FROM ${TableNames.dealerIssues} di
      WHERE di.return_status = 0 AND di.sold_status = 0
        AND (di.imei_list = ? OR di.imei_list LIKE ? OR di.imei_list LIKE ? OR di.imei_list LIKE ?)
      LIMIT 1
    ''', [imei, '$imei,%', '%,$imei,%', '%,$imei']);

    if (issueRows.isEmpty) {
      setState(() {
        _searching = false;
        _errorMessage = 'No active issue record found for IMEI $imei';
      });
      return;
    }

    final issue = DealerIssueEntity.fromMap(
        Map<String, dynamic>.from(issueRows.first));

    final dealers = await ref.read(dealerListProvider.future);
    final dealer = dealers.where((d) => d.id == issue.dealerId).firstOrNull;

    setState(() {
      _searching = false;
      _found = _FoundIssue(issue: issue, dealer: dealer, scannedImei: imei);
    });
  }

  Future<void> _confirmReturn() async {
    if (_found == null) return;
    setState(() => _returning = true);

    await ref
        .read(dealerIssueStateProvider.notifier)
        .markAsReturned(_found!.issue.issueId);

    setState(() => _returning = false);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Scan Return'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _imeiController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                labelText: 'Scan or enter IMEI',
                border: const OutlineInputBorder(),
                isDense: true,
                prefixIcon: const Icon(Icons.qr_code_scanner, size: 18),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.search, size: 18),
                        onPressed: _lookup,
                      ),
              ),
              onSubmitted: (_) => _lookup(),
            ),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ],
            if (_found != null) ...<Widget>[
              const SizedBox(height: 16),
              _FoundIssueCard(found: _found!),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
        if (_found != null)
          FilledButton.icon(
            onPressed: _returning ? null : _confirmReturn,
            icon: _returning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Confirm Return'),
          ),
      ],
    );
  }
}

class _FoundIssue {
  const _FoundIssue({
    required this.issue,
    required this.dealer,
    required this.scannedImei,
  });

  final DealerIssueEntity issue;
  final DealerEntity? dealer;
  final String scannedImei;
}

class _FoundIssueCard extends StatelessWidget {
  const _FoundIssueCard({required this.found});

  final _FoundIssue found;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final issue = found.issue;
    final dealer = found.dealer;

    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.person_outline,
                    size: 16,
                    color: theme.colorScheme.onSecondaryContainer),
                const SizedBox(width: 6),
                Text(
                  dealer?.name ?? 'Unknown Dealer',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Issued: ${FormattingHelpers.dateYmd(issue.issueDate)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            Text(
              '${issue.imeiList.length} item${issue.imeiList.length == 1 ? '' : 's'} in this issue',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Scanned: ${found.scannedImei}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
