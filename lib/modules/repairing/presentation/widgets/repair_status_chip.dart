part of '../screens/repairing_screen.dart';

Widget _repairStatusBadge(BuildContext context, String status) {
  final colors = _statusPillColors(status, Theme.of(context).colorScheme);
  return AppStatusBadge(
    label: _statusLabel(status),
    color: colors.background,
    foreground: colors.foreground,
  );
}

({Color background, Color foreground}) _statusPillColors(
  String status,
  ColorScheme colorScheme,
) {
  switch (status) {
    case RepairJobEntity.statusReceived:
      return (
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurfaceVariant,
      );
    case RepairJobEntity.statusDiagnosing:
      return (
        background: colorScheme.secondaryContainer,
        foreground: colorScheme.onSecondaryContainer,
      );
    case RepairJobEntity.statusRepairing:
      return (
        background: colorScheme.tertiaryContainer,
        foreground: colorScheme.onTertiaryContainer,
      );
    case RepairJobEntity.statusReady:
      return (
        background: colorScheme.primaryContainer,
        foreground: colorScheme.onPrimaryContainer,
      );
    case RepairJobEntity.statusDelivered:
      return (
        background: colorScheme.secondaryContainer,
        foreground: colorScheme.onSecondaryContainer,
      );
    case RepairJobEntity.statusCancelled:
      return (
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
      );
    default:
      return (
        background: colorScheme.surfaceContainerHighest,
        foreground: colorScheme.onSurfaceVariant,
      );
  }
}

String _statusLabel(String status) {
  switch (status) {
    case RepairJobEntity.statusReceived:
      return 'Received';
    case RepairJobEntity.statusDiagnosing:
      return 'Diagnosing';
    case RepairJobEntity.statusRepairing:
      return 'Repairing';
    case RepairJobEntity.statusReady:
      return 'Ready';
    case RepairJobEntity.statusDelivered:
      return 'Delivered';
    case RepairJobEntity.statusCancelled:
      return 'Cancelled';
    default:
      return status;
  }
}
