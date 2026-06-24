import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ReportsTab {
  dailySales,
  dailyPurchase,
  profit,
  cashFlow,
  expenses,
  repairAnalytics,
  customerLedger,
  supplierLedger,
  dealerIssues,
}

final selectedReportsTabProvider = StateProvider<ReportsTab>(
  (ref) => ReportsTab.dailySales,
);
