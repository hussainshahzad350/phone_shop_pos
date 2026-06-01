import 'package:flutter/material.dart';

class ReportSummaryRow extends StatelessWidget {
  const ReportSummaryRow({
    super.key,
    required this.children,
    this.spacing = 8,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (var index = 0; index < children.length; index++) ...<Widget>[
          children[index],
          if (index != children.length - 1) SizedBox(width: spacing),
        ],
      ],
    );
  }
}
