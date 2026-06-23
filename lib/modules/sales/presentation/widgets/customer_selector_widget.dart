import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/customer_option_entity.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/sales_query_providers.dart';

class CustomerSelectorWidget extends ConsumerStatefulWidget {
  const CustomerSelectorWidget({
    super.key,
    this.customers,
    required this.selectedCustomerId,
    required this.onChanged,
  });

  final List<CustomerOptionEntity>? customers;
  final String? selectedCustomerId;
  final ValueChanged<String?> onChanged;

  @override
  ConsumerState<CustomerSelectorWidget> createState() =>
      _CustomerSelectorWidgetState();
}

class _CustomerSelectorWidgetState
    extends ConsumerState<CustomerSelectorWidget> {
  static const int _defaultVisibleCustomerCount = 5;
  static final List<String> _recentCustomerIds = <String>[];
  late final TextEditingController _displayController;
  late final TextEditingController _searchController;
  bool _isDropdownOpen = false;
  bool _showAllCustomers = false;

  @override
  void initState() {
    super.initState();
    _displayController = TextEditingController();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _displayController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = widget.customers == null
        ? ref.watch(customerSearchResultsProvider)
        : null;
    final customers = widget.customers ??
        customersAsync?.value ??
        const <CustomerOptionEntity>[];
    final selectedLabel = _selectedLabel(customers);

    if (_displayController.text != selectedLabel) {
      _displayController.value = _displayController.value.copyWith(
        text: selectedLabel,
        selection: TextSelection.collapsed(offset: selectedLabel.length),
        composing: TextRange.empty,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            TextField(
              controller: _displayController,
              readOnly: true,
              onTap: _toggleDropdown,
              decoration: appDesktopInputDecoration(
                labelText: 'Customer',
                hintText: 'Search customer',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: widget.selectedCustomerId != null
                    ? const Icon(Icons.check_circle)
                    : const Icon(Icons.arrow_drop_down),
              ),
            ),
            if (customersAsync?.isLoading == true) ...<Widget>[
              const SizedBox(height: 6),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (customersAsync?.hasError == true) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                customersAsync!.error is AppError
                    ? (customersAsync.error as AppError).message
                    : 'Failed to load customers.',
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _retryLoadCustomers,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
            if (customersAsync?.isLoading != true &&
                customersAsync?.hasError != true &&
                customers.isEmpty) ...<Widget>[
              const SizedBox(height: 8),
              const Text('No customers found.'),
            ],
            if (_isDropdownOpen) ...<Widget>[
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration:
                    appDesktopInputDecoration(labelText: 'Search customer'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: _showAllCustomers ? double.infinity : 240,
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: <Widget>[
                          _walkInTile(),
                          ..._filteredCustomers(customers).map(_customerTile),
                        ],
                      ),
                    ),
                    if (_canShowMoreRow(customers)) _moreTile(),
                  ],
                ),
              ),
            ],
          ],
          ),
        ),
      ),
    );
  }

  void _toggleDropdown() {
    setState(() {
      if (_isDropdownOpen) {
        _isDropdownOpen = false;
        return;
      }
      _searchController.clear();
      _showAllCustomers = false;
      _isDropdownOpen = true;
    });
  }

  void _retryLoadCustomers() {
    ref.invalidate(customerSearchResultsProvider);
  }

  void _selectCustomer(String? selected) {
    if (selected == widget.selectedCustomerId) {
      setState(() => _isDropdownOpen = false);
      return;
    }
    if (selected != null) {
      _recordRecentCustomer(selected);
    }
    setState(() => _isDropdownOpen = false);
    widget.onChanged(selected);
  }

  List<CustomerOptionEntity> _filteredCustomers(
      List<CustomerOptionEntity> customers) {
    final search = _searchController.text.trim().toLowerCase();
    return search.isEmpty
        ? (_showAllCustomers ? customers : _defaultCustomers(customers))
        : customers.where((customer) {
            final name = customer.name.toLowerCase();
            final phone = customer.phone?.toLowerCase() ?? '';
            return name.contains(search) || phone.contains(search);
          }).toList(growable: false);
  }

  bool _canShowMoreRow(List<CustomerOptionEntity> customers) {
    return _searchController.text.trim().isEmpty &&
        !_showAllCustomers &&
        customers.length > _defaultVisibleCustomerCount;
  }

  List<CustomerOptionEntity> _defaultCustomers(
      List<CustomerOptionEntity> customers) {
    final byId = <String, CustomerOptionEntity>{
      for (final customer in customers) customer.id: customer,
    };

    final recent = <CustomerOptionEntity>[];
    for (final id in _recentCustomerIds) {
      final customer = byId[id];
      if (customer != null) {
        recent.add(customer);
      }
      if (recent.length == _defaultVisibleCustomerCount) {
        return recent;
      }
    }

    for (final customer in customers) {
      if (recent.any((item) => item.id == customer.id)) {
        continue;
      }
      recent.add(customer);
      if (recent.length == _defaultVisibleCustomerCount) {
        break;
      }
    }
    return recent;
  }

  void _showAll() {
    setState(() {
      _showAllCustomers = true;
    });
  }

  String _selectedLabel(List<CustomerOptionEntity> customers) {
    final selectedCustomer = customers
        .where((customer) => customer.id == widget.selectedCustomerId)
        .cast<CustomerOptionEntity?>()
        .firstOrNull;
    return selectedCustomer == null
        ? 'Walk-in Customer'
        : selectedCustomer.phone == null
            ? selectedCustomer.name
            : '${selectedCustomer.name} (${selectedCustomer.phone})';
  }

  void _recordRecentCustomer(String customerId) {
    _recentCustomerIds.remove(customerId);
    _recentCustomerIds.insert(0, customerId);
    if (_recentCustomerIds.length > 50) {
      _recentCustomerIds.removeRange(50, _recentCustomerIds.length);
    }
  }

  Widget _customerTile(CustomerOptionEntity customer) {
    final isSelected = customer.id == widget.selectedCustomerId;
    return ListTile(
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
      leading: CircleAvatar(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.secondaryContainer,
        foregroundColor: isSelected
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSecondaryContainer,
        child: Text(_initials(customer.name)),
      ),
      title: Text(customer.name),
      subtitle: customer.phone == null ? null : Text(customer.phone!),
      trailing: isSelected ? const Icon(Icons.check_circle) : null,
      onTap: () => _selectCustomer(customer.id),
    );
  }

  Widget _walkInTile() {
    final isSelected = widget.selectedCustomerId == null;
    return ListTile(
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
      leading: CircleAvatar(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.secondaryContainer,
        foregroundColor: isSelected
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSecondaryContainer,
        child: const Text('WI'),
      ),
      title: const Text('Walk-in Customer'),
      trailing: isSelected ? const Icon(Icons.check_circle) : null,
      onTap: () => _selectCustomer(null),
    );
  }

  Widget _moreTile() {
    return ListTile(
      leading: const Icon(Icons.more_horiz),
      title: const Text('More...'),
      onTap: _showAll,
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final first =
        parts.isNotEmpty && parts.first.isNotEmpty ? parts.first[0] : 'C';
    final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }
}
