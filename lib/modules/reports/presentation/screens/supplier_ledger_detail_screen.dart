import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/ledger_timeline_row_entity.dart';
import 'package:phone_shop_pos/modules/ledger/domain/entities/party_summary_card_entity.dart';
import 'package:phone_shop_pos/modules/ledger/presentation/ledger_timeline_labels.dart';
import 'package:phone_shop_pos/modules/ledger/presentation/widgets/ledger_widgets.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/screens/ledger_detail_scope.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/pay_supplier_credit_dialog.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_summary_card_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/widgets/report_table_section_widget.dart';

class SupplierLedgerDetailScreen extends ConsumerStatefulWidget {
  const SupplierLedgerDetailScreen({
    super.key,
    required this.supplierId,
    required this.initialSummary,
  });

  final String supplierId;
  final PartySummaryCardEntity initialSummary;

  static Future<bool?> open(
    BuildContext context, {
    required String supplierId,
    required PartySummaryCardEntity summary,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (context) => SupplierLedgerDetailScreen(
          supplierId: supplierId,
          initialSummary: summary,
        ),
      ),
    );
  }

  @override
  ConsumerState<SupplierLedgerDetailScreen> createState() =>
      _SupplierLedgerDetailScreenState();
}

class _SupplierLedgerDetailScreenState
    extends ConsumerState<SupplierLedgerDetailScreen> {
  String? _categoryFilter = 'all';
  bool _ledgerChanged = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      bindSupplierLedgerDetailScope(ref, widget.supplierId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _requestClose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      clearSupplierLedgerDetailScope(ref);
      Navigator.of(context).pop(_ledgerChanged);
    });
  }

  Future<void> _payCredit(PartySummaryCardEntity summary) async {
    final maxPayable =
        summary.netBalance > 0 ? summary.netBalance : summary.outstanding;
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => PaySupplierCreditDialog(
        supplierId: widget.supplierId,
        maxAmount: maxPayable > 0 ? maxPayable : null,
      ),
    );
    if (changed == true && mounted) {
      setState(() => _ledgerChanged = true);
      refreshSupplierLedgerReports(ref);
    }
  }

  List<LedgerTimelineRowEntity> _filterRows(List<LedgerTimelineRowEntity> rows) {
    final search = _searchController.text;
    return newestFirstTimeline(
      rows
          .where(
            (row) =>
                supplierLedgerRowMatchesCategory(
                    row.ledgerType, _categoryFilter) &&
                ledgerRowMatchesSearch(row, search),
          )
          .toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(supplierLedgerSummaryProvider);
    final timelineAsync = ref.watch(supplierLedgerTimelineProvider);
    final outstandingOnly =
        ref.watch(supplierLedgerTimelineOutstandingOnlyProvider);
    final startDate = ref.watch(supplierLedgerTimelineStartDateProvider);
    final endDate = ref.watch(supplierLedgerTimelineEndDateProvider);

    var summary = widget.initialSummary;
    final summaryRows = summaryAsync.valueOrNull;
    if (summaryRows != null) {
      for (final row in summaryRows) {
        if (row.partyId == widget.supplierId) {
          summary = row;
          break;
        }
      }
    }
    final displayName = normalizeSupplierLedgerName(summary.partyName);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          clearSupplierLedgerDetailScope(ref);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
            onPressed: _requestClose,
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                displayName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                supplierLedgerBalanceSubtitle(summary),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
          actions: <Widget>[
            FilledButton.tonalIcon(
              onPressed: summary.netBalance > 0.009
                  ? () => _payCredit(summary)
                  : null,
              icon: const Icon(Icons.north_east, size: 18),
              label: const Text('Pay Credit'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: ReportSummaryCardWidget(
                      label: 'Outstanding payable',
                      value: FormattingHelpers.currencyPkr(summary.outstanding),
                      color: summary.outstanding > 0
                          ? Theme.of(context).semantic.warning
                          : Theme.of(context).semantic.success,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ReportSummaryCardWidget(
                      label: 'Total purchases',
                      value: FormattingHelpers.currencyPkr(summary.totalPayable),
                      color: Theme.of(context).semantic.info,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ReportSummaryCardWidget(
                      label: 'Total paid',
                      value: FormattingHelpers.currencyPkr(summary.totalReceivable),
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ReportTableSection(
                  title: 'Account Timeline',
                  subtitle: 'Newest transactions first',
                  filterBar: _SupplierLedgerFilters(
                    categoryFilter: _categoryFilter,
                    outstandingOnly: outstandingOnly,
                    startDate: startDate,
                    endDate: endDate,
                    searchController: _searchController,
                    onCategoryChanged: (value) =>
                        setState(() => _categoryFilter = value),
                    onOutstandingChanged: (value) => ref
                        .read(
                          supplierLedgerTimelineOutstandingOnlyProvider.notifier,
                        )
                        .state = value,
                    onSearchChanged: () => setState(() {}),
                    onStartDatePick: (date) => ref
                        .read(supplierLedgerTimelineStartDateProvider.notifier)
                        .state = date,
                    onEndDatePick: (date) => ref
                        .read(supplierLedgerTimelineEndDateProvider.notifier)
                        .state = date,
                    onClearDates: () {
                      ref
                          .read(supplierLedgerTimelineStartDateProvider.notifier)
                          .state = null;
                      ref
                          .read(supplierLedgerTimelineEndDateProvider.notifier)
                          .state = null;
                    },
                  ),
                  child: timelineAsync.when(
                    data: (rows) => LedgerTimelineTable(
                      rows: _filterRows(rows),
                      typeLabelBuilder: humanizeSupplierLedgerType,
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, __) => Center(
                      child: Text('Failed to load timeline: $error'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupplierLedgerFilters extends StatelessWidget {
  const _SupplierLedgerFilters({
    required this.categoryFilter,
    required this.outstandingOnly,
    required this.startDate,
    required this.endDate,
    required this.searchController,
    required this.onCategoryChanged,
    required this.onOutstandingChanged,
    required this.onSearchChanged,
    required this.onStartDatePick,
    required this.onEndDatePick,
    required this.onClearDates,
  });

  final String? categoryFilter;
  final bool outstandingOnly;
  final DateTime? startDate;
  final DateTime? endDate;
  final TextEditingController searchController;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<bool> onOutstandingChanged;
  final VoidCallback onSearchChanged;
  final ValueChanged<DateTime?> onStartDatePick;
  final ValueChanged<DateTime?> onEndDatePick;
  final VoidCallback onClearDates;

  static const List<(String?, String)> _categories = <(String?, String)>[
    ('all', 'All'),
    ('purchases', 'Purchases'),
    ('payments', 'Payments'),
    ('returns', 'Returns'),
    ('advances', 'Advances'),
    ('reversals', 'Reversals'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _categories.map((entry) {
            return FilterChip(
              label: Text(entry.$2),
              selected: categoryFilter == entry.$1,
              onSelected: (_) => onCategoryChanged(entry.$1),
            );
          }).toList(growable: false),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 220,
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Search reference',
                  prefixIcon: Icon(Icons.search, size: 18),
                ),
                onChanged: (_) => onSearchChanged(),
              ),
            ),
            FilterChip(
              label: const Text('Outstanding only'),
              selected: outstandingOnly,
              onSelected: onOutstandingChanged,
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDate: startDate ?? DateTime.now(),
                );
                onStartDatePick(picked);
              },
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(
                startDate == null
                    ? 'Start'
                    : FormattingHelpers.dateYmd(startDate!),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                  initialDate: endDate ?? DateTime.now(),
                );
                onEndDatePick(picked);
              },
              icon: const Icon(Icons.event, size: 18),
              label: Text(
                endDate == null ? 'End' : FormattingHelpers.dateYmd(endDate!),
              ),
            ),
            OutlinedButton(
              onPressed: startDate == null && endDate == null ? null : onClearDates,
              child: const Text('Clear dates'),
            ),
          ],
        ),
      ],
    );
  }
}
