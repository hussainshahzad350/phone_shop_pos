import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/providers/dealer_issue_state_provider.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/providers/dealer_providers.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/widgets/add_dealer_dialog.dart';

class DealerIssueFilterWidget extends ConsumerWidget {
  const DealerIssueFilterWidget({
    super.key,
    required this.onDealerSelected,
  });

  final ValueChanged<String?> onDealerSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDealerId = ref.watch(dealerIssueStateProvider).selectedDealerId;
    final dealersAsync = ref.watch(dealerListProvider);

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
              child: dealersAsync.when(
                data: (dealers) => DropdownButtonFormField<String?>(
                  initialValue: selectedDealerId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Dealers'),
                    ),
                    ...dealers.map((d) => DropdownMenuItem<String?>(
                          value: d.id,
                          child: Text(d.name),
                        )),
                  ],
                  onChanged: onDealerSelected,
                ),
                loading: () => const SizedBox(
                  height: 48,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const Text('Failed to load dealers'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final created = await AddDealerDialog.show(context);
                if (created != null) {
                  ref.invalidate(dealerListProvider);
                }
              },
              icon: const Icon(Icons.person_add_outlined, size: 16),
              label: const Text('Add Dealer'),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
