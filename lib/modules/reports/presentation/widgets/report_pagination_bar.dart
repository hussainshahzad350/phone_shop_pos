import 'package:flutter/material.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/report_filter_entity.dart';

class ReportPaginationBar extends StatelessWidget {
  const ReportPaginationBar({
    super.key,
    required this.filter,
    required this.canGoNextPage,
    required this.onPreviousPage,
    required this.onNextPage,
    required this.onPageSizeChanged,
  });

  final ReportFilterEntity filter;
  final bool canGoNextPage;
  final VoidCallback onPreviousPage;
  final VoidCallback onNextPage;
  final ValueChanged<int> onPageSizeChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: filter.page <= 1 ? null : onPreviousPage,
          icon: const Icon(Icons.chevron_left),
          label: const Text('Previous'),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: canGoNextPage ? onNextPage : null,
          icon: const Icon(Icons.chevron_right),
          label: const Text('Next'),
        ),
        const SizedBox(width: 12),
        DropdownButton<int>(
          value: filter.pageSize,
          onChanged: (value) {
            if (value == null) {
              return;
            }
            onPageSizeChanged(value);
          },
          items: const <DropdownMenuItem<int>>[
            DropdownMenuItem<int>(value: 25, child: Text('25 / page')),
            DropdownMenuItem<int>(value: 50, child: Text('50 / page')),
            DropdownMenuItem<int>(value: 100, child: Text('100 / page')),
            DropdownMenuItem<int>(value: 200, child: Text('200 / page')),
          ],
        ),
        const SizedBox(width: 12),
        Text('Page ${filter.page}'),
      ],
    );
  }
}
