import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/customer_option_entity.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/billing_state_provider.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/sales_query_providers.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

/// Customer picker: a directly typeable field that runs a database search, a ✕
/// to clear the selection, and close-on-outside-click. The results list is
/// shown in a floating [OverlayPortal] anchored under the field, so opening it
/// does not push the totals/payment panel below it down.
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
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _overlayController = OverlayPortalController();
  final Object _tapGroupId = Object();
  Timer? _searchDebounce;
  CustomerOptionEntity? _selectedCustomer;
  List<CustomerOptionEntity> _customers = const <CustomerOptionEntity>[];
  bool _customersLoading = false;
  bool _customersHasError = false;
  Object? _customersError;
  double _fieldWidth = 300;
  bool _isDropdownOpen = false;
  bool _showAllCustomers = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchFocusNode.removeListener(_handleFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (_searchFocusNode.hasFocus) {
      _openDropdown();
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = widget.customers == null
        ? ref.watch(customerSearchResultsProvider)
        : null;
    _customers = widget.customers ??
        customersAsync?.value ??
        const <CustomerOptionEntity>[];
    _customersLoading = customersAsync?.isLoading == true;
    _customersHasError = customersAsync?.hasError == true;
    _customersError = customersAsync?.error;

    // Keep the resolved customer cached so the field label stays correct even
    // when the active search filters the selected customer out of results.
    if (widget.selectedCustomerId == null) {
      _selectedCustomer = null;
    } else {
      final resolved = _customers
          .where((customer) => customer.id == widget.selectedCustomerId)
          .cast<CustomerOptionEntity?>()
          .firstOrNull;
      if (resolved != null) {
        _selectedCustomer = resolved;
      }
    }

    // While closed, the search bar mirrors the current selection (a customer or
    // walk-in). While open it holds the live search query the user is typing.
    if (!_isDropdownOpen) {
      final label = _selectedLabel();
      if (_searchController.text != label) {
        _searchController.value = TextEditingValue(
          text: label,
          selection: TextSelection.collapsed(offset: label.length),
        );
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: TapRegion(
          groupId: _tapGroupId,
          onTapOutside: (_) => _closeDropdown(),
          child: OverlayPortal(
            controller: _overlayController,
            overlayChildBuilder: _buildOverlay,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _fieldWidth = constraints.maxWidth;
                return CompositedTransformTarget(
                  link: _layerLink,
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onTap: _openDropdown,
                    onChanged: _onSearchChanged,
                    decoration: appDesktopInputDecoration(
                      labelText: 'Customer',
                      hintText: 'Search customer by name or phone',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _buildSuffixIcon(),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final theme = Theme.of(context);
    return CompositedTransformFollower(
      link: _layerLink,
      targetAnchor: Alignment.bottomLeft,
      followerAnchor: Alignment.topLeft,
      offset: const Offset(0, 4),
      child: Align(
        alignment: Alignment.topLeft,
        child: TapRegion(
          groupId: _tapGroupId,
          child: SizedBox(
            width: _fieldWidth,
            child: Material(
              elevation: 4,
              borderRadius: AppRadii.smRadius,
              clipBehavior: Clip.antiAlias,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: AppRadii.smRadius,
                ),
                child: _buildOverlayContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlayContent() {
    if (_customersLoading) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }
    if (_customersHasError) {
      final message = _customersError is AppError
          ? (_customersError! as AppError).message
          : 'Failed to load customers.';
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(message),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _retryLoadCustomers,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: _showAllCustomers ? 360 : 240,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: <Widget>[
              _walkInTile(),
              ..._filteredCustomers(_customers).map(_customerTile),
            ],
          ),
        ),
        if (_canShowMoreRow(_customers)) _moreTile(),
      ],
    );
  }

  Widget _buildSuffixIcon() {
    if (widget.selectedCustomerId != null) {
      return IconButton(
        tooltip: 'Clear customer',
        icon: const Icon(Icons.close),
        onPressed: _clearSelection,
      );
    }
    return Icon(
      _isDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
    );
  }

  void _openDropdown() {
    if (_isDropdownOpen) {
      return;
    }
    // Start the search empty so the user can type a fresh query instead of
    // editing the displayed selection label.
    _searchController.clear();
    _searchDebounce?.cancel();
    if (widget.customers == null) {
      ref.read(billingStateProvider.notifier).setCustomerSearchQuery('');
    }
    setState(() {
      _isDropdownOpen = true;
      _showAllCustomers = false;
    });
    _overlayController.show();
    _searchFocusNode.requestFocus();
  }

  void _closeDropdown() {
    if (!_isDropdownOpen) {
      return;
    }
    _searchDebounce?.cancel();
    setState(() {
      _isDropdownOpen = false;
      _showAllCustomers = false;
    });
    _overlayController.hide();
    _searchFocusNode.unfocus();
  }

  void _onSearchChanged(String value) {
    // Local filtering gives instant feedback over the loaded list; the
    // debounced provider update runs the real database search so customers
    // beyond the initially loaded page are also found.
    setState(() {
      _isDropdownOpen = true;
      _showAllCustomers = false;
    });
    if (!_overlayController.isShowing) {
      _overlayController.show();
    }
    if (widget.customers != null) {
      return;
    }
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) {
        return;
      }
      ref
          .read(billingStateProvider.notifier)
          .setCustomerSearchQuery(value.trim());
    });
  }

  void _retryLoadCustomers() {
    ref.invalidate(customerSearchResultsProvider);
  }

  void _clearSelection() {
    _searchDebounce?.cancel();
    if (widget.customers == null) {
      ref.read(billingStateProvider.notifier).setCustomerSearchQuery('');
    }
    setState(() {
      _isDropdownOpen = false;
      _showAllCustomers = false;
    });
    _overlayController.hide();
    _searchFocusNode.unfocus();
    if (widget.selectedCustomerId != null) {
      widget.onChanged(null);
    }
  }

  void _selectCustomer(String? selected) {
    _searchDebounce?.cancel();
    if (widget.customers == null) {
      ref.read(billingStateProvider.notifier).setCustomerSearchQuery('');
    }
    setState(() {
      _isDropdownOpen = false;
      _showAllCustomers = false;
    });
    _overlayController.hide();
    _searchFocusNode.unfocus();
    if (selected != null) {
      _recordRecentCustomer(selected);
    }
    if (selected != widget.selectedCustomerId) {
      widget.onChanged(selected);
    }
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

  String _selectedLabel() {
    final selectedCustomer =
        widget.selectedCustomerId == null ? null : _selectedCustomer;
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
      dense: true,
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
      dense: true,
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
      dense: true,
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
