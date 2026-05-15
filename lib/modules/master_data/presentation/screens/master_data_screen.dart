import 'package:flutter/material.dart';
import 'package:phone_shop_pos/modules/master_data/presentation/widgets/brands_panel.dart';
import 'package:phone_shop_pos/modules/master_data/presentation/widgets/customers_panel.dart';
import 'package:phone_shop_pos/modules/master_data/presentation/widgets/products_panel.dart';
import 'package:phone_shop_pos/modules/master_data/presentation/widgets/suppliers_panel.dart';

class MasterDataScreen extends StatelessWidget {
  const MasterDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Master Data Management',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const TabBar(
                isScrollable: true,
                tabs: <Tab>[
                  Tab(text: 'Products'),
                  Tab(text: 'Brands'),
                  Tab(text: 'Suppliers'),
                  Tab(text: 'Customers'),
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
