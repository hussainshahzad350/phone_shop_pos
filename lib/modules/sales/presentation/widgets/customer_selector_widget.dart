import 'package:flutter/material.dart';

import 'package:phone_shop_pos/modules/sales/domain/entities/customer_option_entity.dart';

class CustomerSelectorWidget extends StatefulWidget {
  const CustomerSelectorWidget({
    super.key,
    required this.customers,
    required this.customerSearchQuery,
    required this.selectedCustomerId,
    required this.onChanged,
    required this.onSearchChanged,
  });

  final List<CustomerOptionEntity> customers;
  final String customerSearchQuery;
  final String? selectedCustomerId;
  final ValueChanged<String?> onChanged;
  final ValueChanged<String> onSearchChanged;

  @override
  State<CustomerSelectorWidget> createState() => _CustomerSelectorWidgetState();
}

class _CustomerSelectorWidgetState extends State<CustomerSelectorWidget> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.customerSearchQuery);
  }

  @override
  void didUpdateWidget(covariant CustomerSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_searchController.text == widget.customerSearchQuery) {
      return;
    }
    _searchController.value = _searchController.value.copyWith(
      text: widget.customerSearchQuery,
      selection: TextSelection.collapsed(
        offset: widget.customerSearchQuery.length,
      ),
      composing: TextRange.empty,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Customer', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search customer',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: widget.onSearchChanged,
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              key: ValueKey<String?>(widget.selectedCustomerId),
              initialValue: widget.selectedCustomerId,
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Walk-in Customer'),
                ),
                ...widget.customers.map(
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
              onChanged: widget.onChanged,
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
