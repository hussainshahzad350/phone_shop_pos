import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/sales_query_providers.dart';

class ProductGridWidget extends ConsumerStatefulWidget {
  const ProductGridWidget({
    super.key,
    required this.onAddProduct,
    required this.onRetry,
  });

  final ValueChanged<ProductEntity> onAddProduct;
  final VoidCallback onRetry;

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
      height: 156,
      child: Card(
        child: productsAsync.when(
          data: (products) => LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = 1;
              final mainAxisExtent =
                  constraints.maxWidth >= 1400 ? 220.0 : 240.0;
              final scrollStep = constraints.maxWidth * 0.75;
              return Stack(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 34),
                    child: GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(8),
                      scrollDirection: Axis.horizontal,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        mainAxisExtent: mainAxisExtent,
                      ),
                      itemCount: products.length,
                      itemBuilder: (context, index) {
                        final product = products[index];
                        return OutlinedButton(
                          onPressed: () => widget.onAddProduct(product),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.all(10),
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
                              ),
                              const SizedBox(height: 4),
                              Text(
                                FormattingHelpers.currencyPkr(
                                  product.salePrice,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                product.hasImei
                                    ? 'Serialized • IMEI required'
                                    : 'Quantity product',
                              ),
                            ],
                          ),
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
          ),
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
