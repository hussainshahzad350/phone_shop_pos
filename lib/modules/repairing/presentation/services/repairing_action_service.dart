part of '../screens/repairing_screen.dart';

class _RepairingActionService {
  static void _refresh(WidgetRef ref) {
    ref.invalidate(repairJobsProvider);
    ref.invalidate(repairKpisProvider);
  }

  static Future<void> openJobForm(
    BuildContext context,
    WidgetRef ref,
    RepairJobEntity job, {
    required bool readOnly,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RepairJobFormDialog(
        initialJob: job,
        readOnly: readOnly,
      ),
    );
    if (saved == true) {
      _refresh(ref);
    }
  }

  static Future<void> collectPayment(
    BuildContext context,
    WidgetRef ref,
    RepairJobEntity job,
  ) async {
    final request = await showDialog<_CollectPaymentRequest>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CollectPaymentDialog(job: job),
    );
    if (request == null) {
      return;
    }

    final repository = await ref.read(repairingRepositoryProvider.future);
    final result = await repository.collectPayment(
      job.id,
      request.amount,
      notes: request.notes,
    );
    result.fold(
      onSuccess: (_) {
        _refresh(ref);
        AppNotifier.success('Payment collected successfully.');
      },
      onFailure: (error) => AppNotifier.error(error.message),
    );
  }

  static Future<void> unarchiveJob(
    BuildContext context,
    WidgetRef ref,
    RepairJobEntity job,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const AppConfirmationDialog(
        title: 'Unarchive Repair Job',
        message: 'Restore this archived repair job?',
        confirmLabel: 'Unarchive',
      ),
    );
    if (confirmed != true) {
      return;
    }

    final repository = await ref.read(repairingRepositoryProvider.future);
    final result = await repository.restoreRepairJob(job.id);
    result.fold(
      onSuccess: (_) {
        _refresh(ref);
        AppNotifier.success('Repair job unarchived.');
      },
      onFailure: (error) => AppNotifier.error(error.message),
    );
  }

  static Future<void> markDelivered(
    BuildContext context,
    WidgetRef ref,
    RepairJobEntity job,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const AppConfirmationDialog(
        title: 'Mark Delivered',
        message: 'Mark this repair as delivered and close editing?',
        confirmLabel: 'Mark Delivered',
      ),
    );
    if (confirmed != true) {
      return;
    }

    final repository = await ref.read(repairingRepositoryProvider.future);
    final result = await repository.updateStatus(
      job.id,
      RepairJobEntity.statusDelivered,
    );
    result.fold(
      onSuccess: (_) {
        _refresh(ref);
        AppNotifier.success('Repair marked delivered.');
      },
      onFailure: (error) => AppNotifier.error(error.message),
    );
  }

  static Future<void> archiveJob(
    BuildContext context,
    WidgetRef ref,
    RepairJobEntity job,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AppConfirmationDialog(
        title: 'Archive Repair Job',
        message:
            'Archive this repair job? It will be hidden but preserved for audit.',
        confirmLabel: 'Archive',
      ),
    );
    if (confirmed != true) {
      return;
    }

    final repository = await ref.read(repairingRepositoryProvider.future);
    final result = await repository.deleteRepairJob(job.id);
    result.fold(
      onSuccess: (_) {
        _refresh(ref);
        AppNotifier.success('Repair job archived.');
      },
      onFailure: (error) => AppNotifier.error(error.message),
    );
  }
}
