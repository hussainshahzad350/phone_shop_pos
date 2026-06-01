import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';

class ReportDateFilterButton extends StatelessWidget {
  const ReportDateFilterButton({
    super.key,
    required this.icon,
    required this.emptyLabel,
    required this.selectedDate,
    required this.initialDate,
    required this.onPicked,
    this.iconSize,
    this.firstDate,
    this.lastDate,
  });

  final IconData icon;
  final String emptyLabel;
  final DateTime? selectedDate;
  final DateTime initialDate;
  final ValueChanged<DateTime?> onPicked;
  final double? iconSize;
  final DateTime? firstDate;
  final DateTime? lastDate;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          firstDate: firstDate ?? DateTime(2020),
          lastDate:
              lastDate ?? DateTime.now().add(const Duration(days: 365)),
          initialDate: initialDate,
        );
        onPicked(picked);
      },
      icon: iconSize == null ? Icon(icon) : Icon(icon, size: iconSize),
      label: Text(
        selectedDate == null
            ? emptyLabel
            : FormattingHelpers.dateYmd(selectedDate!),
      ),
    );
  }
}
