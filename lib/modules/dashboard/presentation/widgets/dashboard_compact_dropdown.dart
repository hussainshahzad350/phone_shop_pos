import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

/// Small outlined dropdown used in dashboard section headers (range picker,
/// brand-stock view picker). Wraps the classic [DropdownButton] with the
/// app's capped menu height and rounded corners so it reads as a compact
/// toolbar control rather than a form field.
class DashboardCompactDropdown<T> extends StatelessWidget {
  const DashboardCompactDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.leadingIcon,
  });

  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: AppRadii.smRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (leadingIcon != null) ...<Widget>[
            Icon(
              leadingIcon,
              size: 15,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isDense: true,
              borderRadius: kAppDropdownMenuRadius,
              menuMaxHeight: kAppDropdownMenuMaxHeight,
              style: theme.textTheme.labelMedium,
              icon: Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              items: items
                  .map(
                    (item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(labelOf(item)),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (selected) {
                if (selected != null) onChanged(selected);
              },
            ),
          ),
        ],
      ),
    );
  }
}
