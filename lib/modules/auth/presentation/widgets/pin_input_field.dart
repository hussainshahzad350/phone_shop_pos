import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';

class PinInputField extends StatelessWidget {
  const PinInputField({
    super.key,
    required this.controller,
    required this.labelText,
    this.focusNode,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String labelText;
  final FocusNode? focusNode;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      decoration: appDesktopInputDecoration(
        labelText: labelText,
      ),
      keyboardType: TextInputType.number,
      obscureText: true,
      textInputAction: textInputAction,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      onSubmitted: onSubmitted,
    );
  }
}
