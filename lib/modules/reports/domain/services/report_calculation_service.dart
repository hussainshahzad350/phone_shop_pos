import 'package:phone_shop_pos/core/utils/formatting_helpers.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/expense_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/operations_entities.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/profit_row_entity.dart';
import 'package:phone_shop_pos/modules/reports/domain/entities/sales_report_row_entity.dart';

class DailySalesPageSummary {
  const DailySalesPageSummary({
    required this.totalInvoices,
    required this.totalDays,
    required this.totalCustomers,
    required this.sumTotal,
    required this.sumPaid,
    required this.sumBalance,
  });

  final int totalInvoices;
  final int totalDays;
  final int totalCustomers;
  final double sumTotal;
  final double sumPaid;
  final double sumBalance;
}

class PurchaseHistoryPageSummary {
  const PurchaseHistoryPageSummary({
    required this.totalPurchases,
    required this.sumTotal,
    required this.sumBalance,
  });

  final int totalPurchases;
  final double sumTotal;
  final double sumBalance;
}

class CashFlowPageSummary {
  const CashFlowPageSummary({
    required this.totalCashIn,
    required this.netCash,
  });

  final double totalCashIn;
  final double netCash;
}

class ExpensesTableSummary {
  const ExpensesTableSummary({
    required this.rowCount,
    required this.totalAmount,
  });

  final int rowCount;
  final double totalAmount;
}

class ReportCalculationService {
  const ReportCalculationService._();

  static DailySalesPageSummary buildDailySalesPageSummary(
    List<SalesReportRowEntity> rows,
  ) {
    return DailySalesPageSummary(
      totalInvoices: rows.length,
      totalDays: rows
          .map(
            (row) => '${row.saleDate.year}-${row.saleDate.month}-${row.saleDate.day}',
          )
          .toSet()
          .length,
      totalCustomers: rows
          .map((row) => row.customerName.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .length,
      sumTotal: rows.fold<double>(0, (sum, row) => sum + row.total),
      sumPaid: rows.fold<double>(0, (sum, row) => sum + row.paidAmount),
      sumBalance: rows.fold<double>(0, (sum, row) => sum + row.balance),
    );
  }

  static List<List<String>> buildDailySalesExportRows(
    List<SalesReportRowEntity> rows,
  ) {
    return rows
        .map(
          (row) => <String>[
            row.invoiceNumber,
            FormattingHelpers.dateYmd(row.saleDate),
            row.customerName,
            FormattingHelpers.decimal(row.total),
            FormattingHelpers.decimal(row.paidAmount),
            FormattingHelpers.decimal(row.balance),
            row.paymentMethod ?? '-',
            row.status,
          ],
        )
        .toList(growable: false);
  }

  static PurchaseHistoryPageSummary buildPurchaseHistoryPageSummary(
    List<PurchaseHistoryRowEntity> rows,
  ) {
    return PurchaseHistoryPageSummary(
      totalPurchases: rows.length,
      sumTotal: rows.fold<double>(0, (sum, row) => sum + row.total),
      sumBalance: rows.fold<double>(
        0,
        (sum, row) => sum + row.remainingBalance,
      ),
    );
  }

  static CashFlowPageSummary buildCashFlowPageSummary(
    List<CashLedgerRowEntity> rows,
  ) {
    return CashFlowPageSummary(
      totalCashIn: rows.fold<double>(0, (sum, row) => sum + row.totalCashIn),
      netCash: rows.fold<double>(0, (sum, row) => sum + row.netCash),
    );
  }

  static List<List<String>> buildProfitExportRows(List<ProfitRowEntity> rows) {
    return rows
        .map(
          (row) => <String>[
            row.day,
            row.phonesSold.toString(),
            row.accessoriesSold.toString(),
            row.totalRevenue.toStringAsFixed(2),
            row.totalCost.toStringAsFixed(2),
            row.totalProfit.toStringAsFixed(2),
            '${row.marginPercent.toStringAsFixed(1)}%',
          ],
        )
        .toList(growable: false);
  }

  static ExpensesTableSummary buildExpensesTableSummary(
    List<ExpenseEntity> rows,
  ) {
    return ExpensesTableSummary(
      rowCount: rows.length,
      totalAmount: rows.fold<double>(0, (sum, expense) => sum + expense.amount),
    );
  }
}
