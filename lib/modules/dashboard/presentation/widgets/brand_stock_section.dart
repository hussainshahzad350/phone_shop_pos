import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/brand_stock_card.dart';

class BrandStockSection extends ConsumerWidget {
  const BrandStockSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brandStockAsync = ref.watch(dashboardBrandStockProvider);

    return brandStockAsync.when(
      data: (brands) {
        if (brands.isEmpty) {
          return const SizedBox.shrink();
        }
        return GridView.builder(
          shrinkWrap: true,
          itemCount: brands.length,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 150,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.72,
          ),
          itemBuilder: (_, index) => BrandStockCard(brand: brands[index]),
        );
      },
      loading: () => const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox(
        height: 160,
        child: Center(child: Text('Failed to load brand stock.')),
      ),
    );
  }
}
