import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/brand_stock_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/model_detail_widget.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/model_summary_widget.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

class BrandStockPopup extends ConsumerStatefulWidget {
  const BrandStockPopup({
    super.key,
    required this.brand,
  });

  final BrandStockEntity brand;

  @override
  ConsumerState<BrandStockPopup> createState() => _BrandStockPopupState();
}

class _BrandStockPopupState extends ConsumerState<BrandStockPopup> {
  int? _selectedModelIndex;

  @override
  Widget build(BuildContext context) {
    final modelStockAsync = ref.watch(
      dashboardModelImeiStockProvider(widget.brand.brandName),
    );

    return AlertDialog(
      title: Text(widget.brand.brandName),
      content: SizedBox(
        width: 700,
        child: modelStockAsync.when(
          data: (modelStocks) {
            if (modelStocks.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text('No stock available for this brand'),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const ScrollPhysics(),
              itemCount: modelStocks.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, index) {
                final model = modelStocks[index];
                final isSelected = _selectedModelIndex == index;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    ModelSummaryWidget(
                      modelStock: model,
                      onModelTap: () {
                        setState(() {
                          _selectedModelIndex = isSelected ? null : index;
                        });
                      },
                    ),
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.sm,
                        ),
                        child: ModelDetailWidget(
                          modelStock: model,
                        ),
                      ),
                  ],
                );
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (_, __) => const Center(
            child: Text('Failed to load stock data'),
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
}
