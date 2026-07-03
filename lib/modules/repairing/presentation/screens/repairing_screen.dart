import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/core/theme/app_semantic_colors.dart';
import 'package:phone_shop_pos/core/utils/date_time_helpers.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/core/utils/id_helpers.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';
import 'package:phone_shop_pos/core/widgets/responsive_table_layout.dart';
import 'package:phone_shop_pos/modules/repairing/domain/entities/repair_analytics_entity.dart';
import 'package:phone_shop_pos/modules/repairing/domain/entities/repair_job_entity.dart';
import 'package:phone_shop_pos/modules/repairing/presentation/providers/repairing_providers.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';
import 'package:phone_shop_pos/core/theme/app_typography.dart';

part '../dialogs/collect_payment_dialog.dart';
part '../dialogs/repair_job_form_dialog.dart';
part '../services/repairing_action_service.dart';
part '../widgets/repair_jobs_row_actions.dart';
part '../widgets/repair_jobs_table.dart';
part '../widgets/repair_status_chip.dart';
part '../widgets/repairing_filters_row.dart';
part '../widgets/repairing_kpi_row.dart';

class RepairingScreen extends ConsumerWidget {
  const RepairingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: AppSpacing.md),
            const _KpiRow(),
            const SizedBox(height: AppSpacing.md),
            const _FiltersRow(),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: SingleChildScrollView(
                child: const _RepairJobsTable(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
