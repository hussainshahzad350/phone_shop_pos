class RepairAnalyticsEntity {
  const RepairAnalyticsEntity({
    required this.totalRepairs,
    required this.deliveredRepairs,
    required this.pendingRepairs,
    required this.totalEarnings,
    required this.totalExpenses,
    required this.issueGroups,
    required this.topModels,
    required this.monthlyTrend,
  });

  final int totalRepairs;
  final int deliveredRepairs;
  final int pendingRepairs;
  final double totalEarnings;
  final double totalExpenses;
  final List<RepairIssueGroupEntity> issueGroups;
  final List<RepairModelCountEntity> topModels;
  final List<RepairMonthlyRowEntity> monthlyTrend;
}

class RepairIssueGroupEntity {
  const RepairIssueGroupEntity({
    required this.issue,
    required this.count,
  });

  final String issue;
  final int count;
}

class RepairModelCountEntity {
  const RepairModelCountEntity({
    required this.model,
    required this.count,
  });

  final String model;
  final int count;
}

class RepairMonthlyRowEntity {
  const RepairMonthlyRowEntity({
    required this.month,
    required this.repairs,
    required this.earnings,
  });

  final String month;
  final int repairs;
  final double earnings;
}

class RepairKpiEntity {
  const RepairKpiEntity({
    required this.receivedToday,
    required this.readyForDelivery,
    required this.pendingRepairs,
    required this.todayEarnings,
    double? allTimeEarnings,
    int? allJobsDone,
  })  : _allTimeEarnings = allTimeEarnings,
        _allJobsDone = allJobsDone;

  final int receivedToday;
  final int readyForDelivery;
  final int pendingRepairs;
  final double todayEarnings;
  final double? _allTimeEarnings;
  final int? _allJobsDone;

  double get allTimeEarnings => _allTimeEarnings ?? 0;
  int get allJobsDone => _allJobsDone ?? 0;
}
