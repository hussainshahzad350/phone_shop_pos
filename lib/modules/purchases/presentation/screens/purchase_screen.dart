import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:phone_shop_pos/core/constants/payment_method.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/routing/current_route_provider.dart';
import 'package:phone_shop_pos/core/services/operations/operation_manager.dart';
import 'package:phone_shop_pos/core/shortcuts/app_shortcut_manager.dart';
import 'package:phone_shop_pos/core/theme/app_interaction_tokens.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/utils/notes_safety.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/purchases/domain/entities/purchase_form_item_entity.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_form_state_provider.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_query_providers.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_repository_provider.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/purchase_totals_provider.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/widgets/imei_entry_widget.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/widgets/purchase_items_table.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/widgets/supplier_selector_widget.dart';
import 'package:phone_shop_pos/modules/reports/presentation/dialogs/purchase_detail_dialog.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:phone_shop_pos/modules/inventory/presentation/providers/inventory_query_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/core/theme/app_typography.dart';

/// Below this width the fixed-width supplier/payment side panel starves the
/// items table, so the layout stacks: full-width table plus a summary bar
/// that opens the panel in a bottom sheet (tablet portrait / split screen).
const double _kPurchaseCompactLayoutWidth = 900.0;

class PurchaseScreen extends ConsumerStatefulWidget {
  const PurchaseScreen({super.key});

  @override
  ConsumerState<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends ConsumerState<PurchaseScreen> {
  final TextEditingController _productSearchController =
      TextEditingController();
  final FocusNode _productSearchFocus = FocusNode();
  final TextEditingController _invoiceController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _taxController = TextEditingController();
  final TextEditingController _paidController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final ScrollController _productGridScrollController = ScrollController();
  final ScrollController _rightPanelScrollController = ScrollController();
  bool _isSubmitting = false;
  bool _isUsedPurchase = false;
  bool _paidAmountTouched = false;
  bool _invoiceTouched = false;
  bool _invoicePreviewApplied = false;
  int _handledShortcutToken = 0;

  @override
  void dispose() {
    _productSearchController.dispose();
    _productSearchFocus.dispose();
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
        _notifyPurchaseError(result.asFailure!.error);
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
      _invoiceController.clear();
      _invoiceTouched = false;
      _invoicePreviewApplied = false;
      ref.invalidate(nextPurchaseInvoiceNumberProvider);
      _discountController.clear();
      _taxController.clear();
      _paidController.clear();
      _notesController.clear();
      _paidAmountTouched = false;
      final purchaseId = completion.purchaseId;
      AppNotifier.success(
        'Purchase saved — Invoice ${completion.invoiceNumber}',
        action: SnackBarAction(
          label: 'View Invoice',
          onPressed: () => _openPurchaseDetail(purchaseId),
        ),
      );
    } else {
      _notifyPurchaseError(result.asFailure!.error);
    }
  }

  bool _isPurchasesPath(String path) =>
      path == '/purchases' || path.startsWith('/purchases/');

  void _clearPaymentInputsOnLeave() {
    ref.read(purchaseFormStateProvider.notifier).clearPaymentInputs();
    _discountController.clear();
    _taxController.clear();
    _paidController.clear();
    _notesController.clear();
    _paidAmountTouched = false;
  }

  void _openPurchaseDetail(String purchaseId) {
    if (!mounted) {
      return;
    }
    showDialog<void>(
      context: context,
      builder: (context) => PurchaseDetailDialog(purchaseId: purchaseId),
    );
  }

  void _invalidateReportsAfterPurchase() {
    ref
        .read(reportWorkflowCoordinatorProvider)
        .refreshPurchaseAfterCompletion();
    ref.invalidate(inventorySummaryProvider);
    ref.invalidate(stockRowsProvider);
    ref.invalidate(lowStockProvider);
    refreshDashboardData(ref);
  }

  /// Business-rule validations the user can correct (empty cart, missing
  /// supplier for credit, payment shortfalls, IMEI issues). These surface as a
  /// warning (amber). Anything else on failure is treated as a hard error
  /// (red) — never as a green "success" snackbar.
  static const Set<String> _validationErrorCodes = <String>{
    'empty_items',
    'missing_imeis',
    'invalid_qty',
    'invalid_cost',
    'not_serialized',
    'serialized_qty_locked',
    'invalid_index',
    'invalid_imei_index',
    'duplicate_imei',
    'duplicate_imei_form',
    'duplicate_imei_pair',
    'imei_exists',
    'imei_existing_stock',
    'invalid_imei_format',
    'empty_imei',
    'invalid_purchase_notes',
    'full_payment_required',
    'credit_requires_supplier',
  };

  void _notifyPurchaseError(AppError error) {
    if (_validationErrorCodes.contains(error.code)) {
      AppNotifier.warning(error.message);
    } else {
      AppNotifier.error(error.message);
    }
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
    ref.listen<String>(currentRoutePathProvider, (previous, next) {
      final leftPurchases = previous != null &&
          _isPurchasesPath(previous) &&
          !_isPurchasesPath(next);
      if (leftPurchases) {
        _clearPaymentInputsOnLeave();
      }
    });

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
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: <Widget>[
                  // Product search + grid + invoice/New-Used. Scoped to the
                  // product results (and invoice preview) so it never rebuilds
                  // when the money fields change.
                  Consumer(
                    builder: (context, ref, _) {
                      final productsAsync =
                          ref.watch(purchaseProductSearchResultsProvider);
                      _syncInvoicePreview(ref);
                      return _buildProductSearch(productsAsync);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Items table. Scoped to the items list only, so
                        // typing discount/tax/paid does not rebuild it.
                        final itemsCard = Consumer(
                          builder: (context, ref, _) {
                            final items = ref.watch(
                              purchaseFormStateProvider
                                  .select((state) => state.items),
                            );
                            return _buildItemsCard(items);
                          },
                        );

                        if (constraints.maxWidth <
                            _kPurchaseCompactLayoutWidth) {
                          // Compact (tablet portrait / split screen): the
                          // fixed side panel would starve the items table,
                          // so supplier/totals/payment move to a bottom
                          // sheet behind a summary bar.
                          return Column(
                            children: <Widget>[
                              Expanded(child: itemsCard),
                              const SizedBox(height: AppSpacing.sm),
                              _CompactPurchaseBar(
                                onOpenCheckout: _openPurchaseCheckoutSheet,
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
                            Expanded(child: itemsCard),
                            const SizedBox(width: AppSpacing.sm),
                            // Right panel (supplier, totals, payment). Its
                            // static parts stay put; only the small total rows
                            // react to money keystrokes (see internal Consumers).
                            SizedBox(
                              width: rightPanelWidth,
                              child: _buildRightPanel(),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final errorMessage = ref.watch(
                        purchaseFormStateProvider
                            .select((state) => state.errorMessage),
                      );
                      if (errorMessage == null) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          errorMessage,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Shows the next systematic invoice number in the field as a preview while
  /// the user hasn't typed their own. The preview is display-only — the form
  /// state's invoiceNumber stays null so the repository generates the real
  /// (atomic) number at save time.
  void _syncInvoicePreview(WidgetRef ref) {
    if (_invoiceTouched || _invoicePreviewApplied) {
      return;
    }
    final preview = ref.watch(nextPurchaseInvoiceNumberProvider).valueOrNull;
    if (preview == null) {
      return;
    }
    _invoiceController.text = preview;
    _invoicePreviewApplied = true;
  }

  void _useSystematicInvoice() {
    final preview = ref.read(nextPurchaseInvoiceNumberProvider).valueOrNull;
    setState(() {
      _invoiceTouched = false;
      _invoicePreviewApplied = true;
    });
    _invoiceController.text = preview ?? '';
    ref.read(purchaseFormStateProvider.notifier).setInvoiceNumber(null);
  }

  Widget _buildInvoiceField() {
    return TextField(
      controller: _invoiceController,
      decoration: appDesktopInputDecoration(
        labelText: 'Invoice Number',
        hintText: 'Auto-generated if left empty',
        suffixIcon: _invoiceTouched
            ? IconButton(
                tooltip: 'Use systematic number',
                icon: const Icon(Icons.auto_mode),
                onPressed: _useSystematicInvoice,
              )
            : null,
      ),
      onChanged: (v) {
        final trimmed = v.trim();
        final touched = trimmed.isNotEmpty;
        // Only rebuild on the empty↔filled transition (toggles the suffix
        // button); typing within a non-empty value must not rebuild the screen.
        if (touched != _invoiceTouched) {
          setState(() => _invoiceTouched = touched);
        }
        ref
            .read(purchaseFormStateProvider.notifier)
            .setInvoiceNumber(trimmed.isEmpty ? null : v);
      },
    );
  }

  Widget _buildNewUsedToggle() {
    return SegmentedButton<bool>(
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
    );
  }

  Widget _buildItemsCard(List<PurchaseFormItem> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: PurchaseItemsTable(
          items: items,
          onRemoveItem: (index) {
            ref.read(purchaseFormStateProvider.notifier).removeItem(index);
          },
          onUpdateQuantity: (index, qty) {
            ref
                .read(purchaseFormStateProvider.notifier)
                .updateQuantity(index: index, quantity: qty);
          },
          onUpdateUnitCost: (index, cost) {
            ref
                .read(purchaseFormStateProvider.notifier)
                .updateUnitCost(index: index, cost: cost);
          },
          onUpdateImeiEntry: (itemIdx, imeiIdx, entry) async {
            final result = await ref
                .read(purchaseFormStateProvider.notifier)
                .updateImeiEntry(
                  itemIndex: itemIdx,
                  imeiIndex: imeiIdx,
                  entry: entry,
                );
            if (result.isFailure) {
              _notifyPurchaseError(result.asFailure!.error);
            }
          },
          onAddImeiEntries: _handleAddImeiEntries,
          onRemoveImeiEntry: (itemIdx, imeiIdx) {
            ref
                .read(purchaseFormStateProvider.notifier)
                .removeImeiEntry(itemIndex: itemIdx, imeiIndex: imeiIdx);
          },
        ),
      ),
    );
  }

  Widget _buildProductSearch(
    AsyncValue<List<ProductEntity>> productsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            // Left half: product search.
            Expanded(
              child: AppSearchField(
                controller: _productSearchController,
                focusNode: _productSearchFocus,
                hintText: 'Search product / SKU / brand',
                onChanged: (value) {
                  ref
                      .read(purchaseFormStateProvider.notifier)
                      .setProductSearchQuery(value);
                },
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // Right half: invoice number + New/Used toggle.
            Expanded(
              child: Row(
                children: <Widget>[
                  Expanded(child: _buildInvoiceField()),
                  const SizedBox(width: AppSpacing.md),
                  _buildNewUsedToggle(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          // Desktop keeps the compact 118px bar; touch mode grows it so the
          // primary purchase-entry targets gain height.
          height: AppInteractionTokens.of(context).productBarHeight,
          child: Card(
            child: productsAsync.when(
              // Keep showing the current results while a new search loads, so
              // the grid doesn't flash to a spinner on every keystroke.
              skipLoadingOnReload: true,
              data: (products) {
                if (products.isEmpty) {
                  return const Center(child: Text('No products found'));
                }
                // Limit the quick bar; full list lives on the Inventory screen.
                final shown = products.length > 12
                    ? products.sublist(0, 12)
                    : products;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final mainAxisExtent =
                        constraints.maxWidth >= 1400 ? 168.0 : 180.0;
                    final scrollStep = constraints.maxWidth * 0.75;
                    return Stack(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 34),
                          child: GridView.builder(
                            controller: _productGridScrollController,
                            padding: const EdgeInsets.all(AppSpacing.xs),
                            scrollDirection: Axis.horizontal,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 1,
                              crossAxisSpacing: 6,
                              mainAxisSpacing: 6,
                              mainAxisExtent: mainAxisExtent,
                            ),
                            // +1 for the trailing "View all in Inventory" cell.
                            itemCount: shown.length + 1,
                            itemBuilder: (context, index) {
                              if (index == shown.length) {
                                return _ViewAllInInventoryButton(
                                  onPressed: () => context.go('/inventory'),
                                );
                              }
                              final product = shown[index];
                              final tokens =
                                  AppInteractionTokens.of(context);
                              final bump = tokens.quickBarFontBump;
                              return OutlinedButton(
                                onPressed: () => _handleAddProduct(product),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: AppSpacing.xs,
                                  ),
                                  minimumSize: tokens.minButtonSize,
                                  tapTargetSize: tokens.tapTargetSize,
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
                                      style: TextStyle(fontSize: 12 + bump),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Cost: ${FormattingHelpers.currencyPkr(product.purchasePrice)}',
                                      style: TextStyle(fontSize: 11 + bump),
                                    ),
                                    Text(
                                      product.hasImei
                                          ? 'Serialized • IMEI'
                                          : 'Qty-based',
                                      style: TextStyle(fontSize: 10 + bump),
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

  Widget _buildRightPanel() {
    return Scrollbar(
      controller: _rightPanelScrollController,
      thumbVisibility: true,
      child: ListView(
        controller: _rightPanelScrollController,
        children: _buildRightPanelChildren(),
      ),
    );
  }

  Future<void> _openPurchaseCheckoutSheet() async {
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _buildRightPanelChildren(
                  onSave: () {
                    Navigator.of(sheetContext).pop();
                    _savePurchase();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Supplier, totals, payment and save column shared by the wide side panel
  /// and the compact bottom sheet. [onSave] overrides the save action (the
  /// sheet closes itself first so the progress overlay is visible).
  List<Widget> _buildRightPanelChildren({VoidCallback? onSave}) {
    return <Widget>[
          // Supplier — rebuilds only when the selected supplier changes.
          Consumer(
            builder: (context, ref, _) {
              final selectedSupplierId = ref.watch(
                purchaseFormStateProvider
                    .select((state) => state.selectedSupplierId),
              );
              return SupplierSelectorWidget(
                selectedSupplierId: selectedSupplierId,
                onChanged: (supplierId) {
                  ref
                      .read(purchaseFormStateProvider.notifier)
                      .setSupplier(supplierId);
                },
              );
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Totals',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Each total row watches only its own value, so a keystroke
                  // repaints a single line instead of the whole panel.
                  Consumer(
                    builder: (context, ref, _) {
                      final subtotal = ref.watch(
                        purchaseTotalsProvider.select((t) => t.subtotal),
                      );
                      return _TotalRow(label: 'Subtotal', value: subtotal);
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildDiscountField(),
                  const SizedBox(height: AppSpacing.sm),
                  _buildTaxField(),
                  const SizedBox(height: AppSpacing.sm),
                  Consumer(
                    builder: (context, ref, _) {
                      final total = ref.watch(
                        purchaseTotalsProvider.select((t) => t.total),
                      );
                      return _TotalRow(
                        label: 'Total',
                        value: total,
                        bold: true,
                      );
                    },
                  ),
                  const Divider(),
                  const Text(
                    'Payment Method',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Consumer(
                    builder: (context, ref, _) {
                      final paymentMethod = ref.watch(
                        purchaseFormStateProvider
                            .select((state) => state.paymentMethod),
                      );
                      return DropdownButtonFormField<String>(
                        initialValue: paymentMethod,
                        borderRadius: kAppDropdownMenuRadius,
                        menuMaxHeight: kAppDropdownMenuMaxHeight,
                        items: PaymentMethod.values
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child:
                                    Text(PaymentMethod.labels[value] ?? value),
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
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildPaidField(),
                  const SizedBox(height: AppSpacing.sm),
                  Consumer(
                    builder: (context, ref, _) {
                      final total = ref.watch(
                        purchaseTotalsProvider.select((t) => t.total),
                      );
                      final paidAmount = ref.watch(
                        purchaseFormStateProvider
                            .select((state) => state.paidAmount),
                      );
                      // An untouched Paid field means "pay in full".
                      final effectivePaid =
                          _paidAmountTouched ? paidAmount : total;
                      return _TotalRow(
                        label: 'Balance Due',
                        value: total - effectivePaid,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
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
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: _isSubmitting ? null : (onSave ?? _savePurchase),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            // The F10 hint documents a physical-keyboard shortcut; hide it
            // when the operator has switched to touch mode.
            label: Text(
              AppInteractionTokens.of(context).isTouch
                  ? 'Save Purchase'
                  : 'Save Purchase (F10)',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ];
  }

  Widget _buildDiscountField() {
    return TextField(
      controller: _discountController,
      decoration: appDesktopInputDecoration(
        labelText: 'Discount',
        hintText: '0.00',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) {
        final val = FormattingHelpers.parseLocaleDecimal(v);
        ref.read(purchaseFormStateProvider.notifier).setDiscount(val);
      },
    );
  }

  Widget _buildTaxField() {
    return TextField(
      controller: _taxController,
      decoration: appDesktopInputDecoration(
        labelText: 'Tax',
        hintText: '0.00',
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) {
        final val = FormattingHelpers.parseLocaleDecimal(v);
        ref.read(purchaseFormStateProvider.notifier).setTax(val);
      },
    );
  }

  Widget _buildPaidField() {
    return Consumer(
      builder: (context, ref, _) {
        // Only the placeholder depends on the live total; typing in this field
        // does not change the total, so the field is not rebuilt per keystroke.
        final total =
            ref.watch(purchaseTotalsProvider.select((t) => t.total));
        return TextField(
          controller: _paidController,
          decoration: appDesktopInputDecoration(
            labelText: 'Paid Amount',
            hintText: FormattingHelpers.decimal(total),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) {
            // No setState here: the Balance Due row watches paidAmount and
            // re-reads _paidAmountTouched on its own, so a keystroke repaints
            // only that one row.
            _paidAmountTouched = true;
            final val = FormattingHelpers.parseLocaleDecimal(v);
            ref.read(purchaseFormStateProvider.notifier).setPaidAmount(val);
          },
        );
      },
    );
  }
}

class _ViewAllInInventoryButton extends StatelessWidget {
  const _ViewAllInInventoryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.inventory_2_outlined,
              size: 22, color: theme.colorScheme.primary),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'View all\nin Inventory',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
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
        ? const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
            fontFeatures: AppTypography.tabularFigures,
          )
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

class _SavePurchaseIntent extends Intent {
  const _SavePurchaseIntent();
}

/// Compact-layout summary strip under the items table: shows the running
/// purchase total and opens the supplier/payment bottom sheet.
class _CompactPurchaseBar extends StatelessWidget {
  const _CompactPurchaseBar({required this.onOpenCheckout});

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
              child: Consumer(
                builder: (context, ref, _) {
                  final total = ref.watch(
                    purchaseTotalsProvider.select((t) => t.total),
                  );
                  return Text(
                    'Total: ${FormattingHelpers.currencyPkr(total)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.icon(
              onPressed: onOpenCheckout,
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Supplier & Payment'),
            ),
          ],
        ),
      ),
    );
  }
}
