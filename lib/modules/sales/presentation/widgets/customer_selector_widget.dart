import 'package:flutter/material.dart';

import 'package:phone_shop_pos/modules/sales/domain/entities/customer_option_entity.dart';

class CustomerSelectorWidget extends StatelessWidget {
  const CustomerSelectorWidget({
    super.key,
    required this.customers,
    required this.selectedCustomerId,
    required this.onChanged,
    required this.onSearchChanged,
  });

  final List<CustomerOptionEntity> customers;
  final String? selectedCustomerId;
  final ValueChanged<String?> onChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Customer',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search customer',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: onSearchChanged,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: selectedCustomerId,
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Walk-in Customer'),
                ),
                ...customers.map(
                  (customer) => DropdownMenuItem<String?>(
                    value: customer.id,
                    child: Text(
                      customer.phone == null
                          ? customer.name
                          : '${customer.name} (${customer.phone})',
                    ),
                  ),
                ),
              ],
              onChanged: onChanged,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
