import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/core/widgets/responsive_table_layout.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_summary_entity.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/supplier_providers.dart';
import 'package:phone_shop_pos/modules/suppliers/presentation/providers/supplier_info_providers.dart';

class SupplierDetailScreen extends ConsumerWidget {
  const SupplierDetailScreen({super.key, required this.supplierId});

  final String supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supplierAsync = ref.watch(supplierRepositoryProvider);
    final historyAsync = ref.watch(supplierPurchaseHistoryProvider(supplierId));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Suppliers',
          onPressed: () => context.go('/suppliers'),
        ),
        title: const Text('Supplier Purchase History'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            supplierAsync.when(
              data: (repo) => FutureBuilder(
                future: repo.getSupplierById(supplierId),
                builder: (context, snapshot) {
                  final supplier = snapshot.data?.asSuccess?.value;
                  if (supplier == null) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    supplier.name,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  );
                },
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  child: historyAsync.when(
                    data: _buildTable,
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => AppErrorState(
                      message: 'Error loading history: $error',
                      onRetry: () => ref.invalidate(
                          supplierPurchaseHistoryProvider(supplierId)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTable(List<SupplierPurchaseHistoryRowEntity> rows) {
    if (rows.isEmpty) {
      return const AppEmptyState(
        message: 'No purchase history for this supplier.',
        icon: Icons.receipt_long_outlined,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = ResponsiveTableLayout.fromWidth(constraints.maxWidth);
        final showInvoice = layout.showCompactColumns == false;
        return AppDataTable(
          showCheckboxColumn: false,
          columnSpacing: layout.columnSpacing,
          dataRowMinHeight: layout.dataRowMinHeight,
          dataRowMaxHeight: layout.dataRowMaxHeight,
          columns: <DataColumn>[
            const DataColumn(label: Text('Brand')),
            const DataColumn(label: Text('Model')),
            const DataColumn(label: Text('IMEI')),
            const DataColumn(label: Text('Purchase Date')),
            const DataColumn(label: Text('Purchase Price'), numeric: true),
            const DataColumn(label: Text('Qty'), numeric: true),
            const DataColumn(label: Text('Current Status')),
            if (showInvoice) const DataColumn(label: Text('Invoice Number')),
          ],
          rows: rows.map((row) {
            return DataRow(
              cells: <DataCell>[
                DataCell(Text(row.brand ?? '-')),
                DataCell(Text(row.productName)),
                DataCell(Text(row.imei ?? '-')),
                DataCell(Text(
                  row.purchaseDate != null
                      ? FormattingHelpers.dateYmd(row.purchaseDate!)
                      : '-',
                )),
                DataCell(Text(
                  row.purchasePrice != null
                      ? FormattingHelpers.currencyPkr(row.purchasePrice!)
                      : '-',
                )),
                DataCell(Text('${row.quantity}')),
                DataCell(Text(row.currentStatus ?? '-')),
                if (showInvoice) DataCell(Text(row.invoiceNumber ?? '-')),
              ],
            );
          }).toList(growable: false),
        );
      },
    );
  }
}
