import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/services/printing/invoice_print_models.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/services/operations/operation_manager.dart';
import 'package:phone_shop_pos/core/shortcuts/app_shortcut_manager.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/cart_item_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/customer_option_entity.dart';
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
import 'package:phone_shop_pos/modules/sales/presentation/widgets/imei_picker_dialog.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/payment_section_widget.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/product_search_bar.dart';
import 'package:phone_shop_pos/modules/sales/presentation/widgets/totals_panel_widget.dart';

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
  bool _isCompleting = false;
  int _selectedCartIndex = 0;
  int _handledShortcutToken = 0;
  Timer? _productSearchDebounce;

  @override
  void dispose() {
    _productSearchDebounce?.cancel();
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
    final normalizedCustomerId = billing.selectedCustomerId?.trim();
    final isWalkInCustomer = normalizedCustomerId == null ||
        normalizedCustomerId.isEmpty ||
        normalizedCustomerId.toLowerCase() == 'walk_in';
    final isCreditMode =
        billing.paymentMethod.trim().toLowerCase() == PaymentMethod.credit;
    if (isCreditMode && totals.remaining > 0 && isWalkInCustomer) {
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

  Future<void> _openPrintPreview(String jobId) async {
    final notifier = ref.read(invoicePrintQueueProvider.notifier);
    final job = notifier.findById(jobId);
    if (job == null || !mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => _InvoicePrintPreviewDialog(jobId: jobId, job: job),
    );
  }

  void _handleSuccessfulSale(SaleCompletionFlowOutcome flowOutcome) {
    final completion = flowOutcome.completionResult.asSuccess!.value;
    final enqueueResult = flowOutcome.enqueueResult;
    _productSearchController.clear();
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

    final billing = ref.watch(billingStateProvider);
    final productsAsync = ref.watch(productSearchResultsProvider);
    final customersAsync = ref.watch(customerSearchResultsProvider);
    final cartItems = ref.watch(cartStateProvider);
    final totals = ref.watch(totalsProvider);
    final products = productsAsync.value ?? const <ProductEntity>[];
    final normalizedCustomerId = billing.selectedCustomerId?.trim();
    final isWalkInCustomer = normalizedCustomerId == null ||
        normalizedCustomerId.isEmpty ||
        normalizedCustomerId.toLowerCase() == 'walk_in';
    final isCreditMode =
        billing.paymentMethod.trim().toLowerCase() == PaymentMethod.credit;
    final requiresRegisteredCustomerForCredit =
        isCreditMode && totals.remaining > 0 && isWalkInCustomer;

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
              padding: const EdgeInsets.all(10),
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
                    height: 156,
                    child: Card(
                      child: productsAsync.when(
                        data: (products) => LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount =
                                constraints.maxWidth >= 900 ? 2 : 1;
                            final mainAxisExtent =
                                constraints.maxWidth >= 1400 ? 220.0 : 240.0;
                            return GridView.builder(
                              padding: const EdgeInsets.all(8),
                              scrollDirection: Axis.horizontal,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                mainAxisExtent: mainAxisExtent,
                              ),
                              itemCount: products.length,
                              itemBuilder: (context, index) {
                                final product = products[index];
                                return OutlinedButton(
                                  onPressed: () => _handleAddProduct(product),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: <Widget>[
                                      Text(
                                        product.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        FormattingHelpers.currencyPkr(
                                          product.salePrice,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        product.hasImei
                                            ? 'Serialized • IMEI required'
                                            : 'Quantity product',
                                      ),
                                    ],
                                  ),
                                );
                              },
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
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final leftFlex = constraints.maxWidth >= 1480 ? 7 : 6;
                        final rightFlex = constraints.maxWidth >= 1480 ? 4 : 5;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              flex: leftFlex,
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
                                      ref
                                          .read(cartStateProvider.notifier)
                                          .updateQty(
                                            index: index,
                                            quantity: item.quantity + 1,
                                          );
                                    },
                                    onDecreaseQty: (index) {
                                      final item = cartItems[index];
                                      if (item.hasImei || item.quantity <= 1) {
                                        return;
                                      }
                                      ref
                                          .read(cartStateProvider.notifier)
                                          .updateQty(
                                            index: index,
                                            quantity: item.quantity - 1,
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
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: rightFlex,
                              child: Scrollbar(
                                thumbVisibility: true,
                                child: ListView(
                                  children: <Widget>[
                                    FocusTraversalOrder(
                                      order: const NumericFocusOrder(2),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          CustomerSelectorWidget(
                                            customers: customersAsync.value ??
                                                const <CustomerOptionEntity>[],
                                            selectedCustomerId:
                                                billing.selectedCustomerId,
                                            onChanged: (value) {
                                              ref
                                                  .read(
                                                    billingStateProvider
                                                        .notifier,
                                                  )
                                                  .setSelectedCustomerId(value);
                                            },
                                          ),
                                          if (requiresRegisteredCustomerForCredit)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 8),
                                              child: Text(
                                                'Registered customer is required for credit (udhar) sale.',
                                                style: TextStyle(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.error,
                                                ),
                                              ),
                                            ),
                                          if (customersAsync.isLoading) ...<Widget>[
                                            const SizedBox(height: 6),
                                            const LinearProgressIndicator(
                                              minHeight: 2,
                                            ),
                                          ],
                                          if (customersAsync.hasError) ...<Widget>[
                                            const SizedBox(height: 8),
                                            Text(
                                              customersAsync.error is AppError
                                                  ? (customersAsync.error
                                                          as AppError)
                                                      .message
                                                  : 'Failed to load customers.',
                                            ),
                                            const SizedBox(height: 8),
                                            OutlinedButton.icon(
                                              onPressed: _refreshSales,
                                              icon: const Icon(Icons.refresh),
                                              label: const Text('Retry'),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    FocusTraversalOrder(
                                      order: const NumericFocusOrder(3),
                                      child: TotalsPanelWidget(
                                        totals: totals,
                                        enteredPaidAmount: billing.paidAmount,
                                        onDiscountChanged: (value) {
                                          ref
                                              .read(
                                                billingStateProvider.notifier,
                                              )
                                              .setDiscount(value);
                                        },
                                        onTaxChanged: (value) {
                                          ref
                                              .read(
                                                billingStateProvider.notifier,
                                              )
                                              .setTax(value);
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    FocusTraversalOrder(
                                      order: const NumericFocusOrder(4),
                                      child: PaymentSectionWidget(
                                        paymentMethod: billing.paymentMethod,
                                        paidAmount: billing.paidAmount,
                                        notes: billing.notes,
                                        paymentMethodFocusNode:
                                            _paymentMethodFocus,
                                        paidAmountFocusNode: _paidAmountFocus,
                                        notesFocusNode: _notesFocus,
                                        onPaymentMethodChanged: (value) {
                                          ref
                                              .read(
                                                billingStateProvider.notifier,
                                              )
                                              .setPaymentMethod(value);
                                        },
                                        onPaidAmountChanged: (value) {
                                          ref
                                              .read(
                                                billingStateProvider.notifier,
                                              )
                                              .setPaidAmount(value);
                                        },
                                        onNotesChanged: (value) {
                                          ref
                                              .read(
                                                billingStateProvider.notifier,
                                              )
                                              .setNotes(value);
                                        },
                                        onPaidAmountSubmitted: _completeSale,
                                        onCompleteSale: _completeSale,
                                        isProcessing: _isCompleting,
                                        canCompleteSale:
                                            !requiresRegisteredCustomerForCredit,
                                        disabledReason:
                                            'Credit sale requires a registered customer.',
                                      ),
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

class _InvoicePrintPreviewDialog extends ConsumerStatefulWidget {
  const _InvoicePrintPreviewDialog({
    required this.jobId,
    required this.job,
  });

  final String jobId;
  final InvoicePrintJob job;

  @override
  ConsumerState<_InvoicePrintPreviewDialog> createState() =>
      _InvoicePrintPreviewDialogState();
}

class _InvoicePrintPreviewDialogState
    extends ConsumerState<_InvoicePrintPreviewDialog> {
  InvoicePaperSize _paperSize = InvoicePaperSize.thermal80;
  bool _isPrinting = false;

  @override
  Widget build(BuildContext context) {
    InvoicePrintJob? latestJob;
    for (final item in ref.watch(invoicePrintQueueProvider)) {
      if (item.id == widget.jobId) {
        latestJob = item;
        break;
      }
    }
    final job = latestJob ?? widget.job;
    final renderer = ref.watch(invoicePrintRendererProvider);
    final preview = renderer.render(
      document: job.document,
      paperSize: _paperSize,
    );

    return AlertDialog(
      title: Text('Invoice Preview - ${job.invoiceNumber}'),
      content: SizedBox(
        width: 820,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text('Layout'),
                const SizedBox(width: 8),
                DropdownButton<InvoicePaperSize>(
                  value: _paperSize,
                  onChanged: _isPrinting
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() => _paperSize = value);
                        },
                  items: InvoicePaperSize.values
                      .map(
                        (size) => DropdownMenuItem<InvoicePaperSize>(
                          value: size,
                          child: Text(size.label),
                        ),
                      )
                      .toList(growable: false),
                ),
                const Spacer(),
                if (job.lastError != null)
                  Tooltip(
                    message: job.lastError!,
                    child:
                        const Icon(Icons.warning_amber, color: Colors.orange),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    preview,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isPrinting ? null : () => Navigator.of(context).pop(),
          child: const Text('Print Later'),
        ),
        FilledButton.icon(
          onPressed: _isPrinting ? null : _printNow,
          icon: const Icon(Icons.print_outlined),
          label: Text(_isPrinting ? 'Printing...' : 'Print'),
        ),
      ],
    );
  }

  Future<void> _printNow() async {
    setState(() => _isPrinting = true);
    final result = await ref.read(invoicePrintQueueProvider.notifier).printJob(
          jobId: widget.jobId,
          paperSize: _paperSize,
        );
    if (!mounted) {
      return;
    }
    setState(() => _isPrinting = false);
    if (result.isSuccess) {
      AppNotifier.success(
        'Print job spooled: ${result.asSuccess!.value.path}',
      );
      Navigator.of(context).pop();
      return;
    }
    final error = result.asFailure!.error;
    AppNotifier.error(
      'Printing failed: ${error.message}',
      action: SnackBarAction(
        label: 'Retry',
        onPressed: _printNow,
      ),
    );
  }
}
