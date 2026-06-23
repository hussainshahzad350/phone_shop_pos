import 'package:flutter/material.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/brand_stock_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/brand_stock_card.dart';

class BrandStockSection extends StatelessWidget {
  const BrandStockSection({
    super.key,
    required this.brands,
    required this.onBrandTap,
  });

  final List<BrandStockEntity> brands;

  /// Called with the brand whose card was tapped.
  final ValueChanged<BrandStockEntity> onBrandTap;

  /// Number of brand cards per row, sized so ~8 fit on a large desktop and
  /// the grid steps down gracefully on smaller widths.
  int _columnsForWidth(double width) {
    if (width >= 1500) {
      return 8;
    }
    if (width >= 1200) {
      return 6;
    }
    if (width >= 800) {
      return 4;
    }
    if (width >= 520) {
      return 3;
    }
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    if (brands.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            LayoutBuilder(
              builder: (context, constraints) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: brands.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: _columnsForWidth(constraints.maxWidth),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    // Portrait (phone-shaped) cells, tall enough to show the
                    // icon, brand name, stock count and model count without
                    // clipping. Fixed height keeps every card identical.
                    mainAxisExtent: 188,
                  ),
                  itemBuilder: (_, index) => BrandStockCard(
                    brand: brands[index],
                    onTap: () => onBrandTap(brands[index]),
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
