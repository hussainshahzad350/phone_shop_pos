import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/modules/dashboard/domain/entities/dashboard_range.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:phone_shop_pos/modules/dashboard/presentation/widgets/dashboard_compact_dropdown.dart';

/// Today / Week / Month range picker driving the Key Metrics section.
/// Rendered as a compact dropdown to keep the section header tight.
class DashboardRangeToggle extends ConsumerWidget {
  const DashboardRangeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(dashboardRangeProvider);

    return DashboardCompactDropdown<DashboardRange>(
      value: range,
      items: DashboardRange.values,
      labelOf: (r) => r.label,
      leadingIcon: Icons.calendar_today_outlined,
      onChanged: (selected) =>
          ref.read(dashboardRangeProvider.notifier).state = selected,
    );
  }
}
