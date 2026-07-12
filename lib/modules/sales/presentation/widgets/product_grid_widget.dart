import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/sales_query_providers.dart';
import 'package:phone_shop_pos/core/theme/app_breakpoints.dart';
import 'package:phone_shop_pos/core/theme/app_motion.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

/// Max product cards shown in the quick stock bar. Beyond this, the user is
/// pointed to the Inventory screen via the trailing "View all" button.
const int _kMaxStockBarItems = 12;

class ProductGridWidget extends ConsumerStatefulWidget {
  const ProductGridWidget({
    super.key,
    required this.onAddProduct,
    required this.onModifyProduct,
    required this.onRetry,
    required this.onViewAllInInventory,
  });

  final ValueChanged<ProductEntity> onAddProduct;
  final ValueChanged<ProductEntity> onModifyProduct;
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
    final stockInfoAsync = ref.watch(productStockInfoProvider);
    final stockInfo = stockInfoAsync.value ?? const <String, ProductStockInfo>{};

    return SizedBox(
      // Taller than before to fit the purchase-info block under each card.
      height: 168,
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
                    AppBreakpoints.productTileExtent(constraints.maxWidth);
                final scrollStep = constraints.maxWidth * 0.75;
                return Stack(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 34),
                      child: GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSpacing.xs),
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
                            stockInfo: stockInfo[shown[index].id],
                            onSell: () => widget.onAddProduct(shown[index]),
                            onModify: () =>
                                widget.onModifyProduct(shown[index]),
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
                const SizedBox(height: AppSpacing.xs),
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
      duration: AppMotion.standardTransition,
      curve: AppMotion.standardTransitionCurve,
    );
  }
}

class _ProductCardButton extends StatelessWidget {
  const _ProductCardButton({
    required this.product,
    required this.stockInfo,
    required this.onSell,
    required this.onModify,
  });

  final ProductEntity product;
  final ProductStockInfo? stockInfo;
  final VoidCallback onSell;
  final VoidCallback onModify;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: onSell,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
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
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Text(
            FormattingHelpers.currencyPkr(product.salePrice),
            style: theme.textTheme.labelSmall
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            product.hasImei ? 'Serialized • IMEI' : 'Qty product',
            // Below the smallest defined type-scale step (labelSmall=11) —
            // deliberately kept as a fixed micro-size for this ultra-dense
            // stock-bar card rather than growing the card to fit the scale.
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (product.hasImei) ...<Widget>[
            const SizedBox(height: 2),
            _PurchaseInfoLine(stockInfo: stockInfo),
          ],
          const SizedBox(height: 4),
          // ── Action row ──────────────────────────────────────────────────
          Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 22,
                  child: FilledButton(
                    onPressed: onSell,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: const TextStyle(fontSize: 10),
                    ),
                    child: const Text('Sale'),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              SizedBox(
                height: 22,
                child: OutlinedButton(
                  onPressed: onModify,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 10),
                    foregroundColor: theme.colorScheme.secondary,
                    side: BorderSide(
                      color: theme.colorScheme.secondary.withValues(alpha: 0.6),
                    ),
                  ),
                  child: const Text('Modify'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Purchase Date / Purchase Price / Supplier of the oldest in-stock unit,
/// shown directly under the product so it always reflects the exact unit
/// that will be sold next — never a second click or page away. Falls back to
/// "-" per field when the data isn't available.
class _PurchaseInfoLine extends StatelessWidget {
  const _PurchaseInfoLine({required this.stockInfo});

  final ProductStockInfo? stockInfo;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 9,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      height: 1.3,
    );
    final purchaseDate = stockInfo?.purchaseDate;
    final costPrice = stockInfo?.costPrice;
    final supplierName = stockInfo?.supplierName;
    return Text(
      'Added: ${purchaseDate == null ? '-' : FormattingHelpers.dateYmd(purchaseDate)}\n'
      'Cost: ${costPrice == null ? '-' : FormattingHelpers.currencyPkr(costPrice)}\n'
      'Supplier: ${supplierName ?? '-'}',
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: style,
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.inventory_2_outlined,
              size: 22, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.xs),
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
