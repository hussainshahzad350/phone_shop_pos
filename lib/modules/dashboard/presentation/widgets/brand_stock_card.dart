import 'package:flutter/material.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/brand_stock_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/brand_stock_popup.dart';

class BrandStockCard extends StatefulWidget {
  const BrandStockCard({
    super.key,
    required this.brand,
  });

  final BrandStockEntity brand;

  @override
  State<BrandStockCard> createState() => _BrandStockCardState();
}

class _BrandStockCardState extends State<BrandStockCard> {
  bool _isHovered = false;

  String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1);
  }

  void _openPopup() {
    showDialog<void>(
      context: context,
      builder: (context) => BrandStockPopup(brandName: widget.brand.brandName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: _openPopup,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: Transform.translate(
            offset: Offset(0, _isHovered ? -3 : 0),
            child: Card(
              elevation: _isHovered ? 6 : 1,
              shadowColor: Colors.black.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _isHovered
                      ? colorScheme.primary.withValues(alpha: 0.5)
                      : Colors.grey.shade300,
                  width: _isHovered ? 1.5 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colorScheme.primary,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.smartphone,
                        color: colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _capitalize(widget.brand.brandName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.brand.modelCount} Model${widget.brand.modelCount == 1 ? '' : 's'}',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.brand.stockCount} Phone${widget.brand.stockCount == 1 ? '' : 's'}',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
