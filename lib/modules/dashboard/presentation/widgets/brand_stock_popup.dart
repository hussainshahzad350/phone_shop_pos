import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/routing/app_router.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/stock_row_entity.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/cart_state_provider.dart';

class BrandStockPopup extends ConsumerStatefulWidget {
  const BrandStockPopup({
    super.key,
    required this.brandName,
  });

  final String brandName;

  @override
  ConsumerState<BrandStockPopup> createState() => _BrandStockPopupState();
}

class _BrandStockPopupState extends ConsumerState<BrandStockPopup> {
  String? _expandedModelId;

  Future<void> _sellPhone(
    ProductEntity product,
    StockRowEntity row,
  ) async {
    final result = await ref.read(cartStateProvider.notifier).addToCart(
          product: product,
          quantity: 1,
          price: row.sellingPrice ?? product.salePrice,
          serializedStockId: row.serializedStockId,
          imei: row.imei1,
          imei2: row.imei2,
          serialNumber: row.serialNumber,
        );

    if (!mounted) {
      return;
    }

    result.fold(
      onSuccess: (_) {
        Navigator.of(context).pop();
        ref.read(appRouterProvider).go('/sales');
      },
      onFailure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add to cart: $error')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final modelsAsync = ref.watch(brandPhoneModelsProvider(widget.brandName));
    final rowsAsync = ref.watch(brandPhoneStockRowsProvider(widget.brandName));

    return AlertDialog(
      title: Text(widget.brandName),
      content: SizedBox(
        width: 500,
        height: 500,
        child: modelsAsync.when(
          data: (models) => rowsAsync.when(
            data: (rows) => _buildContent(models, rows),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(
              child: Text('Failed to load stock details.'),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
            child: Text('Failed to load models.'),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildContent(List<ProductEntity> models, List<StockRowEntity> rows) {
    final rowsByModel = <String, List<StockRowEntity>>{};
    for (final row in rows) {
      rowsByModel
          .putIfAbsent(row.productModelId, () => <StockRowEntity>[])
          .add(row);
    }

    final modelsWithStock = models
        .where((model) => (rowsByModel[model.id]?.length ?? 0) > 0)
        .toList(growable: false);

    if (modelsWithStock.isEmpty) {
      return const Center(child: Text('No phone models in stock.'));
    }

    return ListView.builder(
      itemCount: modelsWithStock.length,
      itemBuilder: (context, index) {
        final model = modelsWithStock[index];
        final modelRows = rowsByModel[model.id] ?? const <StockRowEntity>[];
        final isExpanded = _expandedModelId == model.id;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Column(
            children: <Widget>[
              ListTile(
                title: Text(model.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${modelRows.length} phone${modelRows.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                    ),
                  ],
                ),
                onTap: () => setState(() {
                  _expandedModelId = isExpanded ? null : model.id;
                }),
              ),
              if (isExpanded && modelRows.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: 16,
                  ),
                  child: Column(
                    children: modelRows.map((row) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          row.imei1 ?? row.serialNumber ?? 'Unknown IMEI',
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                        subtitle: Text(
                          'Price: ${FormattingHelpers.currencyPkr(row.sellingPrice ?? model.salePrice)}',
                        ),
                        trailing: FilledButton(
                          onPressed: () => _sellPhone(model, row),
                          child: const Text('SELL'),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
