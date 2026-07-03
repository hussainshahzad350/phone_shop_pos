import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/model_imei_stock_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/cart_state_provider.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

class ModelDetailWidget extends ConsumerStatefulWidget {
  const ModelDetailWidget({
    super.key,
    required this.modelStock,
  });

  final ModelImeiStockEntity modelStock;

  @override
  ConsumerState<ModelDetailWidget> createState() => _ModelDetailWidgetState();
}

class _ModelDetailWidgetState extends ConsumerState<ModelDetailWidget> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  widget.modelStock.modelName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  '${widget.modelStock.imeis.length} Phones',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const Divider(),
          if (widget.modelStock.imeis.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Text('No stock available'),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.modelStock.imeis.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, index) {
                return _ImeiItemWidget(
                  imei: widget.modelStock.imeis[index],
                  onSell: () => _sellImei(context, index),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _sellImei(BuildContext context, int index) async {
    final imei = widget.modelStock.imeis[index];

    final product = ProductEntity(
      id: widget.modelStock.modelId,
      name: widget.modelStock.modelName,
      brand: widget.modelStock.brandName,
      purchasePrice: imei.costPrice,
      salePrice: imei.salePrice,
      hasImei: true,
      isActive: true,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );

    final result = await ref
        .read(cartStateProvider.notifier)
        .addToCart(
          product: product,
          serializedStockId: imei.serializedStockId,
          imei: imei.imei,
          imei2: imei.imei2,
          serialNumber: imei.serialNumber,
          price: imei.salePrice,
        );

    if (!context.mounted) return;

    if (result.isSuccess) {
      // Capture the router before popping so we don't touch a defunct context,
      // then close the brand dialog and jump to the sales screen with the
      // freshly added item already in the (global) cart.
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.go('/sales');
      AppNotifier.success('Added to cart');
    } else {
      AppNotifier.error(result.asFailure!.error.message);
    }
  }
}

class _ImeiItemWidget extends StatelessWidget {
  const _ImeiItemWidget({
    required this.imei,
    required this.onSell,
  });

  final ImeiStockItemEntity imei;
  final VoidCallback onSell;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'IMEI: ${imei.imei}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (imei.imei2 != null && imei.imei2!.isNotEmpty)
                  Text(
                    'IMEI2: ${imei.imei2}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                if (imei.serialNumber != null && imei.serialNumber!.isNotEmpty)
                  Text(
                    'Serial: ${imei.serialNumber}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                Text(
                  'Price: ${FormattingHelpers.currencyPkr(imei.salePrice)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onSell,
            icon: const Icon(Icons.shopping_cart_outlined),
            label: const Text('SELL'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            ),
          ),
        ],
      ),
    );
  }
}