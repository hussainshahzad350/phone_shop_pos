import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/repositories/sales_repository.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

class ImeiPickerDialog extends StatefulWidget {
  const ImeiPickerDialog({
    super.key,
    required this.productName,
    required this.productModelId,
    required this.repository,
  });

  static const int maxImeiResults = 120;
  static const Duration imeiSearchDebounce = Duration(milliseconds: 150);

  final String productName;
  final String productModelId;
  final SalesRepository repository;

  @override
  State<ImeiPickerDialog> createState() => _ImeiPickerDialogState();
}

class _ImeiPickerDialogState extends State<ImeiPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  bool _isLoading = false;
  List<SerializedStockEntity> _items = const <SerializedStockEntity>[];
  String? _errorMessage;
  int _selectedIndex = 0;
  int _latestSearchToken = 0;

  @override
  void initState() {
    super.initState();
    _runSearch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _runSearch({String query = ''}) async {
    final searchToken = ++_latestSearchToken;
    setState(() {
      _isLoading = true;
    });
    final result = await widget.repository.getAvailableImeis(
      widget.productModelId,
      query: query,
      limit: ImeiPickerDialog.maxImeiResults,
    );
    if (!mounted) {
      return;
    }
    if (searchToken != _latestSearchToken) {
      return;
    }

    if (result.isFailure) {
      final failure = result.asFailure!.error;
      setState(() {
        _isLoading = false;
        _items = const <SerializedStockEntity>[];
        _errorMessage = failure.message;
        _selectedIndex = 0;
      });
      AppNotifier.error(failure.message);
      return;
    }

    final items = result.asSuccess!.value;
    setState(() {
      _isLoading = false;
      _items = items;
      _errorMessage = null;
      _selectedIndex =
          _items.isEmpty ? 0 : _selectedIndex.clamp(0, _items.length - 1);
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(ImeiPickerDialog.imeiSearchDebounce, () {
      _runSearch(query: value.trim());
    });
  }

  void _moveSelection(int delta) {
    if (_items.isEmpty) {
      return;
    }
    setState(() {
      _selectedIndex = (_selectedIndex + delta).clamp(0, _items.length - 1);
    });
  }

  void _selectCurrent() {
    if (_items.isEmpty) {
      return;
    }
    Navigator.of(context).pop(_items[_selectedIndex]);
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): _ImeiCancelIntent(),
        SingleActivator(LogicalKeyboardKey.enter): _ImeiSelectIntent(),
        SingleActivator(LogicalKeyboardKey.arrowDown): _ImeiDownIntent(),
        SingleActivator(LogicalKeyboardKey.arrowUp): _ImeiUpIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ImeiCancelIntent: CallbackAction<_ImeiCancelIntent>(
            onInvoke: (_) {
              Navigator.of(context).pop();
              return null;
            },
          ),
          _ImeiSelectIntent: CallbackAction<_ImeiSelectIntent>(
            onInvoke: (_) {
              _selectCurrent();
              return null;
            },
          ),
          _ImeiDownIntent: CallbackAction<_ImeiDownIntent>(
            onInvoke: (_) {
              _moveSelection(1);
              return null;
            },
          ),
          _ImeiUpIntent: CallbackAction<_ImeiUpIntent>(
            onInvoke: (_) {
              _moveSelection(-1);
              return null;
            },
          ),
        },
        child: AlertDialog(
          title: Text('Select IMEI - ${widget.productName}'),
          content: SizedBox(
            width: 520,
            height: 440,
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    hintText: 'Search IMEI / Serial',
                    helperText: 'Enter = select, Esc = cancel, ↑↓ = navigate',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: _onSearchChanged,
                  onSubmitted: (_) => _selectCurrent(),
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Text(_errorMessage!),
                                  const SizedBox(height: AppSpacing.sm),
                                  OutlinedButton.icon(
                                    onPressed: () => _runSearch(
                                      query: _searchController.text.trim(),
                                    ),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _items.isEmpty
                          ? const Center(child: Text('No IMEI matched.'))
                          : ListView.builder(
                              itemCount: _items.length,
                              itemBuilder: (context, index) {
                                final stock = _items[index];
                                final selected = index == _selectedIndex;
                                final secondImei = stock.imei2?.trim();
                                return Semantics(
                                  selected: selected,
                                  label: secondImei == null ||
                                          secondImei.isEmpty
                                      ? 'IMEI 1 ${stock.imei1}'
                                      : 'IMEI 1 ${stock.imei1}, IMEI 2 $secondImei',
                                  child: ExcludeSemantics(
                                    child: ListTile(
                                      dense: true,
                                      selected: selected,
                                      title: Text('IMEI 1: ${stock.imei1}'),
                                      subtitle: stock.imei2 == null
                                          ? null
                                          : Text('IMEI 2: ${stock.imei2!}'),
                                      onTap: () {
                                        setState(() {
                                          _selectedIndex = index;
                                        });
                                        _selectCurrent();
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _items.isEmpty ? null : _selectCurrent,
              child: const Text('Select'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImeiCancelIntent extends Intent {
  const _ImeiCancelIntent();
}

class _ImeiSelectIntent extends Intent {
  const _ImeiSelectIntent();
}

class _ImeiDownIntent extends Intent {
  const _ImeiDownIntent();
}

class _ImeiUpIntent extends Intent {
  const _ImeiUpIntent();
}
