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
  imeiSearch,
}

final selectedReportsTabProvider = StateProvider<ReportsTab>(
  (ref) => ReportsTab.dailySales,
);
