import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/services/operations/operation_manager.dart';
import 'package:phone_shop_pos/core/shortcuts/app_shortcut_manager.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/utils/notes_safety.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/supplier_option_entity.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_form_state_provider.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_query_providers.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_repository_provider.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_totals_provider.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/widgets/imei_entry_widget.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/widgets/purchase_items_table.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/inventory_query_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';

class PurchaseScreen extends ConsumerStatefulWidget {
  const PurchaseScreen({super.key});

  @override
  ConsumerState<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends ConsumerState<PurchaseScreen> {
  final TextEditingController _productSearchController =
      TextEditingController();
  final FocusNode _productSearchFocus = FocusNode();
  final TextEditingController _supplierSearchController =
      TextEditingController();
  final TextEditingController _invoiceController = TextEditingController();
  final TextEditingController _discountController =
      TextEditingController(text: '0');
  final TextEditingController _taxController = TextEditingController(text: '0');
  final TextEditingController _paidController =
      TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();
  final ScrollController _productGridScrollController = ScrollController();
  final ScrollController _rightPanelScrollController = ScrollController();
  bool _isSubmitting = false;
  bool _isUsedPurchase = false;
  bool _paidAmountTouched = false;
  bool _paidAmountFieldTapped = false;
  int _handledShortcutToken = 0;

  @override
  void dispose() {
    _productSearchController.dispose();
    _productSearchFocus.dispose();
    _supplierSearchController.dispose();
    _invoiceController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    _paidController.dispose();
    _notesController.dispose();
    _productGridScrollController.dispose();
    _rightPanelScrollController.dispose();
    super.dispose();
  }

  Future<void> _scrollProductGrid(double delta) async {
    if (!_productGridScrollController.hasClients) {
      return;
    }

    final position = _productGridScrollController.position;
    final target = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    await _productGridScrollController.animateTo(
      target.toDouble(),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _handleAddProduct(ProductEntity product) async {
    await ref.read(purchaseFormStateProvider.notifier).addProduct(product);
  }

  Future<void> _handleAddImeiEntries(int itemIndex) async {
    final item = ref.read(purchaseFormStateProvider).items[itemIndex];
    final entries = await showDialog<List<ImeiEntry>>(
      context: context,
      useRootNavigator: true,
      builder: (context) => ImeiEntryWidget(
        defaultCostPrice: item.unitCost,
        isUsed: _isUsedPurchase,
      ),
    );

    if (entries == null || entries.isEmpty || !mounted) {
      return;
    }

    for (final entry in entries) {
      final result =
          await ref.read(purchaseFormStateProvider.notifier).addImeiEntry(
                index: itemIndex,
                entry: entry,
              );
      if (result.isFailure) {
        _showSnack(result.asFailure!.error.message);
        break;
      }
    }
  }

  Future<void> _savePurchase() async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final formState = ref.read(purchaseFormStateProvider);
    final service = await ref.read(purchaseServiceProvider.future);
    final totals = ref.read(purchaseTotalsProvider);
    final effectivePaidAmount =
        _paidAmountTouched ? formState.paidAmount : totals.total;

    final result = await ref.read(operationManagerProvider.notifier).track(
          code: 'save_purchase',
          label: 'Saving purchase',
          progressLabel: 'Saving purchase and updating stock',
          action: (_) => service.completePurchase(
            items: formState.items,
            discount: formState.discount,
            tax: formState.tax,
            paidAmount: effectivePaidAmount,
            paymentMethod: formState.paymentMethod,
            supplierId: formState.selectedSupplierId,
            invoiceNumber: formState.invoiceNumber,
            notes: formState.notes,
          ),
        );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (result.isSuccess) {
      final completion = result.asSuccess!.value;
      _invalidateReportsAfterPurchase();
      ref.read(purchaseFormStateProvider.notifier).resetForm();
      _productSearchController.clear();
      _supplierSearchController.clear();
      _invoiceController.clear();
      _discountController.text = '0';
      _taxController.text = '0';
      _paidController.text = '0';
      _notesController.clear();
      _paidAmountTouched = false;
      _paidAmountFieldTapped = false;
      _showSnack(
        'Purchase saved. '
        '${completion.serializedItemCount} IMEI(s), '
        '${completion.quantityItemCount} qty line(s). '
        'Total: ${FormattingHelpers.currencyPkr(completion.total)}',
      );
    } else {
      _showSnack(result.asFailure!.error.message);
    }
  }

  void _invalidateReportsAfterPurchase() {
    ref.read(reportWorkflowCoordinatorProvider).refreshPurchaseAfterCompletion();
    ref.invalidate(inventorySummaryProvider);
    ref.invalidate(stockRowsProvider);
    ref.invalidate(lowStockProvider);
    ref.invalidate(dashboardKpisProvider);
    ref.invalidate(dashboardLowStockProvider);
  }

  void _showSnack(String message) {
    final lowered = message.toLowerCase();
    if (lowered.contains('duplicate imei')) {
      AppNotifier.warning(message);
      return;
    }
    if (lowered.contains('failed') || lowered.contains('error')) {
      AppNotifier.error(message);
      return;
    }
    AppNotifier.success(message);
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
      case AppShortcutEvent.saveOrComplete:
        _savePurchase();
        break;
      case AppShortcutEvent.focusPayment:
      case AppShortcutEvent.refreshCurrentScreen:
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppShortcutEventState>(appShortcutEventBusProvider,
        (previous, next) {
      _handleGlobalShortcut(next);
    });

    final formState = ref.watch(purchaseFormStateProvider);
    final productsAsync = ref.watch(purchaseProductSearchResultsProvider);
    final suppliersAsync = ref.watch(supplierSearchResultsProvider);
    final totals = ref.watch(purchaseTotalsProvider);
    _syncDefaultPaidAmount(formState, totals.total);

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.f10): _SavePurchaseIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SavePurchaseIntent: CallbackAction<_SavePurchaseIntent>(
            onInvoke: (intent) {
              _savePurchase();
              return null;
            },
          ),
        },
        child: Scaffold(
          body: AppLoadingOverlay(
            isLoading: _isSubmitting,
            label: 'Saving purchase...',
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: <Widget>[
                  _buildTopBar(formState, suppliersAsync),
                  const SizedBox(height: 8),
                  _buildProductSearch(formState, productsAsync),
                  const SizedBox(height: 8),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final rightPanelWidth = constraints.maxWidth >= 1500
                            ? 360.0
                            : constraints.maxWidth >= 1200
                                ? 320.0
                                : 300.0;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: PurchaseItemsTable(
                                    items: formState.items,
                                    onRemoveItem: (index) {
                                      ref
                                          .read(
                                            purchaseFormStateProvider.notifier,
                                          )
                                          .removeItem(index);
                                    },
                                    onUpdateQuantity: (index, qty) {
                                      ref
                                          .read(
                                            purchaseFormStateProvider.notifier,
                                          )
                                          .updateQuantity(
                                            index: index,
                                            quantity: qty,
                                          );
                                    },
                                    onUpdateUnitCost: (index, cost) {
                                      ref
                                          .read(
                                            purchaseFormStateProvider.notifier,
                                          )
                                          .updateUnitCost(
                                            index: index,
                                            cost: cost,
                                          );
                                    },
                                    onUpdateImeiEntry:
                                        (itemIdx, imeiIdx, entry) async {
                                      final result = await ref
                                          .read(
                                            purchaseFormStateProvider.notifier,
                                          )
                                          .updateImeiEntry(
                                            itemIndex: itemIdx,
                                            imeiIndex: imeiIdx,
                                            entry: entry,
                                          );
                                      if (result.isFailure) {
                                        _showSnack(
                                          result.asFailure!.error.message,
                                        );
                                      }
                                    },
                                    onAddImeiEntries: _handleAddImeiEntries,
                                    onRemoveImeiEntry: (itemIdx, imeiIdx) {
                                      ref
                                          .read(
                                            purchaseFormStateProvider.notifier,
                                          )
                                          .removeImeiEntry(
                                            itemIndex: itemIdx,
                                            imeiIndex: imeiIdx,
                                          );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: rightPanelWidth,
                              child: _buildRightPanel(formState, totals),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (formState.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        formState.errorMessage!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
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

  void _syncDefaultPaidAmount(PurchaseFormState formState, double total) {
    if (_paidAmountTouched || _paidAmountFieldTapped || formState.items.isEmpty) {
      return;
    }
    final text = FormattingHelpers.decimal(total);
    if (_paidController.text == text && formState.paidAmount == total) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _paidAmountTouched || _paidAmountFieldTapped) {
        return;
      }
      _paidController.text = text;
      ref.read(purchaseFormStateProvider.notifier).setPaidAmount(total);
    });
  }

  Widget _buildTopBar(
    PurchaseFormState formState,
    AsyncValue<List<SupplierOptionEntity>> suppliersAsync,
  ) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _SupplierSearchDropdown(
            searchController: _supplierSearchController,
            suppliers: suppliersAsync.value ?? const <SupplierOptionEntity>[],
            selectedSupplierId: formState.selectedSupplierId,
            onSearchChanged: (value) {
              ref
                  .read(purchaseFormStateProvider.notifier)
                  .setSupplierSearchQuery(value);
            },
            onSelected: (supplierId) {
              ref
                  .read(purchaseFormStateProvider.notifier)
                  .setSupplier(supplierId);
            },
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 220,
          child: TextField(
            controller: _invoiceController,
            decoration: appDesktopInputDecoration(
                labelText: 'Invoice Number (optional)'),
            onChanged: (v) {
              ref
                  .read(purchaseFormStateProvider.notifier)
                  .setInvoiceNumber(v.isEmpty ? null : v);
            },
          ),
        ),
        const SizedBox(width: 12),
        SegmentedButton<bool>(
          segments: const <ButtonSegment<bool>>[
            ButtonSegment<bool>(
              value: false,
              label: Text('New'),
              icon: Icon(Icons.fiber_new),
            ),
            ButtonSegment<bool>(
              value: true,
              label: Text('Used'),
              icon: Icon(Icons.recycling),
            ),
          ],
          selected: <bool>{_isUsedPurchase},
          onSelectionChanged: (Set<bool> selection) {
            setState(() => _isUsedPurchase = selection.first);
          },
        ),
      ],
    );
  }

  Widget _buildProductSearch(
    PurchaseFormState formState,
    AsyncValue<List<ProductEntity>> productsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: _productSearchController,
          focusNode: _productSearchFocus,
          decoration: appDesktopInputDecoration(
            labelText: 'Search products to add',
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: (value) {
            ref
                .read(purchaseFormStateProvider.notifier)
                .setProductSearchQuery(value);
          },
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 156,
          child: Card(
            child: productsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return const Center(child: Text('No products found'));
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final crossAxisCount = 1;
                    final mainAxisExtent =
                        constraints.maxWidth >= 1400 ? 220.0 : 240.0;
                    final scrollStep = constraints.maxWidth * 0.75;
                    return Stack(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 34),
                          child: GridView.builder(
                            controller: _productGridScrollController,
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
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.all(10),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  alignment: Alignment.centerLeft,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: <Widget>[
                                    Text(
                                      product.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Cost: ${FormattingHelpers.currencyPkr(product.purchasePrice)}',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    Text(
                                      product.hasImei
                                          ? 'Serialized • IMEI'
                                          : 'Qty-based',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _GridNavArrowButton(
                            icon: Icons.chevron_left,
                            onPressed: () => _scrollProductGrid(-scrollStep),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _GridNavArrowButton(
                            icon: Icons.chevron_right,
                            onPressed: () => _scrollProductGrid(scrollStep),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              error: (_, __) =>
                  const Center(child: Text('Failed to load products')),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanel(
    PurchaseFormState formState,
    ({double subtotal, double total}) totals,
  ) {
    return Scrollbar(
      controller: _rightPanelScrollController,
      thumbVisibility: true,
      child: ListView(
        controller: _rightPanelScrollController,
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Totals',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  _TotalRow(
                    label: 'Subtotal',
                    value: totals.subtotal,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _discountController,
                    decoration:
                        appDesktopInputDecoration(labelText: 'Discount'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      _paidAmountTouched = true;
                      final val = FormattingHelpers.parseLocaleDecimal(v);
                      ref
                          .read(purchaseFormStateProvider.notifier)
                          .setDiscount(val);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _taxController,
                    decoration: appDesktopInputDecoration(labelText: 'Tax'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) {
                      final val = FormattingHelpers.parseLocaleDecimal(v);
                      ref.read(purchaseFormStateProvider.notifier).setTax(val);
                    },
                  ),
                  const SizedBox(height: 8),
                  _TotalRow(
                    label: 'Total',
                    value: totals.total,
                    bold: true,
                  ),
                  const Divider(),
                  const Text(
                    'Payment Method',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: formState.paymentMethod,
                    items: PaymentMethod.values
                        .map(
                          (value) => DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                                PaymentMethod.labels[value] ?? value),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value != null) {
                        ref
                            .read(purchaseFormStateProvider.notifier)
                            .setPaymentMethod(value);
                      }
                    },
                    decoration: appDesktopInputDecoration(),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _paidController,
                    decoration:
                        appDesktopInputDecoration(labelText: 'Paid Amount'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onTap: () {
                      _paidAmountFieldTapped = true;
                      _paidAmountTouched = true;
                    },
                    onChanged: (v) {
                      _paidAmountTouched = true;
                      final val = FormattingHelpers.parseLocaleDecimal(v);
                      ref
                          .read(purchaseFormStateProvider.notifier)
                          .setPaidAmount(val);
                    },
                  ),
                  const SizedBox(height: 8),
                  _TotalRow(
                    label: 'Balance Due',
                    value: totals.total - formState.paidAmount,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _notesController,
                maxLines: 3,
                maxLength: NotesSafety.maxLength,
                decoration: appDesktopInputDecoration(
                  labelText: 'Notes (optional)',
                ),
                onChanged: (v) {
                  ref
                      .read(purchaseFormStateProvider.notifier)
                      .setNotes(v.isEmpty ? null : v);
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : _savePurchase,
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: const Text('Save Purchase (F10)'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridNavArrowButton extends StatelessWidget {
  const _GridNavArrowButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
      elevation: 1,
      shape: const CircleBorder(),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        icon: Icon(icon),
        onPressed: onPressed,
        tooltip:
            icon == Icons.chevron_left ? 'Previous products' : 'Next products',
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final double value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)
        : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label, style: style),
        Text(FormattingHelpers.currencyPkr(value), style: style),
      ],
    );
  }
}

class _SupplierSearchDropdown extends StatefulWidget {
  const _SupplierSearchDropdown({
    required this.searchController,
    required this.suppliers,
    required this.onSearchChanged,
    required this.onSelected,
    this.selectedSupplierId,
  });

  final TextEditingController searchController;
  final List<SupplierOptionEntity> suppliers;
  final String? selectedSupplierId;
  final void Function(String value) onSearchChanged;
  final void Function(String? supplierId) onSelected;

  @override
  State<_SupplierSearchDropdown> createState() =>
      _SupplierSearchDropdownState();
}

class _SupplierSearchDropdownState extends State<_SupplierSearchDropdown> {
  OverlayEntry? _overlay;
  final LayerLink _layerLink = LayerLink();

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  void _showOverlay() {
    _removeOverlay();

    if (widget.suppliers.isEmpty) {
      return;
    }

    _overlay = OverlayEntry(
      builder: (context) => Positioned(
        width: 320,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 44),
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.suppliers.length,
                itemBuilder: (context, index) {
                  final supplier = widget.suppliers[index];
                  return ListTile(
                    dense: true,
                    title: Text(supplier.name),
                    subtitle:
                        supplier.phone != null ? Text(supplier.phone!) : null,
                    onTap: () {
                      widget.searchController.text = supplier.name;
                      widget.onSelected(supplier.id);
                      _removeOverlay();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    SupplierOptionEntity? selected;
    if (widget.selectedSupplierId != null) {
      for (final s in widget.suppliers) {
        if (s.id == widget.selectedSupplierId) {
          selected = s;
          break;
        }
      }
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: widget.searchController,
              decoration: appDesktopInputDecoration(
                labelText: selected != null
                    ? 'Supplier: ${selected.name}'
                    : 'Search supplier (optional)',
                suffixIcon: widget.selectedSupplierId != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          widget.searchController.clear();
                          widget.onSelected(null);
                          widget.onSearchChanged('');
                        },
                      )
                    : null,
              ),
              onChanged: (v) {
                widget.onSearchChanged(v);
                if (v.isNotEmpty) {
                  _showOverlay();
                } else {
                  _removeOverlay();
                }
              },
              onTap: () {
                if (widget.searchController.text.isNotEmpty) {
                  _showOverlay();
                }
              },
              onEditingComplete: _removeOverlay,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavePurchaseIntent extends Intent {
  const _SavePurchaseIntent();
}
