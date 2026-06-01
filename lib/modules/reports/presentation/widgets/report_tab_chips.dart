import 'package:flutter/material.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';

class ReportTabChips extends StatelessWidget {
  const ReportTabChips({
    super.key,
    required this.selectedTab,
    required this.labelFor,
    required this.onSelectTab,
  });

  final ReportsTab selectedTab;
  final String Function(ReportsTab tab) labelFor;
  final ValueChanged<ReportsTab> onSelectTab;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ReportsTab.values
              .map(
                (item) => ChoiceChip(
                  label: Text(labelFor(item)),
                  selected: item == selectedTab,
                  onSelected: (_) => onSelectTab(item),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}
