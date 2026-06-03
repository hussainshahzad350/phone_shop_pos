part of '../screens/repairing_screen.dart';

class _RepairJobsRowActions extends StatelessWidget {
  const _RepairJobsRowActions({
    required this.isDelivered,
    required this.isArchived,
    required this.hasPendingPayment,
    required this.hasFinalPaymentAmount,
    required this.canMarkDelivered,
    required this.onViewOrEdit,
    required this.onCollectPayment,
    required this.onUnarchive,
    required this.onMarkDelivered,
    required this.onArchive,
  });

  final bool isDelivered;
  final bool isArchived;
  final bool hasPendingPayment;
  final bool hasFinalPaymentAmount;
  final bool canMarkDelivered;
  final Future<void> Function() onViewOrEdit;
  final Future<void> Function() onCollectPayment;
  final Future<void> Function() onUnarchive;
  final Future<void> Function()? onMarkDelivered;
  final Future<void> Function() onArchive;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton.filledTonal(
          icon: Icon(
            isDelivered || isArchived
                ? Icons.visibility_outlined
                : Icons.edit_outlined,
            size: 18,
          ),
          tooltip: (isDelivered || isArchived) ? 'View Details' : 'Edit',
          visualDensity: VisualDensity.compact,
          onPressed: onViewOrEdit,
        ),
        if (!isArchived && !isDelivered && hasPendingPayment) ...<Widget>[
          const SizedBox(width: 6),
          IconButton.filledTonal(
            icon: const Icon(Icons.payments_outlined, size: 18),
            tooltip: 'Collect Payment',
            visualDensity: VisualDensity.compact,
            onPressed: onCollectPayment,
          ),
        ],
        if (isArchived) ...<Widget>[
          const SizedBox(width: 6),
          IconButton.filledTonal(
            icon: const Icon(Icons.unarchive_outlined, size: 18),
            tooltip: 'Unarchive',
            visualDensity: VisualDensity.compact,
            onPressed: onUnarchive,
          ),
        ] else if (!isDelivered) ...<Widget>[
          const SizedBox(width: 6),
          IconButton.filledTonal(
            icon: const Icon(Icons.local_shipping_outlined, size: 18),
            tooltip: canMarkDelivered
                ? 'Mark Delivered'
                : hasFinalPaymentAmount
                    ? 'Cannot deliver while payment is pending'
                    : 'Set final cost before delivery',
            visualDensity: VisualDensity.compact,
            onPressed: onMarkDelivered,
          ),
        ],
        if (!isArchived) ...<Widget>[
          const SizedBox(width: 6),
          IconButton.filledTonal(
            icon: const Icon(Icons.delete_outline, size: 18),
            tooltip: 'Archive',
            visualDensity: VisualDensity.compact,
            onPressed: onArchive,
          ),
        ],
      ],
    );
  }
}
