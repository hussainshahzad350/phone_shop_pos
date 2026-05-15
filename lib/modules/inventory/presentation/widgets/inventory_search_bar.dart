import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';

class InventorySearchBar extends StatelessWidget {
  const InventorySearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.focusNode,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return AppSearchField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      onChanged: onChanged,
      hintText: 'Search by name, IMEI, SKU, brand...',
    );
  }
}
