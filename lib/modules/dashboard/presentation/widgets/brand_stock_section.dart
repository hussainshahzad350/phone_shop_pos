import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/services/export/csv_export_service.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/theme/app_typography.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/brand_stock_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/brand_stock_card.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/dashboard_compact_dropdown.dart';
import 'package:phone_shop_pos/modules/dashboard/services/stock_report_export_service.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

class BrandStockSection extends ConsumerStatefulWidget {
  const BrandStockSection({
    super.key,
    required this.brands,
    required this.onBrandTap,
  });

  final List<BrandStockEntity> brands;
  final ValueChanged<BrandStockEntity> onBrandTap;

  @override
  ConsumerState<BrandStockSection> createState() => _BrandStockSectionState();
}

class _BrandStockSectionState extends ConsumerState<BrandStockSection> {
  bool _exporting = false;
  String _query = '';

  static const _exportService = StockReportExportService();
  static const _csvService = FileCsvExportService();

  List<BrandStockEntity> get _filteredBrands {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.brands;
    return widget.brands
        .where((b) => b.brandName.toLowerCase().contains(q))
        .toList(growable: false);
  }

  Future<void> _exportCsv() async {
    final folder = await getDirectoryPath();
    if (folder == null || !mounted) return;

    setState(() => _exporting = true);
    try {
      final service =
          await ref.read(dashboardServiceProvider.future);
      final brandMap = await service.getAllModelImeiStock();

      if (!mounted) return;

      if (brandMap.isEmpty) {
        AppNotifier.warning('No in-stock phones found to export.');
        return;
      }

      final rows = _exportService.buildRows(brandMap);
      final timestamp = FormattingHelpers.backupTimestamp(DateTime.now());
      final file = await _csvService.export(
        directoryPath: folder,
        fileName:
            '${StockReportExportService.fileBaseName}_$timestamp.csv',
        headers: StockReportExportService.headers,
        rows: rows,
      );

      if (!mounted) return;
      AppNotifier.success('Exported: ${file.path}');
    } catch (e) {
      if (!mounted) return;
      AppNotifier.error('Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.brands.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final brands = _filteredBrands;
    final view = ref.watch(brandStockViewProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'Brand Stock',
                      style: theme.textTheme.titleSmall,
                      children: <InlineSpan>[
                        TextSpan(
                          text: ' · ${widget.brands.length} brands',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Same shell as DashboardCompactDropdown so the search box,
                // view dropdown and export button are pixel-identical.
                Container(
                  width: 200,
                  height: 36,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    borderRadius: AppRadii.smRadius,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Icon(
                        Icons.search,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextField(
                          onChanged: (value) =>
                              setState(() => _query = value),
                          style: theme.textTheme.bodySmall,
                          // expands + stretched Row gives the field the full
                          // box height so textAlignVertical can truly centre.
                          expands: true,
                          maxLines: null,
                          minLines: null,
                          textAlignVertical: TextAlignVertical.center,
                          decoration: const InputDecoration(
                            hintText: 'Search brand…',
                            isCollapsed: true,
                            filled: false,
                            // Every border state must be none — otherwise the
                            // enabled/focused borders fall back to the app's
                            // input theme (a 16px pill) inside this shell.
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                DashboardCompactDropdown<BrandStockView>(
                  value: view,
                  items: BrandStockView.values,
                  labelOf: (v) =>
                      v == BrandStockView.table ? 'Table' : 'Cards',
                  leadingIcon: view == BrandStockView.table
                      ? Icons.table_rows_outlined
                      : Icons.grid_view_outlined,
                  onChanged: (selected) =>
                      ref.read(brandStockViewProvider.notifier).state =
                          selected,
                ),
                const SizedBox(width: AppSpacing.sm),
                _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : SizedBox(
                        height: 36,
                        child: OutlinedButton.icon(
                          onPressed: _exportCsv,
                          icon: const Icon(Icons.download, size: 16),
                          label: const Text('Export CSV'),
                          style: OutlinedButton.styleFrom(
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadii.smRadius,
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            textStyle: theme.textTheme.labelMedium,
                          ),
                        ),
                      ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (brands.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: Text(
                    'No brands match "${_query.trim()}"',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else if (view == BrandStockView.table)
              _BrandStockTable(
                brands: brands,
                onBrandTap: widget.onBrandTap,
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: brands.length,
                // Compact phone-silhouette cards: capped width instead of
                // stretching to fill wide columns.
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 140,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 172,
                ),
                itemBuilder: (_, index) => BrandStockCard(
                  brand: brands[index],
                  onTap: () => widget.onBrandTap(brands[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Compact table view of the brand stock: Brand / Models / Units / Stock
/// Worth / Low Stock. Rows open the same brand popup as the cards.
class _BrandStockTable extends StatelessWidget {
  const _BrandStockTable({
    required this.brands,
    required this.onBrandTap,
  });

  final List<BrandStockEntity> brands;
  final ValueChanged<BrandStockEntity> onBrandTap;

  static const double _maxHeight = 320;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.outline,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    );

    return Container(
      constraints: const BoxConstraints(maxHeight: _maxHeight),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: AppRadii.smRadius,
      ),
      child: ClipRRect(
        borderRadius: AppRadii.smRadius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              color: theme.colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                      flex: 12, child: Text('BRAND', style: headerStyle)),
                  Expanded(
                    flex: 8,
                    child: Text('MODELS',
                        textAlign: TextAlign.right, style: headerStyle),
                  ),
                  Expanded(
                    flex: 8,
                    child: Text('UNITS',
                        textAlign: TextAlign.right, style: headerStyle),
                  ),
                  Expanded(
                    flex: 10,
                    child: Text('STOCK WORTH',
                        textAlign: TextAlign.right, style: headerStyle),
                  ),
                  Expanded(
                    flex: 9,
                    child: Text('LOW STOCK',
                        textAlign: TextAlign.right, style: headerStyle),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: brands.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
                itemBuilder: (context, index) =>
                    _BrandStockTableRow(brand: brands[index], onTap: onBrandTap),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandStockTableRow extends StatelessWidget {
  const _BrandStockTableRow({
    required this.brand,
    required this.onTap,
  });

  final BrandStockEntity brand;
  final ValueChanged<BrandStockEntity> onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semantic;
    final valueStyle = theme.textTheme.bodySmall?.copyWith(
      fontFeatures: AppTypography.tabularFigures,
    );
    final mutedStyle = valueStyle?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return InkWell(
      onTap: () => onTap(brand),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 12,
              child: Text(
                brand.brandName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              flex: 8,
              child: Text(
                '${brand.modelCount}',
                textAlign: TextAlign.right,
                style: mutedStyle,
              ),
            ),
            Expanded(
              flex: 8,
              child: Text(
                '${brand.stockCount}',
                textAlign: TextAlign.right,
                style: valueStyle?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              flex: 10,
              child: Text(
                FormattingHelpers.currencyPkr(brand.stockWorth),
                textAlign: TextAlign.right,
                style: mutedStyle,
              ),
            ),
            Expanded(
              flex: 9,
              child: Text(
                brand.lowStockCount > 0 ? '${brand.lowStockCount}' : '—',
                textAlign: TextAlign.right,
                style: valueStyle?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: brand.lowStockCount > 0
                      ? semantic.warning
                      : theme.colorScheme.outlineVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
