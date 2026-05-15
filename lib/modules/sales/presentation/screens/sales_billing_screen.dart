import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/shortcuts/app_shortcut_manager.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/customer_option_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/repositories/sales_repository.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/billing_state_provider.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/cart_state_provider.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/sales_query_providers.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/sales_repository_provider.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/totals_provider.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/cart_table_widget.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/customer_selector_widget.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/payment_section_widget.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/product_search_bar.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/totals_panel_widget.dart';

class SalesBillingScreen extends ConsumerStatefulWidget {
  const SalesBillingScreen({super.key});

  @override
  ConsumerState<SalesBillingScreen> createState() => _SalesBillingScreenState();
}

class _SalesBillingScreenState extends ConsumerState<SalesBillingScreen> {
  final TextEditingController _productSearchController = TextEditingController();
  final FocusNode _productSearchFocus = FocusNode();
  final FocusNode _paymentMethodFocus = FocusNode();
  final FocusNode _paidAmountFocus = FocusNode();
  final FocusNode _notesFocus = FocusNode();
  bool _isCompleting = false;
  int _selectedCartIndex = 0;
  int _handledShortcutToken = 0;
  Timer? _productSearchDebounce;
  Timer? _customerSearchDebounce;

  @override
  void dispose() {
    _productSearchDebounce?.cancel();
    _customerSearchDebounce?.cancel();
    _productSearchController.dispose();
    _productSearchFocus.dispose();
    _paymentMethodFocus.dispose();
    _paidAmountFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  Future<void> _handleAddProduct(ProductEntity product) async {
    if (!product.hasImei) {
      final result = await ref.read(cartStateProvider.notifier).addToCart(
        product: product,
        quantity: 1,
      );
      _showResultError(result);
      if (result.isSuccess) {
        _focusSearchAfterAdd();
      }
      return;
    }

    final selected = await _showImeiPickerDialog(product);
    if (selected == null) {
      return;
    }

    final result = await ref.read(cartStateProvider.notifier).addToCart(
      product: product,
      serializedStockId: selected.id,
      imei: selected.imei1,
      price: selected.sellingPrice ?? product.salePrice,
    );
    _showResultError(result);
    if (result.isSuccess) {
      _focusSearchAfterAdd();
    }
  }

  Future<SerializedStockEntity?> _showImeiPickerDialog(ProductEntity product) async {
    final repository = await ref.read(salesRepositoryProvider.future);
    if (!mounted) {
      return null;
    }
    return showDialog<SerializedStockEntity>(
      context: context,
      builder: (context) => _ImeiPickerDialog(
        productName: product.name,
        productModelId: product.id,
        repository: repository,
      ),
    );
  }

  void _showResultError(Result<void> result) {
    if (result.isFailure) {
      final error = result.asFailure!.error;
      if (error.code == 'duplicate_imei') {
        AppNotifier.warning('Duplicate IMEI: ${error.message}');
      } else {
        AppNotifier.error(error.message);
      }
    }
  }

  void _focusSearchAfterAdd() {
    _productSearchFocus.requestFocus();
    _productSearchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _productSearchController.text.length,
    );
  }

  void _debouncedProductSearch(String value) {
    _productSearchDebounce?.cancel();
    _productSearchDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) {
        return;
      }
      ref.read(billingStateProvider.notifier).setProductSearchQuery(value);
    });
  }

  void _debouncedCustomerSearch(String value) {
    _customerSearchDebounce?.cancel();
    _customerSearchDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) {
        return;
      }
      ref.read(billingStateProvider.notifier).setCustomerSearchQuery(value);
    });
  }

  void _refreshSales() {
    ref.invalidate(productSearchResultsProvider);
    ref.invalidate(customerSearchResultsProvider);
    AppNotifier.info('Sales screen refreshed.');
  }

  void _handleEscape() {
    if (_isCompleting) {
      return;
    }
    final hasSearch = _productSearchController.text.trim().isNotEmpty;
    if (hasSearch) {
      _productSearchController.clear();
      ref.read(billingStateProvider.notifier).setProductSearchQuery('');
    }
    _focusSearchAfterAdd();
  }

  void _handleGlobalShortcut(AppShortcutEventState state) {
    if (!mounted || state.token == 0 || state.token == _handledShortcutToken) {
      return;
    }
    _handledShortcutToken = state.token;

    switch (state.event) {
      case AppShortcutEvent.focusSearch:
        _productSearchFocus.requestFocus();
        break;
      case AppShortcutEvent.focusPayment:
        _paymentMethodFocus.requestFocus();
        break;
      case AppShortcutEvent.refreshCurrentScreen:
        _refreshSales();
        break;
      case AppShortcutEvent.saveOrComplete:
        _completeSale();
        break;
      case null:
        break;
    }
  }

  void _selectNextCartRow(int delta, int total) {
    if (total <= 0) {
      return;
    }
    setState(() {
      _selectedCartIndex = (_selectedCartIndex + delta).clamp(0, total - 1);
    });
  }

  Future<void> _changeSelectedQuantity(
    List<CartItemEntity> cartItems,
    int delta,
  ) async {
    if (cartItems.isEmpty || _selectedCartIndex >= cartItems.length) {
      return;
    }
    final item = cartItems[_selectedCartIndex];
    if (item.hasImei) {
      return;
    }
    final nextQty = item.quantity + delta;
    if (nextQty <= 0) {
      return;
    }
    final result = await ref.read(cartStateProvider.notifier).updateQty(
      index: _selectedCartIndex,
      quantity: nextQty,
    );
    _showResultError(result);
  }

  Future<void> _removeSelectedCartRow(List<CartItemEntity> cartItems) async {
    if (cartItems.isEmpty || _selectedCartIndex >= cartItems.length) {
      return;
    }
    final result = await ref.read(cartStateProvider.notifier).removeFromCart(
      _selectedCartIndex,
    );
    _showResultError(result);
    if (result.isSuccess && mounted) {
      final upper = cartItems.length - 2;
      setState(() {
        _selectedCartIndex = upper < 0 ? 0 : _selectedCartIndex.clamp(0, upper);
      });
    }
  }

  Future<void> _completeSale() async {
    if (_isCompleting) {
      return;
    }
    setState(() {
      _isCompleting = true;
    });

    final totals = ref.read(totalsProvider);
    final billing = ref.read(billingStateProvider);

    final result = await ref
        .read(cartStateProvider.notifier)
        .completeSale(
          totals: totals,
          customerId: billing.selectedCustomerId,
          paymentMethod: billing.paymentMethod,
          notes: billing.notes,
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _isCompleting = false;
    });

    if (result.isSuccess) {
      ref.read(billingStateProvider.notifier).resetAfterSale();
      _productSearchController.clear();
      AppNotifier.success(
        'Sale completed. Invoice: ${result.asSuccess!.value.invoiceNumber}',
      );
      _focusSearchAfterAdd();
      return;
    }

    final error = result.asFailure!.error;
    final message = error.message;
    final lowerMessage = message.toLowerCase();
    final withRollbackSuffix = error.code.toLowerCase().contains('transaction') &&
            !lowerMessage.contains('rollback')
        ? '$message Rollback applied.'
        : message;
    AppNotifier.error(
      'Transaction failed. $withRollbackSuffix',
      action: SnackBarAction(
        label: 'Retry',
        onPressed: _completeSale,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppShortcutEventState>(appShortcutEventBusProvider, (previous, next) {
      _handleGlobalShortcut(next);
    });

    final billing = ref.watch(billingStateProvider);
    final productsAsync = ref.watch(productSearchResultsProvider);
    final customersAsync = ref.watch(customerSearchResultsProvider);
    final cartItems = ref.watch(cartStateProvider);
    final totals = ref.watch(totalsProvider);
    final products = productsAsync.value ?? const <ProductEntity>[];

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.arrowDown): _CartNextIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowUp): _CartPreviousIntent(),
        const SingleActivator(LogicalKeyboardKey.delete): _CartRemoveIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadAdd): _CartIncreaseQtyIntent(),
        const SingleActivator(LogicalKeyboardKey.equal): _CartIncreaseQtyIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadSubtract): _CartDecreaseQtyIntent(),
        const SingleActivator(LogicalKeyboardKey.minus): _CartDecreaseQtyIntent(),
        const SingleActivator(LogicalKeyboardKey.escape): _SalesEscapeIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _CartNextIntent: CallbackAction<_CartNextIntent>(
            onInvoke: (intent) {
              _selectNextCartRow(1, cartItems.length);
              return null;
            },
          ),
          _CartPreviousIntent: CallbackAction<_CartPreviousIntent>(
            onInvoke: (intent) {
              _selectNextCartRow(-1, cartItems.length);
              return null;
            },
          ),
          _CartIncreaseQtyIntent: CallbackAction<_CartIncreaseQtyIntent>(
            onInvoke: (intent) {
              _changeSelectedQuantity(cartItems, 1);
              return null;
            },
          ),
          _CartDecreaseQtyIntent: CallbackAction<_CartDecreaseQtyIntent>(
            onInvoke: (intent) {
              _changeSelectedQuantity(cartItems, -1);
              return null;
            },
          ),
          _CartRemoveIntent: CallbackAction<_CartRemoveIntent>(
            onInvoke: (intent) {
              _removeSelectedCartRow(cartItems);
              return null;
            },
          ),
          _SalesEscapeIntent: CallbackAction<_SalesEscapeIntent>(
            onInvoke: (intent) {
              _handleEscape();
              return null;
            },
          ),
        },
        child: Scaffold(
          body: AppLoadingOverlay(
            isLoading: _isCompleting,
            label: 'Completing sale...',
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: <Widget>[
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(1),
                    child: ProductSearchBar(
                      controller: _productSearchController,
                      focusNode: _productSearchFocus,
                      onChanged: _debouncedProductSearch,
                      onSubmitted: (_) {
                        if (products.isNotEmpty) {
                          _handleAddProduct(products.first);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 140,
                    child: Card(
                      child: productsAsync.when(
                        data: (products) => ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return SizedBox(
                              width: 260,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: OutlinedButton(
                                  onPressed: () => _handleAddProduct(product),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Text(
                                        product.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'PKR ${product.salePrice.toStringAsFixed(2)}',
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        product.hasImei
                                            ? 'Serialized (IMEI required)'
                                            : 'Quantity product',
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        error: (error, stack) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              const Text('Failed to load products'),
                              const SizedBox(height: 6),
                              OutlinedButton.icon(
                                onPressed: _refreshSales,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          flex: 3,
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: CartTableWidget(
                                items: cartItems,
                                selectedIndex: _selectedCartIndex,
                                onSelectRow: (index) {
                                  setState(() {
                                    _selectedCartIndex = index;
                                  });
                                },
                                onIncreaseQty: (index) {
                                  final item = cartItems[index];
                                  if (item.hasImei) {
                                    return;
                                  }
                                  ref.read(cartStateProvider.notifier).updateQty(
                                    index: index,
                                    quantity: item.quantity + 1,
                                  );
                                },
                                onDecreaseQty: (index) {
                                  final item = cartItems[index];
                                  if (item.hasImei || item.quantity <= 1) {
                                    return;
                                  }
                                  ref.read(cartStateProvider.notifier).updateQty(
                                    index: index,
                                    quantity: item.quantity - 1,
                                  );
                                },
                                onRemove: (index) {
                                  ref.read(cartStateProvider.notifier).removeFromCart(
                                    index,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: ListView(
                            children: <Widget>[
                              FocusTraversalOrder(
                                order: const NumericFocusOrder(2),
                                child: CustomerSelectorWidget(
                                  customers: customersAsync.value ??
                                      const <CustomerOptionEntity>[],
                                  selectedCustomerId: billing.selectedCustomerId,
                                  onChanged: (value) {
                                    ref
                                        .read(billingStateProvider.notifier)
                                        .setSelectedCustomerId(value);
                                  },
                                  onSearchChanged: _debouncedCustomerSearch,
                                ),
                              ),
                              const SizedBox(height: 8),
                              FocusTraversalOrder(
                                order: const NumericFocusOrder(3),
                                child: TotalsPanelWidget(
                                  totals: totals,
                                  onDiscountChanged: (value) {
                                    ref
                                        .read(billingStateProvider.notifier)
                                        .setDiscount(value);
                                  },
                                  onTaxChanged: (value) {
                                    ref.read(billingStateProvider.notifier).setTax(
                                          value,
                                        );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              FocusTraversalOrder(
                                order: const NumericFocusOrder(4),
                                child: PaymentSectionWidget(
                                  paymentMethod: billing.paymentMethod,
                                  paymentMethodFocusNode: _paymentMethodFocus,
                                  paidAmountFocusNode: _paidAmountFocus,
                                  notesFocusNode: _notesFocus,
                                  onPaymentMethodChanged: (value) {
                                    ref
                                        .read(billingStateProvider.notifier)
                                        .setPaymentMethod(value);
                                  },
                                  onPaidAmountChanged: (value) {
                                    ref
                                        .read(billingStateProvider.notifier)
                                        .setPaidAmount(value);
                                  },
                                  onNotesChanged: (value) {
                                    ref.read(billingStateProvider.notifier).setNotes(
                                          value,
                                        );
                                  },
                                  onPaidAmountSubmitted: _completeSale,
                                  onCompleteSale: _completeSale,
                                  isProcessing: _isCompleting,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartNextIntent extends Intent {
  const _CartNextIntent();
}

class _CartPreviousIntent extends Intent {
  const _CartPreviousIntent();
}

class _CartIncreaseQtyIntent extends Intent {
  const _CartIncreaseQtyIntent();
}

class _CartDecreaseQtyIntent extends Intent {
  const _CartDecreaseQtyIntent();
}

class _CartRemoveIntent extends Intent {
  const _CartRemoveIntent();
}

class _SalesEscapeIntent extends Intent {
  const _SalesEscapeIntent();
}

class _ImeiPickerDialog extends StatefulWidget {
  const _ImeiPickerDialog({
    required this.productName,
    required this.productModelId,
    required this.repository,
  });

  final String productName;
  final String productModelId;
  final SalesRepository repository;

  @override
  State<_ImeiPickerDialog> createState() => _ImeiPickerDialogState();
}

class _ImeiPickerDialogState extends State<_ImeiPickerDialog> {
  static const int _kMaxImeiResults = 120;
  static const Duration _kImeiSearchDebounce = Duration(milliseconds: 150);

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  bool _isLoading = false;
  List<SerializedStockEntity> _items = const <SerializedStockEntity>[];
  int _selectedIndex = 0;

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
    setState(() {
      _isLoading = true;
    });
    final result = await widget.repository.getAvailableImeis(
      widget.productModelId,
      query: query,
      limit: _kMaxImeiResults,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _items = result.fold(
        onSuccess: (items) => items,
        onFailure: (_) => const <SerializedStockEntity>[],
      );
      _selectedIndex = _items.isEmpty
          ? 0
          : _selectedIndex.clamp(0, _items.length - 1);
    });

    if (result.isFailure) {
      AppNotifier.error(result.asFailure!.error.message);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_kImeiSearchDebounce, () {
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
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: _onSearchChanged,
                  onSubmitted: (_) => _selectCurrent(),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
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
                              label: secondImei == null || secondImei.isEmpty
                                  ? 'IMEI 1 ${stock.imei1}'
                                  : 'IMEI 1 ${stock.imei1}, IMEI 2 $secondImei',
                              child: ExcludeSemantics(
                                child: ListTile(
                                  dense: true,
                                  selected: selected,
                                  title: Text(stock.imei1),
                                  subtitle: stock.imei2 == null
                                      ? null
                                      : Text(stock.imei2!),
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
