import 'package:flutter/material.dart';
import 'package:phone_shop_pos/modules/master_data/presentation/widgets/brands_panel.dart';
import 'package:phone_shop_pos/modules/master_data/presentation/widgets/customers_panel.dart';
import 'package:phone_shop_pos/modules/master_data/presentation/widgets/products_panel.dart';
import 'package:phone_shop_pos/modules/master_data/presentation/widgets/suppliers_panel.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

class MasterDataScreen extends StatelessWidget {
  const MasterDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                labelColor: colorScheme.onPrimary,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                splashBorderRadius: BorderRadius.circular(999),
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                tabs: const <Tab>[
                  Tab(child: _MasterDataTabLabel(text: 'Products')),
                  Tab(child: _MasterDataTabLabel(text: 'Brands')),
                  Tab(child: _MasterDataTabLabel(text: 'Suppliers')),
                  Tab(child: _MasterDataTabLabel(text: 'Customers')),
                ],
              ),
              const SizedBox(height: 8),
              const Expanded(
                child: TabBarView(
                  children: <Widget>[
                    ProductsPanel(),
                    BrandsPanel(),
                    SuppliersPanel(),
                    CustomersPanel(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MasterDataTabLabel extends StatelessWidget {
  const _MasterDataTabLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Text(text),
    );
  }
}
