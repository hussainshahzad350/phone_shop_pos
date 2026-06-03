part of '../screens/repairing_screen.dart';

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final colors = _statusPillColors(status, colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusLabel(status),
        style: theme.textTheme.labelMedium?.copyWith(
          color: colors.foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
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
