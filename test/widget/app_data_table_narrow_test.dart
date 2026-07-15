import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:phone_shop_pos/core/widgets/desktop_components.dart';

void main() {
  // A table whose fixed-width cells sum well past a narrow viewport —
  // mirrors the report tables' desktop-tier column widths.
  AppDataTable wideTable() {
    return AppDataTable(
      columns: List<DataColumn>.generate(
        6,
        (i) => DataColumn(
          label: SizedBox(width: 150, child: Text('Column $i')),
        ),
      ),
      rows: List<DataRow>.generate(
        3,
        (r) => DataRow(
          cells: List<DataCell>.generate(
            6,
            (c) => DataCell(SizedBox(width: 150, child: Text('R$r C$c'))),
          ),
        ),
      ),
    );
  }

  testWidgets('narrow bounded viewport scrolls horizontally instead of '
      'overflowing', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              height: 300,
              child: wideTable(),
            ),
          ),
        ),
      ),
    );

    // No RenderFlex/RenderTable overflow exceptions.
    expect(tester.takeException(), isNull);

    // The compact path renders one single table (aligned header + body)
    // inside a horizontal scrollable.
    final horizontal = find.byWidgetPredicate(
      (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
    );
    expect(horizontal, findsOneWidget);
    expect(find.byType(DataTable), findsOneWidget);

    // The last column starts off-screen and can be dragged into view.
    expect(find.text('R0 C5').hitTestable(), findsNothing);
    await tester.drag(horizontal, const Offset(-800, 0));
    await tester.pumpAndSettle();
    expect(find.text('R0 C5').hitTestable(), findsOneWidget);
  });

  testWidgets('wide bounded viewport keeps the sticky-header dual table',
      (tester) async {
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1200,
            height: 600,
            child: wideTable(),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    // Sticky-header path: separate header table + body table.
    expect(find.byType(DataTable), findsNWidgets(2));
  });
}
