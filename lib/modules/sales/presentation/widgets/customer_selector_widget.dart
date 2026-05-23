import 'package:flutter/material.dart';

import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/customer_option_entity.dart';

class CustomerSelectorWidget extends StatefulWidget {
  const CustomerSelectorWidget({
    super.key,
    required this.customers,
    required this.selectedCustomerId,
    required this.onChanged,
  });

  final List<CustomerOptionEntity> customers;
  final String? selectedCustomerId;
  final ValueChanged<String?> onChanged;

  @override
  State<CustomerSelectorWidget> createState() => _CustomerSelectorWidgetState();
}

class _CustomerSelectorWidgetState extends State<CustomerSelectorWidget> {
  static const int _defaultVisibleCustomerCount = 5;
  static final List<String> _recentCustomerIds = <String>[];
  late final TextEditingController _displayController;
  late final TextEditingController _searchController;
  bool _isDropdownOpen = false;
  bool _showAllCustomers = false;

  @override
  void initState() {
    super.initState();
    _displayController = TextEditingController(text: _selectedLabel());
    _searchController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant CustomerSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _selectedLabel();
    if (_displayController.text == next) {
      return;
    }
    _displayController.value = _displayController.value.copyWith(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
      composing: TextRange.empty,
    );
  }

  @override
  void dispose() {
    _displayController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCustomer = widget.customers
        .where((customer) => customer.id == widget.selectedCustomerId)
        .cast<CustomerOptionEntity?>()
        .firstOrNull;
    final selectedLabel = selectedCustomer == null
        ? 'Walk-in Customer'
        : selectedCustomer.phone == null
            ? selectedCustomer.name
            : '${selectedCustomer.name} (${selectedCustomer.phone})';

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
                suffixIcon: const Icon(Icons.arrow_drop_down),
              ),
            ),
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
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      _walkInTile(),
                      ..._filteredCustomers().map(_customerTile),
                      if (_canShowMoreRow()) _moreTile(),
                    ],
                  ),
                ),
              ),
            ],
          ],
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

  List<CustomerOptionEntity> _filteredCustomers() {
    final search = _searchController.text.trim().toLowerCase();
    return search.isEmpty
        ? (_showAllCustomers ? widget.customers : _defaultCustomers())
        : widget.customers.where((customer) {
            final name = customer.name.toLowerCase();
            final phone = customer.phone?.toLowerCase() ?? '';
            return name.contains(search) || phone.contains(search);
          }).toList(growable: false);
  }

  bool _canShowMoreRow() {
    return _searchController.text.trim().isEmpty &&
        !_showAllCustomers &&
        widget.customers.length > _defaultVisibleCustomerCount;
  }

  List<CustomerOptionEntity> _defaultCustomers() {
    final byId = <String, CustomerOptionEntity>{
      for (final customer in widget.customers) customer.id: customer,
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

    for (final customer in widget.customers) {
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

  String _selectedLabel() {
    final selectedCustomer = widget.customers
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
