import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/utils/debouncer.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_option_entity.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_form_state_provider.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_query_providers.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/supplier_providers.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

/// A minimal, source-agnostic supplier option used internally by
/// [SupplierSelectorWidget] so the same picker UI can be fed either by the
/// purchase form's live search provider or, in [SupplierSelectorWidget.standalone]
/// mode, by a direct repository query — without those two screens sharing any
/// state (a standalone instance must never mutate the purchase form's search
/// query).
class _SupplierOption {
  const _SupplierOption({required this.id, required this.name, this.phone});
  final String id;
  final String name;
  final String? phone;
}

/// Supplier picker modeled on the Sales customer selector: a directly typeable
/// field that runs a database search, a ✕ to clear the selection, and
/// close-on-outside-click. A supplier is optional, so the default state reads
/// as "No supplier".
///
/// The results list is shown in a floating [OverlayPortal] anchored under the
/// field, so opening it does not push the totals/payment panel below it down.
///
/// By default this reads/writes the Purchases screen's shared
/// [purchaseFormStateProvider] search query. Pass [standalone] to use this
/// picker from any other screen (e.g. Inventory's IMEI management) with its
/// own local search state instead, so it never leaks into purchase-form state.
class SupplierSelectorWidget extends ConsumerStatefulWidget {
  const SupplierSelectorWidget({
    super.key,
    required this.selectedSupplierId,
    required this.onChanged,
    this.standalone = false,
  });

  final String? selectedSupplierId;
  final ValueChanged<String?> onChanged;
  final bool standalone;

  @override
  ConsumerState<SupplierSelectorWidget> createState() =>
      _SupplierSelectorWidgetState();
}

class _SupplierSelectorWidgetState
    extends ConsumerState<SupplierSelectorWidget> {
  static const int _defaultVisibleSupplierCount = 5;
  static final List<String> _recentSupplierIds = <String>[];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _overlayController = OverlayPortalController();
  final Object _tapGroupId = Object();
  final _searchDebounce = Debouncer();
  _SupplierOption? _selectedSupplier;
  List<_SupplierOption> _suppliers = const <_SupplierOption>[];
  bool _suppliersLoading = false;
  double _fieldWidth = 300;
  bool _isDropdownOpen = false;
  bool _showAllSuppliers = false;

  // Standalone-mode search state (unused when widget.standalone is false).
  int _standaloneRequestId = 0;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_handleFocusChanged);
    if (widget.standalone) {
      _runStandaloneSearch('');
    }
  }

  @override
  void dispose() {
    _searchDebounce.cancel();
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

  Future<void> _runStandaloneSearch(String query) async {
    final requestId = ++_standaloneRequestId;
    setState(() => _suppliersLoading = true);
    final repository = await ref.read(supplierRepositoryProvider.future);
    final result = await repository.searchSuppliers(query, isActive: true, limit: 30);
    if (!mounted || requestId != _standaloneRequestId) {
      return;
    }
    setState(() {
      _suppliersLoading = false;
      _suppliers = result.fold(
        onSuccess: (suppliers) => suppliers
            .map((s) => _SupplierOption(id: s.id, name: s.name, phone: s.phone))
            .toList(growable: false),
        onFailure: (_) => const <_SupplierOption>[],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.standalone) {
      final suppliersAsync = ref.watch(supplierSearchResultsProvider);
      _suppliers = (suppliersAsync.value ?? const <SupplierOptionEntity>[])
          .map((s) => _SupplierOption(id: s.id, name: s.name, phone: s.phone))
          .toList(growable: false);
      _suppliersLoading = suppliersAsync.isLoading;
    }

    // Keep the resolved supplier cached so the field label stays correct even
    // when the active search filters the selected supplier out of results.
    if (widget.selectedSupplierId == null) {
      _selectedSupplier = null;
    } else {
      final resolved = _suppliers
          .where((supplier) => supplier.id == widget.selectedSupplierId)
          .cast<_SupplierOption?>()
          .firstOrNull;
      if (resolved != null) {
        _selectedSupplier = resolved;
      }
    }

    // While closed, the search bar mirrors the current selection (a supplier or
    // "No supplier"). While open it holds the live search query.
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
                      labelText: 'Supplier',
                      hintText: 'Search supplier by name or phone',
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (_suppliersLoading) const LinearProgressIndicator(minHeight: 2),
                    if (!_suppliersLoading && _suppliers.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No suppliers found.'),
                      )
                    else
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: _showAllSuppliers ? 360 : 240,
                        ),
                        child: ListView(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          children: <Widget>[
                            _noSupplierTile(),
                            ..._filteredSuppliers(_suppliers).map(_supplierTile),
                          ],
                        ),
                      ),
                    if (_canShowMoreRow(_suppliers)) _moreTile(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuffixIcon() {
    if (widget.selectedSupplierId != null) {
      return IconButton(
        tooltip: 'Clear supplier',
        icon: const Icon(Icons.close),
        onPressed: _clearSelection,
      );
    }
    return Icon(
      _isDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
    );
  }

  void _resetSearchQuery() {
    if (widget.standalone) {
      _runStandaloneSearch('');
    } else {
      ref.read(purchaseFormStateProvider.notifier).setSupplierSearchQuery('');
    }
  }

  void _openDropdown() {
    if (_isDropdownOpen) {
      return;
    }
    _searchController.clear();
    _searchDebounce.cancel();
    _resetSearchQuery();
    setState(() {
      _isDropdownOpen = true;
      _showAllSuppliers = false;
    });
    _overlayController.show();
    _searchFocusNode.requestFocus();
  }

  void _closeDropdown() {
    if (!_isDropdownOpen) {
      return;
    }
    _searchDebounce.cancel();
    setState(() {
      _isDropdownOpen = false;
      _showAllSuppliers = false;
    });
    _overlayController.hide();
    _searchFocusNode.unfocus();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _isDropdownOpen = true;
      _showAllSuppliers = false;
    });
    if (!_overlayController.isShowing) {
      _overlayController.show();
    }
    _searchDebounce.run(() {
      if (!mounted) {
        return;
      }
      if (widget.standalone) {
        _runStandaloneSearch(value.trim());
      } else {
        ref
            .read(purchaseFormStateProvider.notifier)
            .setSupplierSearchQuery(value.trim());
      }
    });
  }

  void _clearSelection() {
    _searchDebounce.cancel();
    _resetSearchQuery();
    setState(() {
      _isDropdownOpen = false;
      _showAllSuppliers = false;
    });
    _overlayController.hide();
    _searchFocusNode.unfocus();
    if (widget.selectedSupplierId != null) {
      widget.onChanged(null);
    }
  }

  void _selectSupplier(String? selected) {
    _searchDebounce.cancel();
    _resetSearchQuery();
    setState(() {
      _isDropdownOpen = false;
      _showAllSuppliers = false;
    });
    _overlayController.hide();
    _searchFocusNode.unfocus();
    if (selected != null) {
      _recordRecentSupplier(selected);
    }
    if (selected != widget.selectedSupplierId) {
      widget.onChanged(selected);
    }
  }

  List<_SupplierOption> _filteredSuppliers(List<_SupplierOption> suppliers) {
    final search = _searchController.text.trim().toLowerCase();
    return search.isEmpty
        ? (_showAllSuppliers ? suppliers : _defaultSuppliers(suppliers))
        : suppliers.where((supplier) {
            final name = supplier.name.toLowerCase();
            final phone = supplier.phone?.toLowerCase() ?? '';
            return name.contains(search) || phone.contains(search);
          }).toList(growable: false);
  }

  bool _canShowMoreRow(List<_SupplierOption> suppliers) {
    return _searchController.text.trim().isEmpty &&
        !_showAllSuppliers &&
        suppliers.length > _defaultVisibleSupplierCount;
  }

  List<_SupplierOption> _defaultSuppliers(List<_SupplierOption> suppliers) {
    final byId = <String, _SupplierOption>{
      for (final supplier in suppliers) supplier.id: supplier,
    };

    final recent = <_SupplierOption>[];
    for (final id in _recentSupplierIds) {
      final supplier = byId[id];
      if (supplier != null) {
        recent.add(supplier);
      }
      if (recent.length == _defaultVisibleSupplierCount) {
        return recent;
      }
    }

    for (final supplier in suppliers) {
      if (recent.any((item) => item.id == supplier.id)) {
        continue;
      }
      recent.add(supplier);
      if (recent.length == _defaultVisibleSupplierCount) {
        break;
      }
    }
    return recent;
  }

  void _showAll() {
    setState(() {
      _showAllSuppliers = true;
    });
  }

  String _selectedLabel() {
    final selectedSupplier =
        widget.selectedSupplierId == null ? null : _selectedSupplier;
    return selectedSupplier == null
        ? 'No supplier'
        : selectedSupplier.phone == null
            ? selectedSupplier.name
            : '${selectedSupplier.name} (${selectedSupplier.phone})';
  }

  void _recordRecentSupplier(String supplierId) {
    _recentSupplierIds.remove(supplierId);
    _recentSupplierIds.insert(0, supplierId);
    if (_recentSupplierIds.length > 50) {
      _recentSupplierIds.removeRange(50, _recentSupplierIds.length);
    }
  }

  Widget _supplierTile(_SupplierOption supplier) {
    final isSelected = supplier.id == widget.selectedSupplierId;
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
        child: Text(_initials(supplier.name)),
      ),
      title: Text(supplier.name),
      subtitle: supplier.phone == null ? null : Text(supplier.phone!),
      trailing: isSelected ? const Icon(Icons.check_circle) : null,
      onTap: () => _selectSupplier(supplier.id),
    );
  }

  Widget _noSupplierTile() {
    final isSelected = widget.selectedSupplierId == null;
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
        child: const Icon(Icons.block, size: 18),
      ),
      title: const Text('No supplier'),
      trailing: isSelected ? const Icon(Icons.check_circle) : null,
      onTap: () => _selectSupplier(null),
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
        parts.isNotEmpty && parts.first.isNotEmpty ? parts.first[0] : 'S';
    final second = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (first + second).toUpperCase();
  }
}
