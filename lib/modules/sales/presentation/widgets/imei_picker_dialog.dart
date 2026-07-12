import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/theme/app_motion.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/core/utils/debouncer.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/repositories/sales_repository.dart';

class ImeiPickerDialog extends StatefulWidget {
  const ImeiPickerDialog({
    super.key,
    required this.productName,
    required this.productModelId,
    required this.repository,
  });

  static const int maxImeiResults = 120;
  static const Duration imeiSearchDebounce = AppMotion.fastDebounce;

  final String productName;
  final String productModelId;
  final SalesRepository repository;

  @override
  State<ImeiPickerDialog> createState() => _ImeiPickerDialogState();
}

class _ImeiPickerDialogState extends State<ImeiPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _resultsScrollController = ScrollController();
  final _debounce = Debouncer(delay: ImeiPickerDialog.imeiSearchDebounce);
  bool _isLoading = false;
  List<SerializedStockEntity> _items = const <SerializedStockEntity>[];
  Map<String, String> _supplierNames = const <String, String>{};
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
    _debounce.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _resultsScrollController.dispose();
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
        _supplierNames = const <String, String>{};
        _errorMessage = failure.message;
        _selectedIndex = 0;
      });
      AppNotifier.error(failure.message);
      return;
    }

    final items = result.asSuccess!.value;

    // Batch-fetch supplier names for all IMEIs that have a supplierId.
    final supplierIds = items
        .map((e) => e.supplierId)
        .whereType<String>()
        .toSet()
        .toList(growable: false);

    Map<String, String> supplierNames = const <String, String>{};
    if (supplierIds.isNotEmpty) {
      final namesResult = await widget.repository.getSupplierNames(supplierIds);
      if (namesResult.isSuccess) {
        supplierNames = namesResult.asSuccess!.value;
      }
    }

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _items = items;
      _supplierNames = supplierNames;
      _errorMessage = null;
      _selectedIndex =
          _items.isEmpty ? 0 : _selectedIndex.clamp(0, _items.length - 1);
    });
  }

  void _onSearchChanged(String value) {
    _debounce.run(() {
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
            width: 560,
            height: 440,
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: appDesktopInputDecoration(
                    hintText: 'Search IMEI / Serial',
                    prefixIcon: const Icon(Icons.search),
                  ).copyWith(
                    helperText: 'Enter = select, Esc = cancel, ↑↓ = navigate',
                  ),
                  onChanged: _onSearchChanged,
                  onSubmitted: (_) => _selectCurrent(),
                ),
                AppSpacing.gapSm,
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _errorMessage != null
                          ? AppErrorState(
                              message: _errorMessage!,
                              onRetry: () => _runSearch(
                                query: _searchController.text.trim(),
                              ),
                            )
                          : _items.isEmpty
                              ? const AppEmptyState(message: 'No IMEI matched.')
                              : Scrollbar(
                                  controller: _resultsScrollController,
                                  thumbVisibility: true,
                                  child: ListView.builder(
                                    controller: _resultsScrollController,
                                    itemCount: _items.length,
                                    itemBuilder: (context, index) {
                                      final stock = _items[index];
                                      final selected = index == _selectedIndex;
                                      final secondImei = stock.imei2?.trim();
                                      final supplierName =
                                          stock.supplierId != null
                                              ? _supplierNames[stock.supplierId]
                                              : null;
                                      final effectivePurchaseDate =
                                          stock.purchaseDate ?? stock.createdAt;

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
                                            title:
                                                Text('IMEI 1: ${stock.imei1}'),
                                            subtitle: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                if (secondImei != null &&
                                                    secondImei.isNotEmpty)
                                                  Text('IMEI 2: $secondImei'),
                                                _PurchaseInfoRow(
                                                  purchaseDate:
                                                      effectivePurchaseDate,
                                                  costPrice: stock.costPrice,
                                                  supplierName: supplierName,
                                                ),
                                              ],
                                            ),
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

class _PurchaseInfoRow extends StatelessWidget {
  const _PurchaseInfoRow({
    required this.purchaseDate,
    required this.costPrice,
    required this.supplierName,
  });

  final DateTime purchaseDate;
  final double costPrice;
  final String? supplierName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final style = theme.textTheme.bodySmall?.copyWith(color: color);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: <Widget>[
          Icon(Icons.calendar_today_outlined, size: 11, color: color),
          const SizedBox(width: 3),
          Text(FormattingHelpers.dateYmd(purchaseDate), style: style),
          const SizedBox(width: 10),
          Icon(Icons.attach_money_outlined, size: 11, color: color),
          const SizedBox(width: 2),
          Text(
            FormattingHelpers.currencyPkr(costPrice),
            style: style?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (supplierName != null) ...<Widget>[
            const SizedBox(width: 10),
            Icon(Icons.store_outlined, size: 11, color: color),
            const SizedBox(width: 2),
            Flexible(
              child: Text(
                supplierName!,
                style: style,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
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
