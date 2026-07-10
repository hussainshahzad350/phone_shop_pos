import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';

/// A single selectable option for [AppSearchableDropdownField].
class AppSelectOption {
  const AppSelectOption({
    required this.id,
    required this.label,
    this.subtitle,
  });

  final String id;
  final String label;

  /// Optional secondary line (e.g. a phone number or IMEI) that is also
  /// matched while filtering.
  final String? subtitle;
}

/// A typeable single-select field whose results list opens in a floating
/// [OverlayPortal] anchored directly under the field.
///
/// Unlike the classic [DropdownButton] menu, the list:
/// - opens *below* the field and never overlaps it, so the field the operator
///   is editing stays visible;
/// - is height-capped and scrollable (mouse wheel + an always-visible
///   scrollbar) instead of a full-height sheet;
/// - has rounded corners matching the input field, so it reads as part of the
///   field rather than a detached list.
///
/// Use this instead of [DropdownButton] for pickers backed by a long, dynamic
/// list (customers, products, dealers, IMEIs) so the operator can type to
/// filter instead of scrolling a giant menu. Filtering is local over
/// [options]; callers that page results from a database should pass the
/// already-loaded list (this mirrors how the report filters and inventory
/// pickers already hold their options in memory).
class AppSearchableDropdownField extends StatefulWidget {
  const AppSearchableDropdownField({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.labelText,
    this.hintText,
    this.noneLabel,
    this.enabled = true,
  });

  /// Currently selected option id, or null when nothing (or the [noneLabel]
  /// option) is selected.
  final String? value;
  final List<AppSelectOption> options;
  final ValueChanged<String?> onChanged;
  final String? labelText;
  final String? hintText;

  /// When non-null, a leading tile with this text selects "no value" (id
  /// null) — used for filters where null means e.g. "All".
  final String? noneLabel;

  /// When false the field is greyed out and cannot be opened or edited
  /// (mirrors passing a null `onChanged` to a [DropdownButton]).
  final bool enabled;

  @override
  State<AppSearchableDropdownField> createState() =>
      _AppSearchableDropdownFieldState();
}

class _AppSearchableDropdownFieldState
    extends State<AppSearchableDropdownField> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final LayerLink _layerLink = LayerLink();
  final OverlayPortalController _overlayController = OverlayPortalController();
  final Object _tapGroupId = Object();
  double _fieldWidth = 300;
  bool _isDropdownOpen = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _searchFocusNode.removeListener(_handleFocusChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (_searchFocusNode.hasFocus && widget.enabled) {
      _openDropdown();
    }
  }

  @override
  Widget build(BuildContext context) {
    // While closed the field mirrors the current selection; while open it
    // holds the live search query the operator is typing.
    if (!_isDropdownOpen) {
      final label = _selectedLabel();
      if (_searchController.text != label) {
        _searchController.value = TextEditingValue(
          text: label,
          selection: TextSelection.collapsed(offset: label.length),
        );
      }
    }

    return TapRegion(
      groupId: _tapGroupId,
      onTapOutside: (_) => _closeDropdown(),
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: _buildOverlay,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth.isFinite) {
              _fieldWidth = constraints.maxWidth;
            }
            return CompositedTransformTarget(
              link: _layerLink,
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                enabled: widget.enabled,
                onTap: _openDropdown,
                onChanged: _onSearchChanged,
                decoration: appDesktopInputDecoration(
                  labelText: widget.labelText,
                  hintText: widget.hintText,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: _buildSuffixIcon(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredOptions();
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
              borderRadius: kAppDropdownMenuRadius,
              clipBehavior: Clip.antiAlias,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: kAppDropdownMenuRadius,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: kAppDropdownMenuMaxHeight,
                  ),
                  child: (filtered.isEmpty && widget.noneLabel == null)
                      ? const Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: Text('No matches found.'),
                        )
                      : Scrollbar(
                          controller: _scrollController,
                          thumbVisibility: true,
                          child: ListView(
                            controller: _scrollController,
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            children: <Widget>[
                              if (widget.noneLabel != null) _noneTile(),
                              ...filtered.map(_optionTile),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuffixIcon() {
    if (widget.value != null && widget.enabled) {
      return IconButton(
        tooltip: 'Clear',
        icon: const Icon(Icons.close),
        onPressed: _clearSelection,
      );
    }
    return Icon(
      _isDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
    );
  }

  Widget _optionTile(AppSelectOption option) {
    final isSelected = option.id == widget.value;
    return ListTile(
      dense: true,
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
      title: Text(option.label),
      subtitle: option.subtitle == null ? null : Text(option.subtitle!),
      trailing: isSelected ? const Icon(Icons.check, size: 18) : null,
      onTap: () => _select(option.id),
    );
  }

  Widget _noneTile() {
    final isSelected = widget.value == null;
    return ListTile(
      dense: true,
      selected: isSelected,
      selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
      title: Text(widget.noneLabel!),
      trailing: isSelected ? const Icon(Icons.check, size: 18) : null,
      onTap: () => _select(null),
    );
  }

  List<AppSelectOption> _filteredOptions() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.options;
    }
    return widget.options.where((option) {
      final label = option.label.toLowerCase();
      final subtitle = option.subtitle?.toLowerCase() ?? '';
      return label.contains(query) || subtitle.contains(query);
    }).toList(growable: false);
  }

  String _selectedLabel() {
    if (widget.value == null) {
      return widget.noneLabel ?? '';
    }
    for (final option in widget.options) {
      if (option.id == widget.value) {
        return option.label;
      }
    }
    return widget.noneLabel ?? '';
  }

  void _openDropdown() {
    if (_isDropdownOpen) {
      return;
    }
    // Start empty so the operator types a fresh query instead of editing the
    // displayed selection label.
    _searchController.clear();
    setState(() => _isDropdownOpen = true);
    _overlayController.show();
    _searchFocusNode.requestFocus();
  }

  void _closeDropdown() {
    if (!_isDropdownOpen) {
      return;
    }
    setState(() => _isDropdownOpen = false);
    _overlayController.hide();
    _searchFocusNode.unfocus();
  }

  void _onSearchChanged(String value) {
    setState(() => _isDropdownOpen = true);
    if (!_overlayController.isShowing) {
      _overlayController.show();
    }
  }

  void _select(String? id) {
    setState(() => _isDropdownOpen = false);
    _overlayController.hide();
    _searchFocusNode.unfocus();
    if (id != widget.value) {
      widget.onChanged(id);
    }
  }

  void _clearSelection() {
    setState(() => _isDropdownOpen = false);
    _overlayController.hide();
    _searchFocusNode.unfocus();
    if (widget.value != null) {
      widget.onChanged(null);
    }
  }
}
