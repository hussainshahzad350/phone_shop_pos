import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/services/export/csv_export_service.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/brand_stock_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/brand_stock_card.dart';
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

  static const _exportService = StockReportExportService();
  static const _csvService = FileCsvExportService();

  int _columnsForWidth(double width) {
    if (width >= 1500) return 8;
    if (width >= 1200) return 6;
    if (width >= 800) return 4;
    if (width >= 520) return 3;
    return 2;
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Spacer(),
                _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : OutlinedButton.icon(
                        onPressed: _exportCsv,
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Export CSV'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: theme.textTheme.labelSmall,
                        ),
                      ),
              ],
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.brands.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _columnsForWidth(constraints.maxWidth),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: 188,
                  ),
                  itemBuilder: (_, index) => BrandStockCard(
                    brand: widget.brands[index],
                    onTap: () => widget.onBrandTap(widget.brands[index]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
