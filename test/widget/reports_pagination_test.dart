import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/core/errors/app_error.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/daily_sales_report_row_entity.dart';
import 'package:phone_shop_pos/modules/reports/presentation/providers/report_providers.dart';
import 'package:phone_shop_pos/modules/reports/presentation/screens/reports_screen.dart';

void main() {
  testWidgets('next page is disabled when results are less than page size', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildReportsApp(
        rows: List<DailySalesReportRowEntity>.generate(
          10,
          (index) => _row(day: '2026-01-${index + 1}'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nextButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Next'),
    );
    expect(nextButton.onPressed, isNull);
  });

  testWidgets('next page remains enabled when results equal page size', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildReportsApp(
        rows: List<DailySalesReportRowEntity>.generate(
          50,
          (index) => _row(day: '2026-02-${index + 1}'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nextButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Next'),
    );
    expect(nextButton.onPressed, isNotNull);
  });

  testWidgets('report failures show explicit error details and retry action', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          selectedReportsTabProvider.overrideWith((ref) => ReportsTab.dailySales),
          reportFilterProvider.overrideWith((ref) => ReportFilterNotifier()),
          reportCustomerOptionsProvider.overrideWith(
            (ref) async => const <MapEntry<String, String>>[],
          ),
          reportProductOptionsProvider.overrideWith(
            (ref) async => const <MapEntry<String, String>>[],
          ),
          dailySalesReportProvider.overrideWith((ref) async {
            throw const AppError(
              code: 'db_failure',
              message: 'Database unavailable',
            );
          }),
        ],
        child: const MaterialApp(home: ReportsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to load daily sales report.'), findsOneWidget);
    expect(find.text('Database unavailable'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
  });
}

Widget _buildReportsApp({
  required List<DailySalesReportRowEntity> rows,
}) {
  return ProviderScope(
    overrides: <Override>[
      selectedReportsTabProvider.overrideWith((ref) => ReportsTab.dailySales),
      reportFilterProvider.overrideWith((ref) => ReportFilterNotifier()),
      reportCustomerOptionsProvider.overrideWith(
        (ref) async => const <MapEntry<String, String>>[],
      ),
      reportProductOptionsProvider.overrideWith(
        (ref) async => const <MapEntry<String, String>>[],
      ),
      dailySalesReportProvider.overrideWith(
        (ref) async => rows,
      ),
    ],
    child: const MaterialApp(
      home: ReportsScreen(),
    ),
  );
}

DailySalesReportRowEntity _row({required String day}) {
  return DailySalesReportRowEntity(
    day: day,
    invoiceCount: 1,
    totalSales: 1000,
    totalProfit: 100,
    phonesSold: 1,
    accessoriesSold: 0,
    pendingBalances: 0,
  );
}
