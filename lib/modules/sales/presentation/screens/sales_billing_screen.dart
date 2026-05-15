import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/errors/result.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/product_entity.dart';
import 'package:phone_shop_pos/modules/inventory/domain/entities/serialized_stock_entity.dart';
import 'package:phone_shop_pos/modules/sales/domain/entities/customer_option_entity.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/billing_state_provider.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/cart_state_provider.dart';
import 'package:phone_shop_pos/modules/sales/presentation/providers/sales_query_providers.dart';
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
  bool _isCompleting = false;

  @override
  void dispose() {
    _productSearchController.dispose();
    super.dispose();
  }

  Future<void> _handleAddProduct(ProductEntity product) async {
    if (!product.hasImei) {
      final result = await ref.read(cartStateProvider.notifier).addToCart(
        product: product,
        quantity: 1,
      );
      _showResultError(result);
      return;
    }

    final imeis = await ref.read(availableImeisProvider(product.id).future);
    if (!mounted) {
      return;
    }

    if (imeis.isEmpty) {
      _showSnack('No in-stock IMEI available.');
      return;
    }

    SerializedStockEntity? selected;
    if (imeis.length == 1) {
      selected = imeis.first;
    } else {
      selected = await showDialog<SerializedStockEntity>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Select IMEI - ${product.name}'),
          content: SizedBox(
            width: 420,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: imeis.length,
              itemBuilder: (context, index) {
                final stock = imeis[index];
                return ListTile(
                  title: Text(stock.imei1),
                  subtitle: stock.imei2 == null ? null : Text(stock.imei2!),
                  onTap: () => Navigator.of(context).pop(stock),
                );
              },
            ),
          ),
        ),
      );
    }

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
  }

  void _showResultError(Result<void> result) {
    if (result.isFailure) {
      _showSnack(result.asFailure!.error.message);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _completeSale() async {
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
      _showSnack('Sale completed. Invoice: ${result.asSuccess!.value.invoiceNumber}');
      return;
    }

    _showSnack(result.asFailure!.error.message);
  }

  @override
  Widget build(BuildContext context) {
    final billing = ref.watch(billingStateProvider);
    final productsAsync = ref.watch(productSearchResultsProvider);
    final customersAsync = ref.watch(customerSearchResultsProvider);
    final cartItems = ref.watch(cartStateProvider);
    final totals = ref.watch(totalsProvider);

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.f9): const _CompleteSaleIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _CompleteSaleIntent: CallbackAction<_CompleteSaleIntent>(
            onInvoke: (intent) {
              _completeSale();
              return null;
            },
          ),
        },
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: <Widget>[
                ProductSearchBar(
                  controller: _productSearchController,
                  onChanged: (value) {
                    ref.read(billingStateProvider.notifier).setProductSearchQuery(
                      value,
                    );
                  },
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
                      error: (error, stack) => const Center(
                        child: Text('Failed to load products'),
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
                            CustomerSelectorWidget(
                              customers:
                                  customersAsync.value ?? const <CustomerOptionEntity>[],
                              selectedCustomerId: billing.selectedCustomerId,
                              onChanged: (value) {
                                ref
                                    .read(billingStateProvider.notifier)
                                    .setSelectedCustomerId(value);
                              },
                              onSearchChanged: (value) {
                                ref
                                    .read(billingStateProvider.notifier)
                                    .setCustomerSearchQuery(value);
                              },
                            ),
                            const SizedBox(height: 8),
                            TotalsPanelWidget(
                              totals: totals,
                              onDiscountChanged: (value) {
                                ref.read(billingStateProvider.notifier).setDiscount(
                                  value,
                                );
                              },
                              onTaxChanged: (value) {
                                ref.read(billingStateProvider.notifier).setTax(value);
                              },
                            ),
                            const SizedBox(height: 8),
                            PaymentSectionWidget(
                              paymentMethod: billing.paymentMethod,
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
                              onCompleteSale: _completeSale,
                              isProcessing: _isCompleting,
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
    );
  }
}

class _CompleteSaleIntent extends Intent {
  const _CompleteSaleIntent();
}
