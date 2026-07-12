import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/utils/imei_bulk_parser.dart';
import 'package:phone_shop_pos/core/validation/field_validators.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/core/widgets/responsive_table_layout.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/bulk_imei_import_summary.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/imei_management_entry.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/imei_management_providers.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/widgets/supplier_selector_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';

// NOTE: this screen is pushed as a modal (Navigator.push), outside the
// go_router shell that drives ScannerController's mode-routing. IMEI input
// here (typed or scanner-typed, since a barcode scanner just emits keystrokes
// into whatever field has focus) is validated via the same FieldValidators
// used everywhere else, but does not get ScannerController's per-session
// duplicate-scan dedup that Sales/Purchases/Inventory get automatically.
// Deliberate scope boundary — see rollout Part 3/Feature 19.
class ImeiManagementScreen extends ConsumerStatefulWidget {
  const ImeiManagementScreen({super.key, required this.product});

  final ProductEntity product;

  static Future<void> open(BuildContext context, ProductEntity product) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ImeiManagementScreen(product: product),
      ),
    );
  }

  @override
  ConsumerState<ImeiManagementScreen> createState() =>
      _ImeiManagementScreenState();
}

class _ImeiManagementScreenState extends ConsumerState<ImeiManagementScreen> {
  final TextEditingController _filterController = TextEditingController();
  String _filterQuery = '';

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  void _onFilterChanged(String value) {
    setState(() => _filterQuery = value.trim().toLowerCase());
  }

  Future<void> _openAddImeiSheet() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddImeiSheet(productModelId: widget.product.id),
    );
    if (added == true) {
      ref.read(reportWorkflowCoordinatorProvider).refreshInventoryAfterChange();
    }
  }

  Future<void> _openBulkAddImeiSheet() async {
    final summary = await showModalBottomSheet<BulkImeiImportSummary>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BulkAddImeiSheet(productModelId: widget.product.id),
    );
    if (summary == null || !mounted) {
      return;
    }
    ref.read(reportWorkflowCoordinatorProvider).refreshInventoryAfterChange();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bulk Import Summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _SummaryRow(label: 'Total Scanned', value: '${summary.totalScanned}'),
            _SummaryRow(label: 'Successfully Added', value: '${summary.added}'),
            _SummaryRow(
                label: 'Duplicates', value: '${summary.duplicates.length}'),
            _SummaryRow(label: 'Failed', value: '${summary.failed.length}'),
            if (summary.failed.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              const Text('Failed:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...summary.failed.map(
                (f) => Text(
                  '${f.imei}: ${f.reason}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteImei(ImeiManagementEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete IMEI?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('IMEI: ${entry.imei1}'),
            if (entry.imei2 != null) Text('IMEI 2: ${entry.imei2}'),
            const SizedBox(height: 8),
            const Text(
              'This is permanent. The IMEI will be removed from inventory and '
              'can be re-entered into the correct model.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repo = await ref.read(imeiManagementRepositoryProvider.future);
    if (!mounted) return;
    final result = await repo.deleteImei(entry.stockId);
    if (!mounted) return;

    result.fold(
      onSuccess: (_) {
        ref.read(reportWorkflowCoordinatorProvider).refreshInventoryAfterChange();
        AppNotifier.success('IMEI deleted successfully.');
      },
      onFailure: (e) => AppNotifier.error(e.message),
    );
  }

  Future<void> _editPurchaseInfo(ImeiManagementEntry entry) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditPurchaseInfoDialog(entry: entry),
    );
    if (saved == true) {
      ref.read(reportWorkflowCoordinatorProvider).refreshInventoryAfterChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    final imeiListAsync =
        ref.watch(imeiListForModelProvider(widget.product.id));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(widget.product.name),
            if (widget.product.brand != null)
              Text(
                widget.product.brand!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
        actions: <Widget>[
          OutlinedButton.icon(
            onPressed: _openBulkAddImeiSheet,
            icon: const Icon(Icons.playlist_add),
            label: const Text('Bulk Add'),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton.icon(
            onPressed: _openAddImeiSheet,
            icon: const Icon(Icons.add),
            label: const Text('Add IMEI'),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: <Widget>[
            // ── Search / filter bar ───────────────────────────────────────
            TextField(
              controller: _filterController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Scan or search IMEI…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _filterQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear',
                        onPressed: () {
                          _filterController.clear();
                          _onFilterChanged('');
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: _onFilterChanged,
            ),
            const SizedBox(height: AppSpacing.sm),
            // ── IMEI list ─────────────────────────────────────────────────
            Expanded(
              child: imeiListAsync.when(
                data: (entries) {
                  final filtered = _filterQuery.isEmpty
                      ? entries
                      : entries
                          .where(
                            (e) =>
                                e.imei1
                                    .toLowerCase()
                                    .contains(_filterQuery) ||
                                (e.imei2
                                        ?.toLowerCase()
                                        .contains(_filterQuery) ??
                                    false),
                          )
                          .toList(growable: false);

                  if (entries.isEmpty) {
                    return _EmptyState(onAdd: _openAddImeiSheet);
                  }
                  if (filtered.isEmpty) {
                    return Center(
                      child: Text(
                        'No IMEI matches "${_filterController.text.trim()}"',
                        style: theme.textTheme.bodyMedium,
                      ),
                    );
                  }

                  return _ImeiTable(
                    entries: filtered,
                    onEdit: _editPurchaseInfo,
                    onDelete: _deleteImei,
                  );
                },
                error: (e, _) => AppErrorState(
                  message: 'Failed to load IMEIs: $e',
                  onRetry: () => ref
                      .invalidate(imeiListForModelProvider(widget.product.id)),
                ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── IMEI table ──────────────────────────────────────────────────────────────

class _ImeiTable extends StatelessWidget {
  const _ImeiTable({
    required this.entries,
    required this.onEdit,
    required this.onDelete,
  });

  final List<ImeiManagementEntry> entries;
  final ValueChanged<ImeiManagementEntry> onEdit;
  final ValueChanged<ImeiManagementEntry> onDelete;

  static const List<_ImeiColumn> _columns = <_ImeiColumn>[
    _ImeiColumn.imei1,
    _ImeiColumn.imei2,
    _ImeiColumn.status,
    _ImeiColumn.purchaseDate,
    _ImeiColumn.cost,
    _ImeiColumn.supplier,
    _ImeiColumn.actions,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = ResponsiveTableLayout.fromWidth(constraints.maxWidth);
        return AppDataTable(
          columnSpacing: layout.columnSpacing,
          dataRowMinHeight: layout.dataRowMinHeight,
          dataRowMaxHeight: layout.dataRowMaxHeight,
          columns:
              _columns.map(_buildDataColumn).toList(growable: false),
          rows: entries
              .map((e) => _buildDataRow(context, e))
              .toList(growable: false),
        );
      },
    );
  }

  DataColumn _buildDataColumn(_ImeiColumn column) {
    return DataColumn(
      numeric: column == _ImeiColumn.cost,
      label: Text(_columnLabel(column)),
    );
  }

  DataRow _buildDataRow(BuildContext context, ImeiManagementEntry e) {
    final theme = Theme.of(context);
    final semantic = theme.semantic;
    final effectiveDate = e.purchaseDate ?? e.createdAt;
    final statusColor = _statusColor(e.stockStatus, semantic);
    return DataRow(
      cells: <DataCell>[
        DataCell(
          SelectableText(
            e.imei1,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        DataCell(
          e.imei2 != null
              ? SelectableText(
                  e.imei2!,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 12),
                )
              : Text('-',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        ),
        DataCell(
          AppStatusBadge(
            label: _statusLabel(e.stockStatus),
            color: statusColor,
          ),
        ),
        DataCell(Text(FormattingHelpers.dateYmd(effectiveDate))),
        DataCell(Text(FormattingHelpers.currencyPkr(e.costPrice))),
        DataCell(Text(e.supplierName ?? '-')),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton.filledTonal(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit purchase info',
                visualDensity: VisualDensity.compact,
                onPressed: () => onEdit(e),
              ),
              if (e.isDeletable) ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
                IconButton.filledTonal(
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: theme.colorScheme.error),
                  tooltip: 'Delete IMEI',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onDelete(e),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _columnLabel(_ImeiColumn column) {
    switch (column) {
      case _ImeiColumn.imei1:
        return 'IMEI 1';
      case _ImeiColumn.imei2:
        return 'IMEI 2';
      case _ImeiColumn.status:
        return 'Status';
      case _ImeiColumn.purchaseDate:
        return 'Purchase Date';
      case _ImeiColumn.cost:
        return 'Cost';
      case _ImeiColumn.supplier:
        return 'Supplier';
      case _ImeiColumn.actions:
        return 'Actions';
    }
  }

  Color _statusColor(SerializedStockStatus status, AppSemanticColors semantic) {
    switch (status) {
      case SerializedStockStatus.inStock:
        return semantic.success;
      case SerializedStockStatus.sold:
        return semantic.info;
      case SerializedStockStatus.reserved:
      case SerializedStockStatus.withDealer:
      case SerializedStockStatus.returned:
        return semantic.warning;
      case SerializedStockStatus.damaged:
        return semantic.danger;
    }
  }

  String _statusLabel(SerializedStockStatus status) {
    switch (status) {
      case SerializedStockStatus.inStock:
        return 'In Stock';
      case SerializedStockStatus.sold:
        return 'Sold';
      case SerializedStockStatus.reserved:
        return 'Reserved';
      case SerializedStockStatus.withDealer:
        return 'With Dealer';
      case SerializedStockStatus.returned:
        return 'Returned';
      case SerializedStockStatus.damaged:
        return 'Damaged';
    }
  }
}

enum _ImeiColumn {
  imei1,
  imei2,
  status,
  purchaseDate,
  cost,
  supplier,
  actions,
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      message: 'No IMEIs found for this model.',
      icon: Icons.phonelink_off_outlined,
      action: FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Add First IMEI'),
      ),
    );
  }
}

// ── Add IMEI bottom sheet ─────────────────────────────────────────────────────

class _AddImeiSheet extends ConsumerStatefulWidget {
  const _AddImeiSheet({required this.productModelId});
  final String productModelId;

  @override
  ConsumerState<_AddImeiSheet> createState() => _AddImeiSheetState();
}

class _AddImeiSheetState extends ConsumerState<_AddImeiSheet> {
  final _formKey = GlobalKey<FormState>();

  final _imei1Controller = TextEditingController();
  final _imei2Controller = TextEditingController();
  final _costController = TextEditingController(text: '0');
  final _imei1Focus = FocusNode();
  final _imei2Focus = FocusNode();
  final _costFocus = FocusNode();

  DateTime _purchaseDate = DateTime.now();
  String? _supplierId;
  bool _isSaving = false;
  bool _addedAtLeastOne = false;

  @override
  void dispose() {
    _imei1Controller.dispose();
    _imei2Controller.dispose();
    _costController.dispose();
    _imei1Focus.dispose();
    _imei2Focus.dispose();
    _costFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _purchaseDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final repo = await ref.read(imeiManagementRepositoryProvider.future);
    if (!mounted) return;

    final cost =
        FormattingHelpers.parseLocaleDecimal(_costController.text);

    final result = await repo.addImei(
      productModelId: widget.productModelId,
      imei1: _imei1Controller.text.trim(),
      imei2: _imei2Controller.text.trim().isEmpty
          ? null
          : _imei2Controller.text.trim(),
      purchaseDate: _purchaseDate,
      costPrice: cost,
      supplierId: _supplierId,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    result.fold(
      onSuccess: (_) {
        _addedAtLeastOne = true;
        AppNotifier.success('IMEI ${_imei1Controller.text.trim()} added.');
        // Reset IMEI fields only — keep cost/supplier/date for continuous entry
        _imei1Controller.clear();
        _imei2Controller.clear();
        _imei1Focus.requestFocus();
      },
      onFailure: (e) => AppNotifier.error(e.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Add IMEI',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                  onPressed: () =>
                      Navigator.pop(context, _addedAtLeastOne),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // ── IMEI 1 ──────────────────────────────────────────────────
            TextFormField(
              controller: _imei1Controller,
              focusNode: _imei1Focus,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'IMEI 1 *',
                hintText: 'Scan or type 14–15 digit IMEI',
                prefixIcon: Icon(Icons.qr_code_scanner),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onFieldSubmitted: (_) => _imei2Focus.requestFocus(),
              validator: (v) => FieldValidators.imei(v, label: 'IMEI 1'),
            ),
            const SizedBox(height: AppSpacing.xs),
            // ── IMEI 2 ──────────────────────────────────────────────────
            TextFormField(
              controller: _imei2Controller,
              focusNode: _imei2Focus,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'IMEI 2 (optional)',
                prefixIcon: Icon(Icons.qr_code_scanner),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onFieldSubmitted: (_) => _costFocus.requestFocus(),
              validator: FieldValidators.optionalImei,
            ),
            const SizedBox(height: AppSpacing.xs),
            // ── Date + Cost row ──────────────────────────────────────────
            Row(
              children: <Widget>[
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Purchase Date',
                        prefixIcon: Icon(Icons.calendar_today, size: 18),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(
                        FormattingHelpers.dateYmd(_purchaseDate),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: TextFormField(
                    controller: _costController,
                    focusNode: _costFocus,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Purchase Price',
                      prefixText: 'PKR ',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[\d.,]')),
                    ],
                    onFieldSubmitted: (_) => _submit(),
                    validator: FieldValidators.nonNegativePrice,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // ── Supplier ─────────────────────────────────────────────────
            SupplierSelectorWidget(
              standalone: true,
              selectedSupplierId: _supplierId,
              onChanged: (v) => setState(() => _supplierId = v),
            ),
            const SizedBox(height: AppSpacing.md),
            // ── Submit ────────────────────────────────────────────────────
            FilledButton.icon(
              onPressed: _isSaving ? null : _submit,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              label: const Text('Add IMEI'),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Tip: After adding, the form stays open so you can scan the next IMEI.',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bulk Add IMEI sheet ────────────────────────────────────────────────────────

class _BulkAddImeiSheet extends ConsumerStatefulWidget {
  const _BulkAddImeiSheet({required this.productModelId});
  final String productModelId;

  @override
  ConsumerState<_BulkAddImeiSheet> createState() => _BulkAddImeiSheetState();
}

class _BulkAddImeiSheetState extends ConsumerState<_BulkAddImeiSheet> {
  final _bulkController = TextEditingController();
  final _costController = TextEditingController(text: '0');
  final ValueNotifier<List<ParsedImeiLine>> _previewNotifier =
      ValueNotifier<List<ParsedImeiLine>>(const []);

  DateTime _purchaseDate = DateTime.now();
  String? _supplierId;
  bool _isSaving = false;

  @override
  void dispose() {
    _bulkController.dispose();
    _costController.dispose();
    _previewNotifier.dispose();
    super.dispose();
  }

  void _parseInput(String text) {
    _previewNotifier.value = ImeiBulkParser.parse(text);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _purchaseDate = picked);
    }
  }

  Future<void> _submit() async {
    final entries = _previewNotifier.value;
    if (entries.isEmpty) {
      return;
    }
    setState(() => _isSaving = true);

    final repo = await ref.read(imeiManagementRepositoryProvider.future);
    if (!mounted) return;

    final cost = FormattingHelpers.parseLocaleDecimal(_costController.text);
    final result = await repo.addImeisBulk(
      productModelId: widget.productModelId,
      entries: entries,
      purchaseDate: _purchaseDate,
      costPrice: cost,
      supplierId: _supplierId,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    result.fold(
      onSuccess: (summary) => Navigator.pop(context, summary),
      onFailure: (e) => AppNotifier.error(e.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Bulk Add IMEIs',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Scan or paste one IMEI per line. Formats accepted:\n'
            '• IMEI1\n'
            '• IMEI1,IMEI2\n'
            '• IMEI1,IMEI2,SerialNumber',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _bulkController,
            autofocus: true,
            maxLines: 8,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText:
                  '356789101234561\n356789101234562\n356789101234563\n...',
              labelText: 'Scan or paste IMEIs here',
            ),
            onChanged: _parseInput,
          ),
          const SizedBox(height: AppSpacing.sm),
          ValueListenableBuilder<List<ParsedImeiLine>>(
            valueListenable: _previewNotifier,
            builder: (context, preview, _) {
              if (preview.isEmpty) {
                return const SizedBox.shrink();
              }
              return Text(
                'Preview: ${preview.length} device(s) parsed',
                style: const TextStyle(fontWeight: FontWeight.bold),
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Purchase Date',
                      prefixIcon: Icon(Icons.calendar_today, size: 18),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: Text(
                      FormattingHelpers.dateYmd(_purchaseDate),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: TextField(
                  controller: _costController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Cost Price (all devices)',
                    prefixText: 'PKR ',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SupplierSelectorWidget(
            standalone: true,
            selectedSupplierId: _supplierId,
            onChanged: (v) => setState(() => _supplierId = v),
          ),
          const SizedBox(height: AppSpacing.md),
          ValueListenableBuilder<List<ParsedImeiLine>>(
            valueListenable: _previewNotifier,
            builder: (context, preview, _) {
              return FilledButton.icon(
                onPressed: _isSaving || preview.isEmpty ? null : _submit,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.playlist_add_check),
                label: Text('Import ${preview.length} Device(s)'),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ── Edit purchase info dialog ─────────────────────────────────────────────────

class _EditPurchaseInfoDialog extends ConsumerStatefulWidget {
  const _EditPurchaseInfoDialog({
    required this.entry,
  });

  final ImeiManagementEntry entry;

  @override
  ConsumerState<_EditPurchaseInfoDialog> createState() =>
      _EditPurchaseInfoDialogState();
}

class _EditPurchaseInfoDialogState
    extends ConsumerState<_EditPurchaseInfoDialog> {
  late TextEditingController _costController;
  late DateTime _purchaseDate;
  String? _supplierId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final effectiveDate =
        widget.entry.purchaseDate ?? widget.entry.createdAt;
    _purchaseDate = effectiveDate;
    _supplierId = widget.entry.supplierId;
    _costController = TextEditingController(
      text: FormattingHelpers.decimal(widget.entry.costPrice),
    );
  }

  @override
  void dispose() {
    _costController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _purchaseDate = picked);
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final cost =
        FormattingHelpers.parseLocaleDecimal(_costController.text);

    final repo = await ref.read(imeiManagementRepositoryProvider.future);
    if (!mounted) return;

    final result = await repo.updatePurchaseInfo(
      stockId: widget.entry.stockId,
      purchaseDate: _purchaseDate,
      costPrice: cost,
      supplierId: _supplierId,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    result.fold(
      onSuccess: (_) => Navigator.pop(context, true),
      onFailure: (e) {
        AppNotifier.error(e.message);
        Navigator.pop(context, false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Text('Edit Purchase Info'),
          Text(
            widget.entry.imei1,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                  fontFamily: 'monospace',
                ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Purchase Date',
                  prefixIcon: Icon(Icons.calendar_today, size: 18),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                child: Text(FormattingHelpers.dateYmd(_purchaseDate)),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _costController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Purchase Price',
                prefixText: 'PKR ',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SupplierSelectorWidget(
              standalone: true,
              selectedSupplierId: _supplierId,
              onChanged: (v) => setState(() => _supplierId = v),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed:
              _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
