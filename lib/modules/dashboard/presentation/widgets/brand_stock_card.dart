import 'package:flutter/material.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/brand_stock_entity.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

/// Brand card styled as a phone silhouette (v2 mockup): speaker bar on top,
/// home bar below, circular brand-initial avatar and the units count in the
/// middle.
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
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final primary = theme.colorScheme.primary;

    Widget phoneBar({required double width, required double height}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: theme.colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.lgRadius,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                theme.colorScheme.surface,
                theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
              ],
            ),
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
              width: 2,
            ),
            borderRadius: AppRadii.lgRadius,
          ),
          child: Column(
            children: <Widget>[
              phoneBar(width: 34, height: 5),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: primary,
                      child: Text(
                        brand.brandName.isEmpty
                            ? '?'
                            : brand.brandName[0].toUpperCase(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      brand.brandName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${brand.stockCount}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                    Text(
                      'units in stock',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${brand.modelCount} models',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              phoneBar(width: 44, height: 4),
            ],
          ),
        ),
      ),
    );
  }
}
