import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/services/operations/operation_manager.dart';
import 'package:phone_shop_pos/core/routing/current_route_provider.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/shortcuts/app_shortcut_manager.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/sale_totals_entity.dart';
import 'package:phone_shop_pos/modules/sales/presentation/helpers/sale_completion_flow.dart';
import 'package:phone_shop_pos/modules/sales/presentation/helpers/sales_shortcut_helpers.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/billing_state_provider.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/cart_state_provider.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/printing_providers.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/sales_query_providers.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/sales_repository_provider.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/totals_provider.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/cart_table_widget.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/customer_selector_widget.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/invoice_print_preview_dialog.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/imei_picker_dialog.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/payment_section_widget.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/product_grid_widget.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/product_search_bar.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/totals_panel_widget.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

/// Below this width the fixed-width checkout side panel starves the cart, so
/// the layout stacks: full-width cart plus a summary bar that opens the
/// checkout panel in a bottom sheet (tablet portrait / split screen).
const double _kSalesCompactLayoutWidth = 900.0;

bool _creditSaleRequiresRegisteredCustomer({
  required String? selectedCustomerId,
  required String paymentMethod,
  required double remaining,
}) {
  final normalizedCustomerId = selectedCustomerId?.trim();
  final isWalkInCustomer = normalizedCustomerId == null ||
      normalizedCustomerId.isEmpty ||
      normalizedCustomerId.toLowerCase() == 'walk_in';
  final isCreditMode =
      paymentMethod.trim().toLowerCase() == PaymentMethod.credit;
  return isCreditMode && remaining > 0 && isWalkInCustomer;
}

class SalesBillingScreen extends ConsumerStatefulWidget {
  const SalesBillingScreen({super.key});

  @override
  ConsumerState<SalesBillingScreen> createState() => _SalesBillingScreenState();
}

class _SalesBillingScreenState extends ConsumerState<SalesBillingScreen> {
  final TextEditingController _productSearchController =
      TextEditingController();
  final FocusNode _productSearchFocus = FocusNode();
  final FocusNode _paymentMethodFocus = FocusNode();
  final FocusNode _paidAmountFocus = FocusNode();
  final FocusNode _notesFocus = FocusNode();
  final ScrollController _rightPanelScrollController = ScrollController();
  bool _isCompleting = false;
  int _selectedCartIndex = 0;
  int _handledShortcutToken = 0;
  Timer? _productSearchDebounce;

  @override
  void initState() {
    super.initState();
    // Entering the Sales screen always starts with a clean search, so the
    // stock bar shows full stock instead of a filter left over from a previous
    // visit (the search query lives in a global provider that survives
    // navigation).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _productSearchController.clear();
      ref.read(billingStateProvider.notifier).setProductSearchQuery('');
    });
  }

  @override
  void dispose() {
    // Clear the quick-search filter so returning to Sales shows the full stock
    // bar instead of the last scanned/searched item.
    ref.read(billingStateProvider.notifier).setProductSearchQuery('');
    _productSearchDebounce?.cancel();
    _productSearchController.dispose();
    _productSearchFocus.dispose();
    _paymentMethodFocus.dispose();
    _paidAmountFocus.dispose();
    _notesFocus.dispose();
    _rightPanelScrollController.dispose();
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
        _clearSearchAfterAdd();
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
          imei2: selected.imei2,
          serialNumber: selected.serialNumber,
          price: selected.sellingPrice ?? product.salePrice,
        );
    _showResultError(result);
    if (result.isSuccess) {
      _clearSearchAfterAdd();
    }
  }

  /// After adding an item (scan or tap), clear the search so the stock bar
  /// resets to the full list, ready for the next scan.
  void _clearSearchAfterAdd() {
    _productSearchController.clear();
    ref.read(billingStateProvider.notifier).setProductSearchQuery('');
    _productSearchFocus.requestFocus();
  }

  Future<void> _handleSearchSubmitted(String query) async {
    final trimmed = query.trim();
    final products =
        ref.read(productSearchResultsProvider).value ?? const <ProductEntity>[];
    if (products.isEmpty) {
      return;
    }

    if (_isImeiFormat(trimmed)) {
      final added = await _tryAddExactImei(trimmed, products);
      if (added) {
        _productSearchController.clear();
        ref.read(billingStateProvider.notifier).setProductSearchQuery('');
        _focusSearchAfterAdd();
      }
      return;
    }

    _handleAddProduct(products.first);
  }

  bool _isImeiFormat(String value) {
    if (value.length != 14 && value.length != 15) {
      return false;
    }
    return RegExp(r'^\d+$').hasMatch(value);
  }

  Future<bool> _tryAddExactImei(
    String query,
    List<ProductEntity> products,
  ) async {
    final repository = await ref.read(salesRepositoryProvider.future);
    for (final product in products.where((p) => p.hasImei)) {
      final result = await repository.getAvailableImeis(
        product.id,
        query: query,
        limit: 1,
      );
      if (result.isFailure) {
        continue;
      }
      final matches = result.asSuccess!.value;
      if (matches.isEmpty) {
        continue;
      }
      final stock = matches.first;
      final addResult = await ref.read(cartStateProvider.notifier).addToCart(
            product: product,
            serializedStockId: stock.id,
            imei: stock.imei1,
            imei2: stock.imei2,
            serialNumber: stock.serialNumber,
            price: stock.sellingPrice ?? product.salePrice,
          );
      if (mounted) _showResultError(addResult);
      return addResult.isSuccess;
    }
    return false;
  }

  Future<SerializedStockEntity?> _showImeiPickerDialog(
      ProductEntity product) async {
    final repository = await ref.read(salesRepositoryProvider.future);
    if (!mounted) {
      return null;
    }
    return showDialog<SerializedStockEntity>(
      context: context,
      builder: (context) => ImeiPickerDialog(
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
    // Clearing should be instant (e.g. the ✕ button / Escape) so the stock bar
    // resets to full stock immediately instead of after the debounce window.
    if (value.isEmpty) {
      ref.read(billingStateProvider.notifier).setProductSearchQuery('');
      return;
    }
    _productSearchDebounce = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) {
        return;
      }
      ref.read(billingStateProvider.notifier).setProductSearchQuery(value);
    });
  }

  void _refreshSales() {
    ref.invalidate(productSearchResultsProvider);
    ref.invalidate(customerSearchResultsProvider);
    AppNotifier.info('Sales screen refreshed.');
  }

  bool _isSalesPath(String path) =>
      path == '/sales' || path.startsWith('/sales/');

  bool _requiresRegisteredCustomerForCredit({
    required String? selectedCustomerId,
    required String paymentMethod,
    required double remaining,
  }) {
    return _creditSaleRequiresRegisteredCustomer(
      selectedCustomerId: selectedCustomerId,
      paymentMethod: paymentMethod,
      remaining: remaining,
    );
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
    _handledShortcutToken = SalesGlobalShortcutHelper.handle(
      state: state,
      isMounted: mounted,
      handledShortcutToken: _handledShortcutToken,
      onFocusSearch: _productSearchFocus.requestFocus,
      onFocusPayment: _paymentMethodFocus.requestFocus,
      onRefreshCurrentScreen: _refreshSales,
      onSaveOrComplete: _completeSale,
    );
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
    final billing = ref.read(billingStateProvider);
    final totals = ref.read(totalsProvider);
    if (_requiresRegisteredCustomerForCredit(
      selectedCustomerId: billing.selectedCustomerId,
      paymentMethod: billing.paymentMethod,
      remaining: totals.remaining,
    )) {
      AppNotifier.warning(
        'Credit sale requires a registered customer. Please select a customer.',
      );
      return;
    }

    setState(() {
      _isCompleting = true;
    });

    final saleItemsSnapshot = List<CartItemEntity>.from(
      ref.read(cartStateProvider),
    );
    final flow = SaleCompletionFlow(
      trackSaleOperation: (action) {
        return ref.read(operationManagerProvider.notifier).track(
              code: 'save_sale',
              label: 'Saving sale',
              progressLabel: 'Saving sale and updating stock',
              action: (_) => action(),
            );
      },
      completeSale: () {
        return ref.read(cartStateProvider.notifier).completeSale(
              totals: totals,
              customerId: billing.selectedCustomerId,
              paymentMethod: billing.paymentMethod,
              notes: billing.notes,
            );
      },
      enqueueInvoice: (document) {
        return ref.read(invoicePrintQueueProvider.notifier).enqueue(document);
      },
      resetBilling: () {
        ref.read(billingStateProvider.notifier).resetAfterSale();
      },
    );
    final flowOutcome = await flow.run(
      billing: billing,
      saleItemsSnapshot: saleItemsSnapshot,
    );
    final result = flowOutcome.completionResult;

    if (!mounted) {
      return;
    }

    setState(() {
      _isCompleting = false;
    });

    if (result.isSuccess) {
      _handleSuccessfulSale(flowOutcome);
      return;
    }

    _handleFailedSale(result.asFailure!.error);
  }

  Future<void> _openCheckoutSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return Padding(
          // Keep the payment fields above the on-screen keyboard.
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _SalesCheckoutPanel(
                paymentMethodFocusNode: _paymentMethodFocus,
                paidAmountFocusNode: _paidAmountFocus,
                notesFocusNode: _notesFocus,
                isCompleting: _isCompleting,
                onCompleteSale: () {
                  Navigator.of(sheetContext).pop();
                  _completeSale();
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openPrintPreview(String jobId) async {
    final notifier = ref.read(invoicePrintQueueProvider.notifier);
    final job = notifier.findById(jobId);
    if (job == null || !mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => InvoicePrintPreviewDialog(jobId: jobId, job: job),
    );
  }

  void _handleSuccessfulSale(SaleCompletionFlowOutcome flowOutcome) {
    final completion = flowOutcome.completionResult.asSuccess!.value;
    final enqueueResult = flowOutcome.enqueueResult;
    _productSearchController.clear();
    _invalidateFinancialReportsAfterSale();
    if (enqueueResult != null && enqueueResult.isSuccess) {
      AppNotifier.success(
        'Sale completed. Invoice: ${completion.invoiceNumber}',
        action: SnackBarAction(
          label: 'Print Preview',
          onPressed: () => _openPrintPreview(enqueueResult.asSuccess!.value),
        ),
      );
    } else {
      AppNotifier.warning(
        'Sale completed, but the receipt queue could not be updated. Check printer queue health in Settings.',
      );
    }
    _focusSearchAfterAdd();
  }

  void _invalidateFinancialReportsAfterSale() {
    ref.read(reportWorkflowCoordinatorProvider).refreshSalesAfterCompletion();
    // Cascades through every dashboard/sidebar provider (KPIs, chart, feed,
    // low stock, brand stock, badges) so they reflect this sale immediately.
    refreshDashboardData(ref);
  }

  void _handleFailedSale(AppError error) {
    final message = error.message;
    final lowerMessage = message.toLowerCase();
    final withRollbackSuffix =
        error.code.toLowerCase().contains('transaction') &&
                !lowerMessage.contains('rollback')
            ? '$message Rollback applied.'
            : message;
    final detail = _buildFailureDetail(error);
    final fullMessage = detail == null
        ? 'Transaction failed. $withRollbackSuffix'
        : 'Transaction failed. $withRollbackSuffix\nReason: $detail';
    AppNotifier.error(
      fullMessage,
      action: SnackBarAction(
        label: 'Retry',
        onPressed: _completeSale,
      ),
      showCloseIcon: true,
    );
  }

  String? _buildFailureDetail(AppError error) {
    if (error.code != 'database_error') {
      return null;
    }
    final details = error.details;
    if (details == null) {
      return null;
    }

    final compact = details.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) {
      return null;
    }
    if (compact.length <= 180) {
      return compact;
    }
    return '${compact.substring(0, 180)}...';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppShortcutEventState>(appShortcutEventBusProvider,
        (previous, next) {
      _handleGlobalShortcut(next);
    });
    ref.listen<String>(currentRoutePathProvider, (previous, next) {
      final leftSales = previous != null &&
          _isSalesPath(previous) &&
          !_isSalesPath(next);
      if (leftSales) {
        ref.read(billingStateProvider.notifier).clearPaymentInputs();
      }
    });

    final cartItems = ref.watch(cartStateProvider);
    final totals = ref.watch(totalsProvider);

    return Shortcuts(
      shortcuts: salesScreenShortcuts,
      child: Actions(
        actions: buildSalesScreenActions(
          onCartNext: () => _selectNextCartRow(1, cartItems.length),
          onCartPrevious: () => _selectNextCartRow(-1, cartItems.length),
          onIncreaseQty: () => _changeSelectedQuantity(cartItems, 1),
          onDecreaseQty: () => _changeSelectedQuantity(cartItems, -1),
          onRemove: () => _removeSelectedCartRow(cartItems),
          onEscape: _handleEscape,
        ),
        child: Scaffold(
          body: AppLoadingOverlay(
            isLoading: _isCompleting,
            label: 'Completing sale...',
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: <Widget>[
                  FocusTraversalOrder(
                    order: const NumericFocusOrder(1),
                    child: ProductSearchBar(
                      controller: _productSearchController,
                      focusNode: _productSearchFocus,
                      onChanged: _debouncedProductSearch,
                      onSubmitted: _handleSearchSubmitted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ProductGridWidget(
                    onAddProduct: _handleAddProduct,
                    onRetry: _refreshSales,
                    onViewAllInInventory: () => context.go('/inventory'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final cartCard = Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.sm),
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
                              onUpdateUnitPrice: (index, price) {
                                ref
                                    .read(cartStateProvider.notifier)
                                    .updateUnitPrice(
                                      index: index,
                                      price: price,
                                    );
                              },
                              onRemove: (index) {
                                ref
                                    .read(cartStateProvider.notifier)
                                    .removeFromCart(
                                      index,
                                    );
                              },
                            ),
                          ),
                        );

                        if (constraints.maxWidth < _kSalesCompactLayoutWidth) {
                          // Compact (tablet portrait / split screen): the
                          // fixed side panel would starve the cart, so the
                          // checkout moves to a bottom sheet behind a
                          // summary bar.
                          return Column(
                            children: <Widget>[
                              Expanded(child: cartCard),
                              const SizedBox(height: AppSpacing.sm),
                              _CompactCheckoutBar(
                                totals: totals,
                                onOpenCheckout: _openCheckoutSheet,
                              ),
                            ],
                          );
                        }

                        final rightPanelWidth = constraints.maxWidth >= 1500
                            ? 360.0
                            : constraints.maxWidth >= 1200
                                ? 320.0
                                : 300.0;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(child: cartCard),
                            const SizedBox(width: AppSpacing.sm),
                            SizedBox(
                              width: rightPanelWidth,
                              child: Scrollbar(
                                controller: _rightPanelScrollController,
                                thumbVisibility: true,
                                child: ListView(
                                  controller: _rightPanelScrollController,
                                  children: <Widget>[
                                    _SalesCheckoutPanel(
                                      paymentMethodFocusNode:
                                          _paymentMethodFocus,
                                      paidAmountFocusNode: _paidAmountFocus,
                                      notesFocusNode: _notesFocus,
                                      isCompleting: _isCompleting,
                                      onCompleteSale: _completeSale,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
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

/// Customer, totals and payment column shared by the wide side panel and the
/// compact checkout bottom sheet. Watches the billing/totals providers itself
/// so the sheet stays live while the operator edits payment details.
class _SalesCheckoutPanel extends ConsumerWidget {
  const _SalesCheckoutPanel({
    required this.paymentMethodFocusNode,
    required this.paidAmountFocusNode,
    required this.notesFocusNode,
    required this.isCompleting,
    required this.onCompleteSale,
  });

  final FocusNode paymentMethodFocusNode;
  final FocusNode paidAmountFocusNode;
  final FocusNode notesFocusNode;
  final bool isCompleting;
  final VoidCallback onCompleteSale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(totalsProvider);
    final selectedCustomerId = ref.watch(
      billingStateProvider.select((state) => state.selectedCustomerId),
    );
    final paymentMethod = ref.watch(
      billingStateProvider.select((state) => state.paymentMethod),
    );
    final paidAmount = ref.watch(
      billingStateProvider.select((state) => state.paidAmount),
    );
    final notes = ref.watch(
      billingStateProvider.select((state) => state.notes),
    );
    final requiresRegisteredCustomerForCredit =
        _creditSaleRequiresRegisteredCustomer(
      selectedCustomerId: selectedCustomerId,
      paymentMethod: paymentMethod,
      remaining: totals.remaining,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        FocusTraversalOrder(
          order: const NumericFocusOrder(2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              CustomerSelectorWidget(
                selectedCustomerId: selectedCustomerId,
                onChanged: (value) {
                  ref
                      .read(billingStateProvider.notifier)
                      .setSelectedCustomerId(value);
                },
              ),
              if (requiresRegisteredCustomerForCredit)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Text(
                    'Registered customer is required for credit (udhar) sale.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FocusTraversalOrder(
          order: const NumericFocusOrder(3),
          child: TotalsPanelWidget(
            totals: totals,
            enteredPaidAmount: paidAmount,
            onDiscountChanged: (value) {
              ref.read(billingStateProvider.notifier).setDiscount(value);
            },
            onTaxChanged: (value) {
              ref.read(billingStateProvider.notifier).setTax(value);
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FocusTraversalOrder(
          order: const NumericFocusOrder(4),
          child: PaymentSectionWidget(
            paymentMethod: paymentMethod,
            paidAmount: paidAmount,
            notes: notes,
            paymentMethodFocusNode: paymentMethodFocusNode,
            paidAmountFocusNode: paidAmountFocusNode,
            notesFocusNode: notesFocusNode,
            onPaymentMethodChanged: (value) {
              ref.read(billingStateProvider.notifier).setPaymentMethod(value);
            },
            onPaidAmountChanged: (value) {
              ref.read(billingStateProvider.notifier).setPaidAmount(value);
            },
            onNotesChanged: (value) {
              ref.read(billingStateProvider.notifier).setNotes(value);
            },
            onPaidAmountSubmitted: onCompleteSale,
            onCompleteSale: onCompleteSale,
            isProcessing: isCompleting,
            canCompleteSale: !requiresRegisteredCustomerForCredit,
            disabledReason: 'Credit sale requires a registered customer.',
          ),
        ),
      ],
    );
  }
}

/// Compact-layout summary strip under the cart: shows the running total and
/// remaining balance and opens the checkout bottom sheet.
class _CompactCheckoutBar extends StatelessWidget {
  const _CompactCheckoutBar({
    required this.totals,
    required this.onOpenCheckout,
  });

  final SaleTotalsEntity totals;
  final VoidCallback onOpenCheckout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Total: ${FormattingHelpers.currencyPkr(totals.total)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (totals.remaining > 0)
                    Text(
                      'Remaining: '
                      '${FormattingHelpers.currencyPkr(totals.remaining)}',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.icon(
              onPressed: onOpenCheckout,
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Customer & Payment'),
            ),
          ],
        ),
      ),
    );
  }
}
