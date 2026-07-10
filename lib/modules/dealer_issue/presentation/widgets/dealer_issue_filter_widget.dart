import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/providers/dealer_issue_state_provider.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/providers/dealer_providers.dart';
import 'package:phone_shop_pos/modules/dealer_issue/presentation/widgets/add_dealer_dialog.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/core/widgets/app_searchable_dropdown_field.dart';

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
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            Text(
              'Filter by Dealer:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: dealersAsync.when(
                data: (dealers) => AppSearchableDropdownField(
                  value: selectedDealerId,
                  hintText: 'Search dealer',
                  noneLabel: 'All Dealers',
                  options: dealers
                      .map((d) => AppSelectOption(id: d.id, label: d.name))
                      .toList(growable: false),
                  onChanged: onDealerSelected,
                ),
                loading: () => const SizedBox(
                  height: 48,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => const Text('Failed to load dealers'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
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
                    const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpacing.sm),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
