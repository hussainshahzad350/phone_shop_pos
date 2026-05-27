import 'package:flutter/material.dart';

import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/ledger_timeline_row_entity.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/party_summary_card_entity.dart';

class LedgerSummaryCards extends StatelessWidget {
  const LedgerSummaryCards({
    super.key,
    required this.summary,
    required this.balanceLabel,
  });

  final PartySummaryCardEntity summary;
  final String balanceLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _SummaryCard(
            title: 'Receivable',
            value: FormattingHelpers.currencyPkr(summary.totalReceivable),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            title: 'Payable',
            value: FormattingHelpers.currencyPkr(summary.totalPayable),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            title: balanceLabel,
            value: FormattingHelpers.currencyPkr(summary.netBalance),
          ),
        ),
      ],
    );
  }
}

class LedgerTimelineTable extends StatelessWidget {
  const LedgerTimelineTable({super.key, required this.rows});

  final List<LedgerTimelineRowEntity> rows;

  @override
  Widget build(BuildContext context) {
    return AppDataTable(
      showCheckboxColumn: false,
      emptyMessage: 'No ledger events found.',
      columns: const <DataColumn>[
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Type')),
        DataColumn(label: Text('Source')),
        DataColumn(label: Text('Dr')),
        DataColumn(label: Text('Cr')),
        DataColumn(label: Text('Running')),
        DataColumn(label: Text('Note')),
      ],
      rows: rows.map((row) {
        final isDebit = row.direction.value == 'debit';
        return DataRow(cells: <DataCell>[
          DataCell(Text(FormattingHelpers.dateYmd(row.createdAt))),
          DataCell(Text(row.ledgerType)),
          DataCell(Text(row.sourceLabel)),
          DataCell(Text(isDebit ? FormattingHelpers.decimal(row.amount) : '-')),
          DataCell(Text(!isDebit ? FormattingHelpers.decimal(row.amount) : '-')),
          DataCell(Text(FormattingHelpers.decimal(row.runningBalance))),
          DataCell(Text(row.note ?? '-')),
        ]);
      }).toList(growable: false),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
