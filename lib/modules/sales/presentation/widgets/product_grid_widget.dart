import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/sales_query_providers.dart';

/// Max product cards shown in the quick stock bar. Beyond this, the user is
/// pointed to the Inventory screen via the trailing "View all" button.
const int _kMaxStockBarItems = 12;

class ProductGridWidget extends ConsumerStatefulWidget {
  const ProductGridWidget({
    super.key,
    required this.onAddProduct,
    required this.onRetry,
    required this.onViewAllInInventory,
  });

  final ValueChanged<ProductEntity> onAddProduct;
  final VoidCallback onRetry;
  final VoidCallback onViewAllInInventory;

  @override
  ConsumerState<ProductGridWidget> createState() => _ProductGridWidgetState();
}

class _ProductGridWidgetState extends ConsumerState<ProductGridWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productSearchResultsProvider);

    return SizedBox(
      // ~25% shorter than before so the cart below gets more room.
      height: 118,
      child: Card(
        child: productsAsync.when(
          // Keep the current cards visible while a new search loads instead of
          // flashing to a spinner on every keystroke / scan.
          skipLoadingOnReload: true,
          data: (products) {
            final shown = products.length > _kMaxStockBarItems
                ? products.sublist(0, _kMaxStockBarItems)
                : products;
            return LayoutBuilder(
              builder: (context, constraints) {
                final mainAxisExtent =
                    constraints.maxWidth >= 1400 ? 168.0 : 180.0;
                final scrollStep = constraints.maxWidth * 0.75;
                return Stack(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 34),
                      child: GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(6),
                        scrollDirection: Axis.horizontal,
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 1,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                          mainAxisExtent: mainAxisExtent,
                        ),
                        // +1 for the trailing "View all in Inventory" button.
                        itemCount: shown.length + 1,
                        itemBuilder: (context, index) {
                          if (index == shown.length) {
                            return _ViewAllInInventoryButton(
                              onPressed: widget.onViewAllInInventory,
                            );
                          }
                          return _ProductCardButton(
                            product: shown[index],
                            onPressed: () =>
                                widget.onAddProduct(shown[index]),
                          );
                        },
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _GridNavArrowButton(
                        icon: Icons.chevron_left,
                        onPressed: () => _scrollProductGrid(-scrollStep),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _GridNavArrowButton(
                        icon: Icons.chevron_right,
                        onPressed: () => _scrollProductGrid(scrollStep),
                      ),
                    ),
                  ],
                );
              },
            );
          },
          error: (_, __) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text('Failed to load products'),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }

  Future<void> _scrollProductGrid(double delta) async {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    await _scrollController.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }
}

class _ProductCardButton extends StatelessWidget {
  const _ProductCardButton({
    required this.product,
    required this.onPressed,
  });

  final ProductEntity product;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        alignment: Alignment.centerLeft,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            FormattingHelpers.currencyPkr(product.salePrice),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            product.hasImei ? 'Serialized • IMEI' : 'Qty product',
            style: const TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _ViewAllInInventoryButton extends StatelessWidget {
  const _ViewAllInInventoryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.inventory_2_outlined,
              size: 22, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          Text(
            'View all\nin Inventory',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _GridNavArrowButton extends StatelessWidget {
  const _GridNavArrowButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
      elevation: 1,
      shape: const CircleBorder(),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        icon: Icon(icon),
        onPressed: onPressed,
        tooltip:
            icon == Icons.chevron_left ? 'Previous products' : 'Next products',
      ),
    );
  }
}
