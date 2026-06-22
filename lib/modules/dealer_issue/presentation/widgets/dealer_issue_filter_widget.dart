import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/providers/dealer_issue_state_provider.dart';
import 'package:phone_shop_pos/modules/purchases/presentation/providers/supplier_providers.dart';

class DealerIssueFilterWidget extends ConsumerWidget {
  const DealerIssueFilterWidget({
    super.key,
    required this.onDealerSelected,
  });

  final ValueChanged<String?> onDealerSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDealerId = ref.watch(dealerIssueStateProvider).selectedDealerId;
    final suppliersAsync = ref.watch(supplierListProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            const Text(
              'Filter by Dealer:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: suppliersAsync.when(
                data: (dealers) {
                  if (dealers.isEmpty) {
                    return const Text('No dealers available');
                  }

                  return DropdownButtonFormField<String?>(
                    initialValue: selectedDealerId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All Dealers'),
                      ),
                      ...dealers.map((dealer) {
                        return DropdownMenuItem<String?>(
                          value: dealer.id,
                          child: Text(dealer.name),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      onDealerSelected(value);
                    },
                  );
                },
                loading: () => const SizedBox(
                  height: 48,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const Text('Failed to load dealers'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
