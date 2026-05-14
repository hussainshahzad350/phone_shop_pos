import 'package:flutter/material.dart';

class AppPlaceholderWidget extends StatelessWidget {
  const AppPlaceholderWidget({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(label),
    );
  }
}
