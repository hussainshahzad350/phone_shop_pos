import 'package:flutter/material.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/model_imei_stock_entity.dart';

class ModelSummaryWidget extends StatelessWidget {
  const ModelSummaryWidget({
    super.key,
    required this.modelStock,
    required this.onModelTap,
  });

  final ModelImeiStockEntity modelStock;
  final VoidCallback onModelTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onModelTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  modelStock.modelName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${modelStock.quantity} Phones',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}