import 'package:flutter_test/flutter_test.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/expense_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/operations_entities.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/sales_report_row_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/services/report_calculation_service.dart';

void main() {
  SalesReportRowEntity saleRow({
    required DateTime date,
    required String customer,
    required double total,
    required double paid,
    String status = 'completed',
  }) =>
      SalesReportRowEntity(
        saleId: 'sale-${date.microsecondsSinceEpoch}-$customer',
        invoiceNumber: 'INV-1',
        saleDate: date,
        customerName: customer,
        total: total,
        paidAmount: paid,
        paymentMethod: 'cash',
        status: status,
        printJobId: null,
      );

  PurchaseHistoryRowEntity purchaseRow({
    required double total,
    required double paid,
    String status = 'posted',
  }) =>
      PurchaseHistoryRowEntity(
        purchaseId: 'p-$total-$paid-$status',
        purchaseDate: DateTime(2024, 1, 1),
        supplierName: 'Supplier',
        sellerName: null,
        invoiceNumber: 'PINV-1',
        total: total,
        paidAmount: paid,
        status: status,
      );

  group('buildDailySalesPageSummary', () {
    test('excludes void sales from counts and financial totals', () {
      final summary = ReportCalculationService.buildDailySalesPageSummary(
        <SalesReportRowEntity>[
          saleRow(
            date: DateTime(2024, 1, 1),
            customer: 'Ali',
            total: 1000,
            paid: 600,
          ),
          saleRow(
            date: DateTime(2024, 1, 2),
            customer: 'Sara',
            total: 500,
            paid: 500,
          ),
          saleRow(
            date: DateTime(2024, 3, 3),
            customer: 'Ghost',
            total: 9999,
            paid: 0,
            status: 'void',
          ),
        ],
      );

      expect(summary.totalInvoices, 2);
      expect(summary.totalDays, 2);
      expect(summary.totalCustomers, 2);
      expect(summary.sumTotal, closeTo(1500, 0.0001));
      expect(summary.sumPaid, closeTo(1100, 0.0001));
      // balance = (1000-600) + (500-500) = 400
      expect(summary.sumBalance, closeTo(400, 0.0001));
    });

    test('counts distinct days and distinct non-empty customers', () {
      final summary = ReportCalculationService.buildDailySalesPageSummary(
        <SalesReportRowEntity>[
          saleRow(date: DateTime(2024, 5, 5), customer: 'Ali', total: 100, paid: 0),
          saleRow(date: DateTime(2024, 5, 5), customer: 'Ali', total: 200, paid: 0),
          // Whitespace-only customer must not inflate the customer count.
          saleRow(date: DateTime(2024, 5, 5), customer: '   ', total: 300, paid: 0),
        ],
      );

      expect(summary.totalInvoices, 3);
      expect(summary.totalDays, 1);
      expect(summary.totalCustomers, 1);
    });

    test('returns zeros for an empty row list', () {
      final summary = ReportCalculationService.buildDailySalesPageSummary(
        const <SalesReportRowEntity>[],
      );
      expect(summary.totalInvoices, 0);
      expect(summary.totalDays, 0);
      expect(summary.totalCustomers, 0);
      expect(summary.sumTotal, 0);
      expect(summary.sumPaid, 0);
      expect(summary.sumBalance, 0);
    });
  });

  group('buildPurchaseHistoryPageSummary', () {
    test('excludes void purchases from counts and totals', () {
      final summary = ReportCalculationService.buildPurchaseHistoryPageSummary(
        <PurchaseHistoryRowEntity>[
          purchaseRow(total: 2000, paid: 500),
          purchaseRow(total: 1000, paid: 1000),
          purchaseRow(total: 9999, paid: 0, status: 'void'),
        ],
      );

      expect(summary.totalPurchases, 2);
      expect(summary.sumTotal, closeTo(3000, 0.0001));
      // remainingBalance = (2000-500) + (1000-1000) = 1500
      expect(summary.sumBalance, closeTo(1500, 0.0001));
    });
  });

  group('buildCashFlowPageSummary', () {
    test('aggregates cash-in and net cash across rows', () {
      final summary = ReportCalculationService.buildCashFlowPageSummary(
        <CashLedgerRowEntity>[
          const CashLedgerRowEntity(
            day: '2024-01-01',
            cashSalesIn: 1000,
            cashCollectionsIn: 200,
            cashRefundsOut: 0,
            purchasePaymentsOut: 300,
            purchaseRefundsIn: 0,
            expensesOut: 100,
          ),
          const CashLedgerRowEntity(
            day: '2024-01-02',
            cashSalesIn: 500,
            cashCollectionsIn: 0,
            cashRefundsOut: 0,
            purchasePaymentsOut: 0,
            purchaseRefundsIn: 0,
            expensesOut: 0,
          ),
        ],
      );

      // totalCashIn = 1200 + 500 = 1700
      expect(summary.totalCashIn, closeTo(1700, 0.0001));
      // netCash = (1200-400) + (500-0) = 1300
      expect(summary.netCash, closeTo(1300, 0.0001));
    });
  });

  group('buildExpensesTableSummary', () {
    test('counts rows and sums amounts', () {
      final summary = ReportCalculationService.buildExpensesTableSummary(
        <ExpenseEntity>[
          ExpenseEntity(
            id: 'e1',
            expenseDate: DateTime(2024, 1, 1),
            category: 'Electricity Bill',
            amount: 300,
            createdAt: DateTime(2024, 1, 1),
          ),
          ExpenseEntity(
            id: 'e2',
            expenseDate: DateTime(2024, 1, 2),
            category: 'Rent',
            amount: 150,
            createdAt: DateTime(2024, 1, 2),
          ),
        ],
      );

      expect(summary.rowCount, 2);
      expect(summary.totalAmount, closeTo(450, 0.0001));
    });

    test('returns zero total for no expenses', () {
      final summary = ReportCalculationService.buildExpensesTableSummary(
        const <ExpenseEntity>[],
      );
      expect(summary.rowCount, 0);
      expect(summary.totalAmount, 0);
    });
  });
}
