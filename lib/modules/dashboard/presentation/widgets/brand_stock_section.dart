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
  final VoidCallback onBrandTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Brand Stock',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: brands.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.0,
              ),
              itemBuilder: (_, index) => BrandStockCard(
                brand: brands[index],
                onTap: onBrandTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
