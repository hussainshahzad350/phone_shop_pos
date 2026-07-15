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
    final tokens = AppInteractionTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton.filledTonal(
          icon: Icon(
            isDelivered || isArchived
                ? Icons.visibility_outlined
                : Icons.edit_outlined,
            size: tokens.rowActionIconSize,
          ),
          tooltip: (isDelivered || isArchived) ? 'View Details' : 'Edit',
          visualDensity: tokens.controlDensity,
          onPressed: onViewOrEdit,
        ),
        if (!isArchived && !isDelivered && hasPendingPayment) ...<Widget>[
          SizedBox(width: tokens.rowActionGap),
          IconButton.filledTonal(
            icon: Icon(Icons.payments_outlined, size: tokens.rowActionIconSize),
            tooltip: 'Collect Payment',
            visualDensity: tokens.controlDensity,
            onPressed: onCollectPayment,
          ),
        ],
        if (isArchived) ...<Widget>[
          SizedBox(width: tokens.rowActionGap),
          IconButton.filledTonal(
            icon:
                Icon(Icons.unarchive_outlined, size: tokens.rowActionIconSize),
            tooltip: 'Unarchive',
            visualDensity: tokens.controlDensity,
            onPressed: onUnarchive,
          ),
        ] else if (!isDelivered) ...<Widget>[
          SizedBox(width: tokens.rowActionGap),
          IconButton.filledTonal(
            icon: Icon(
              Icons.local_shipping_outlined,
              size: tokens.rowActionIconSize,
            ),
            tooltip: canMarkDelivered
                ? 'Mark Delivered'
                : hasFinalPaymentAmount
                    ? 'Cannot deliver while payment is pending'
                    : 'Set final cost before delivery',
            visualDensity: tokens.controlDensity,
            onPressed: onMarkDelivered,
          ),
        ],
        if (!isArchived) ...<Widget>[
          SizedBox(width: tokens.rowActionGap),
          IconButton.filledTonal(
            icon: Icon(Icons.delete_outline, size: tokens.rowActionIconSize),
            tooltip: 'Archive',
            visualDensity: tokens.controlDensity,
            onPressed: onArchive,
          ),
        ],
      ],
    );
  }
}
