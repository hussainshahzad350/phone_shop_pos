import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppOperation {
  const AppOperation({
    required this.id,
    required this.code,
    required this.label,
    required this.startedAt,
    this.progressLabel,
    this.isCritical = true,
  });

  final String id;
  final String code;
  final String label;
  final DateTime startedAt;
  final String? progressLabel;
  final bool isCritical;

  AppOperation copyWith({
    String? progressLabel,
  }) {
    return AppOperation(
      id: id,
      code: code,
      label: label,
      startedAt: startedAt,
      progressLabel: progressLabel ?? this.progressLabel,
      isCritical: isCritical,
    );
  }
}

class OperationManager extends StateNotifier<List<AppOperation>> {
  OperationManager() : super(const <AppOperation>[]);

  String start({
    required String code,
    required String label,
    String? progressLabel,
    bool isCritical = true,
  }) {
    final operationId = '${code}_${DateTime.now().toUtc().microsecondsSinceEpoch}';
    state = <AppOperation>[
      AppOperation(
        id: operationId,
        code: code,
        label: label,
        startedAt: DateTime.now().toUtc(),
        progressLabel: progressLabel,
        isCritical: isCritical,
      ),
      ...state,
    ];
    return operationId;
  }

  void updateProgress(String operationId, String progressLabel) {
    state = state
        .map(
          (operation) => operation.id == operationId
              ? operation.copyWith(progressLabel: progressLabel)
              : operation,
        )
        .toList(growable: false);
  }

  void finish(String operationId) {
    state = state
        .where((operation) => operation.id != operationId)
        .toList(growable: false);
  }

  Future<T> track<T>({
    required String code,
    required String label,
    String? progressLabel,
    bool isCritical = true,
    required Future<T> Function(String operationId) action,
  }) async {
    final operationId = start(
      code: code,
      label: label,
      progressLabel: progressLabel,
      isCritical: isCritical,
    );
    try {
      return await action(operationId);
    } finally {
      finish(operationId);
    }
  }
}

final operationManagerProvider =
    StateNotifierProvider<OperationManager, List<AppOperation>>(
      (ref) => OperationManager(),
    );

final activeCriticalOperationsProvider = Provider<List<AppOperation>>((ref) {
  return ref
      .watch(operationManagerProvider)
      .where((operation) => operation.isCritical)
      .toList(growable: false);
});
