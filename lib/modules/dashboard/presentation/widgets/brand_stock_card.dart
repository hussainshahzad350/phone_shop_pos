import 'package:flutter/material.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/brand_stock_entity.dart';

class BrandStockCard extends StatelessWidget {
  const BrandStockCard({
    super.key,
    required this.brand,
    required this.onTap,
  });

  final BrandStockEntity brand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                _getBrandIcon(brand.brandName),
                size: 28,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 4),
              Text(
                brand.brandName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    'Models: ${brand.modelCount}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '|',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Phones: ${brand.stockCount}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getBrandIcon(String brandName) {
    final normalized = brandName.toLowerCase();
    if (normalized.contains('samsung')) {
      return Icons.phone_android;
    }
    if (normalized.contains('apple')) {
      return Icons.phone_iphone;
    }
    if (normalized.contains('vivo') || normalized.contains('oppo') ||
        normalized.contains('tecno') || normalized.contains('infinix')) {
      return Icons.smartphone;
    }
    return Icons.branding_watermark;
  }
}