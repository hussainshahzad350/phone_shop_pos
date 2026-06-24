import 'package:flutter/material.dart';

import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/ledger_timeline_row_entity.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/party_summary_card_entity.dart';
import 'package:phone_shop_pos/modules/ledger/presentation/ledger_timeline_labels.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_styling.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

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
  const LedgerTimelineTable({
    super.key,
    required this.rows,
    required this.typeLabelBuilder,
    this.emptyMessage = 'No transactions found.',
  });

  final List<LedgerTimelineRowEntity> rows;
  final String Function(String ledgerType) typeLabelBuilder;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final layout = reportTableLayoutFor(context);
    final sorted = newestFirstTimeline(rows);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppDataTable(
      showCheckboxColumn: false,
      emptyMessage: emptyMessage,
      columnSpacing: layout.columnSpacing,
      dataRowMinHeight: layout.dataRowMinHeight,
      dataRowMaxHeight: layout.dataRowMaxHeight,
      columns: <DataColumn>[
        DataColumn(
          label: reportStyledTableHeaderCell(context, 'Date & Time', width: 150),
        ),
        DataColumn(
          label: reportStyledTableHeaderCell(context, 'Transaction', width: 200),
        ),
        DataColumn(
          label: reportStyledTableHeaderCell(context, 'Money In (PKR)', width: 130),
        ),
        DataColumn(
          label: reportStyledTableHeaderCell(context, 'Money Out (PKR)', width: 130),
        ),
        DataColumn(
          label: reportStyledTableHeaderCell(context, 'Balance (PKR)', width: 130),
        ),
        DataColumn(
          label: reportStyledTableHeaderCell(context, 'Payment', width: 100),
        ),
        DataColumn(
          label: reportStyledTableHeaderCell(context, 'Reference', width: 140),
        ),
        DataColumn(
          label: reportStyledTableHeaderCell(context, 'Note', width: 180),
        ),
      ],
      rows: sorted.map((row) {
        final isMoneyIn = row.direction.value == 'credit';
        final badges = <Widget>[];
        if (row.isReversal) {
          badges.add(
            reportStyledStatusCell(
              context,
              'Reversed',
              colorScheme.errorContainer,
              colorScheme.onErrorContainer,
            ),
          );
        }
        return DataRow(
          cells: <DataCell>[
            DataCell(
              reportStyledTableCell(
                FormattingHelpers.dateYmdHm(row.createdAt),
                width: 150,
              ),
            ),
            DataCell(
              SizedBox(
                width: 200,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      typeLabelBuilder(row.ledgerType),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (badges.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Wrap(spacing: 4, children: badges),
                      ),
                  ],
                ),
              ),
            ),
            DataCell(
              reportStyledTableCell(
                isMoneyIn ? FormattingHelpers.decimal(row.amount) : '-',
                width: 130,
              ),
            ),
            DataCell(
              reportStyledTableCell(
                !isMoneyIn ? FormattingHelpers.decimal(row.amount) : '-',
                width: 130,
              ),
            ),
            DataCell(
              reportStyledTableCell(
                FormattingHelpers.decimal(row.runningBalance),
                width: 130,
              ),
            ),
            DataCell(
              reportStyledTableCell(row.paymentMethod ?? '-', width: 100),
            ),
            DataCell(
              reportStyledTableCell(row.transactionId, width: 140),
            ),
            DataCell(
              reportStyledTableCell(row.note ?? '-', width: 180),
            ),
          ],
        );
      }).toList(growable: false),
    );
  }
}

class LedgerDetailSummaryStrip extends StatelessWidget {
  const LedgerDetailSummaryStrip({
    super.key,
    required this.cards,
    this.highlightIndex = 0,
  });

  final List<LedgerSummaryMetric> cards;
  final int highlightIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1100
            ? 5
            : width >= 720
                ? 3
                : 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List<Widget>.generate(cards.length, (index) {
            final card = cards[index];
            final highlighted = index == highlightIndex;
            return SizedBox(
              width: columns == 5
                  ? (width - 32) / 5
                  : columns == 3
                      ? (width - 16) / 3
                      : (width - 8) / 2,
              child: _SummaryCard(
                title: card.title,
                value: card.value,
                emphasized: highlighted,
              ),
            );
          }),
        );
      },
    );
  }
}

class LedgerSummaryMetric {
  const LedgerSummaryMetric({required this.title, required this.value});

  final String title;
  final String value;
}

class LedgerTimelineCardList extends StatelessWidget {
  const LedgerTimelineCardList({
    super.key,
    required this.rows,
    required this.typeLabelBuilder,
    this.emptyMessage = 'No transactions in this period.',
  });

  final List<LedgerTimelineRowEntity> rows;
  final String Function(String ledgerType) typeLabelBuilder;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(child: Text(emptyMessage));
    }
    return ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return LedgerTimelineEntryCard(
          row: rows[index],
          typeLabel: typeLabelBuilder(rows[index].ledgerType),
        );
      },
    );
  }
}

class LedgerTimelineEntryCard extends StatelessWidget {
  const LedgerTimelineEntryCard({
    super.key,
    required this.row,
    required this.typeLabel,
  });

  final LedgerTimelineRowEntity row;
  final String typeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMoneyIn = row.direction.value == 'credit';
    final accent = isMoneyIn ? colorScheme.primary : colorScheme.tertiary;
    final amountPrefix = isMoneyIn ? '+' : '-';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 4,
              height: 72,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          typeLabel,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '$amountPrefix${FormattingHelpers.currencyPkr(row.amount)}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    FormattingHelpers.dateYmdHm(row.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[
                      Text(
                        'Balance: ${FormattingHelpers.currencyPkr(row.runningBalance)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Ref: ${row.transactionId}',
                        style: theme.textTheme.bodySmall,
                      ),
                      if ((row.paymentMethod ?? '').isNotEmpty)
                        Chip(
                          label: Text(row.paymentMethod!),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ..._statusBadges(context, row),
                    ],
                  ),
                  if ((row.note ?? '').trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      row.note!.trim(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _statusBadges(BuildContext context, LedgerTimelineRowEntity row) {
    final colorScheme = Theme.of(context).colorScheme;
    final badges = <Widget>[];
    if (row.isReversal) {
      badges.add(_badge('Reversed', colorScheme.errorContainer,
          colorScheme.onErrorContainer));
    }
    final type = row.ledgerType.toLowerCase();
    if (type.contains('payment') || type.contains('settlement')) {
      badges.add(_badge(
          'Settlement', colorScheme.primaryContainer, colorScheme.onPrimaryContainer));
    }
    if (type.contains('return') || type.contains('refund')) {
      badges.add(
          _badge('Refunded', colorScheme.tertiaryContainer, colorScheme.onTertiaryContainer));
    }
    return badges;
  }

  Widget _badge(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class LedgerDuesKpiCards extends StatelessWidget {
  const LedgerDuesKpiCards({
    super.key,
    required this.outstandingLabel,
    required this.outstandingAmount,
    required this.paymentsLabel,
    required this.paymentsAmount,
    required this.remainingLabel,
    required this.remainingAmount,
  });

  final String outstandingLabel;
  final double outstandingAmount;
  final String paymentsLabel;
  final double paymentsAmount;
  final String remainingLabel;
  final double remainingAmount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _SummaryCard(
            title: outstandingLabel,
            value: FormattingHelpers.currencyPkr(outstandingAmount),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            title: paymentsLabel,
            value: FormattingHelpers.currencyPkr(paymentsAmount),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            title: remainingLabel,
            value: FormattingHelpers.currencyPkr(remainingAmount),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    this.emphasized = false,
  });

  final String title;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      color: emphasized ? colorScheme.primaryContainer.withValues(alpha: 0.35) : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: emphasized ? colorScheme.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
