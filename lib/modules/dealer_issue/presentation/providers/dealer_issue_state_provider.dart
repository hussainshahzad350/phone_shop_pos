import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone_shop_pos/core/database/database_provider.dart';
import 'package:phone_shop_pos/core/notifications/app_notifier.dart';
import 'package:phone_shop_pos/modules/dealer_issue/domain/entities/dealer_issue_entity.dart';
import 'package:phone_shop_pos/modules/dealer_issue/domain/repositories/dealer_issue_repository.dart';
import 'package:phone_shop_pos/modules/dealer_issue/data/repositories/sqlite_dealer_issue_repository.dart';

class DealerIssueState {
  final List<DealerIssueEntity> issues;
  final DealerIssueEntity? selectedIssue;
  final String? selectedDealerId;
  final List<String> selectedImeis;
  final bool isSubmitting;
  final String? errorMessage;
  final bool isLoading;

  DealerIssueState({
    this.issues = const [],
    this.selectedIssue,
    this.selectedDealerId,
    this.selectedImeis = const [],
    this.isSubmitting = false,
    this.errorMessage,
    this.isLoading = false,
  });

  DealerIssueState copyWith({
    List<DealerIssueEntity>? issues,
    DealerIssueEntity? selectedIssue,
    String? selectedDealerId,
    List<String>? selectedImeis,
    bool? isSubmitting,
    String? errorMessage,
    bool? isLoading,
  }) {
    return DealerIssueState(
      issues: issues ?? this.issues,
      selectedIssue: selectedIssue ?? this.selectedIssue,
      selectedDealerId: selectedDealerId ?? this.selectedDealerId,
      selectedImeis: selectedImeis ?? this.selectedImeis,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool get hasSelectedDealer => selectedDealerId != null && selectedDealerId!.isNotEmpty;
  bool get hasSelectedImeis => selectedImeis.isNotEmpty;
  bool get canCreateIssue => hasSelectedDealer && hasSelectedImeis;
  int get selectedIssueCount => selectedImeis.length;
}

class DealerIssueStateNotifier extends StateNotifier<DealerIssueState> {
  final DealerIssueRepository _repository;

  DealerIssueStateNotifier(this._repository) : super(DealerIssueState());

  Future<void> loadIssues() async {
    state = state.copyWith(isLoading: true);
    final result = await _repository.getAllIssues();
    state = state.copyWith(isLoading: false);

    result.fold(
      onSuccess: (issues) {
        state = state.copyWith(issues: issues);
      },
      onFailure: (error) {
        AppNotifier.error('Failed to load issues: ${error.message}');
        state = state.copyWith(errorMessage: error.message);
      },
    );
  }

  Future<void> loadIssuesByDealer(String dealerId) async {
    state = state.copyWith(isLoading: true, selectedDealerId: dealerId);
    final result = await _repository.getIssuesByDealer(dealerId);
    state = state.copyWith(isLoading: false);

    result.fold(
      onSuccess: (issues) {
        state = state.copyWith(issues: issues);
      },
      onFailure: (error) {
        AppNotifier.error('Failed to load issues: ${error.message}');
        state = state.copyWith(errorMessage: error.message);
      },
    );
  }

  Future<void> selectDealer(String dealerId) async {
    state = state.copyWith(selectedDealerId: dealerId, selectedImeis: []);
    await loadIssuesByDealer(dealerId);
  }

  Future<void> selectImei(String imei) async {
    final selected = state.selectedImeis;
    if (selected.contains(imei)) {
      state = state.copyWith(selectedImeis: selected.where((i) => i != imei).toList());
    } else {
      state = state.copyWith(selectedImeis: [...selected, imei]);
    }
  }

  Future<void> createIssue({
    required String dealerId,
    required List<String> imeiList,
    String? notes,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);

    final issue = DealerIssueEntity(
      issueId: DateTime.now().millisecondsSinceEpoch.toString(),
      dealerId: dealerId,
      imeiList: imeiList,
      issueDate: DateTime.now(),
      notes: notes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final result = await _repository.createIssue(issue);
    state = state.copyWith(isSubmitting: false);

    result.fold(
      onSuccess: (createdIssue) {
        AppNotifier.success('Issue created successfully');
        state = state.copyWith(
          issues: [...state.issues, createdIssue],
          selectedImeis: [],
        );
      },
      onFailure: (error) {
        AppNotifier.error('Failed to create issue: ${error.message}');
        state = state.copyWith(errorMessage: error.message);
      },
    );
  }

  Future<void> updateIssue(DealerIssueEntity issue) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);

    final result = await _repository.updateIssue(issue);
    state = state.copyWith(isSubmitting: false);

    result.fold(
      onSuccess: (_) {
        AppNotifier.success('Issue updated successfully');
        state = state.copyWith(
          issues: state.issues.map((i) => i.issueId == issue.issueId ? issue : i).toList(),
        );
      },
      onFailure: (error) {
        AppNotifier.error('Failed to update issue: ${error.message}');
        state = state.copyWith(errorMessage: error.message);
      },
    );
  }

  Future<void> deleteIssue(String issueId) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);

    final result = await _repository.deleteIssue(issueId);
    state = state.copyWith(isSubmitting: false);

    result.fold(
      onSuccess: (_) {
        AppNotifier.success('Issue deleted successfully');
        state = state.copyWith(
          issues: state.issues.where((i) => i.issueId != issueId).toList(),
          selectedIssue: null,
        );
      },
      onFailure: (error) {
        AppNotifier.error('Failed to delete issue: ${error.message}');
        state = state.copyWith(errorMessage: error.message);
      },
    );
  }

  Future<void> markAsReturned(String issueId) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);

    final result = await _repository.markAsReturned(issueId);
    state = state.copyWith(isSubmitting: false);

    result.fold(
      onSuccess: (_) {
        AppNotifier.success('Item marked as returned');
        state = state.copyWith(
          issues: state.issues.map((i) => i.issueId == issueId ? i.copyWith(returnStatus: true, returnedAt: DateTime.now()) : i).toList(),
        );
      },
      onFailure: (error) {
        AppNotifier.error('Failed to mark as returned: ${error.message}');
        state = state.copyWith(errorMessage: error.message);
      },
    );
  }

  Future<void> convertToSale(String issueId, String saleInvoiceId) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);

    final result = await _repository.convertToSale(issueId, saleInvoiceId);
    state = state.copyWith(isSubmitting: false);

    result.fold(
      onSuccess: (_) {
        AppNotifier.success('Converted to sale successfully');
        state = state.copyWith(
          issues: state.issues.map((i) => i.issueId == issueId ? i.copyWith(convertedToSale: true, saleInvoiceId: saleInvoiceId) : i).toList(),
        );
      },
      onFailure: (error) {
        AppNotifier.error('Failed to convert to sale: ${error.message}');
        state = state.copyWith(errorMessage: error.message);
      },
    );
  }

  Future<void> markAsSold(String issueId) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);

    final result = await _repository.markAsSold(issueId);
    state = state.copyWith(isSubmitting: false);

    result.fold(
      onSuccess: (_) {
        AppNotifier.success('Item marked as sold');
        state = state.copyWith(
          issues: state.issues.map((i) => i.issueId == issueId ? i.copyWith(soldStatus: true) : i).toList(),
        );
      },
      onFailure: (error) {
        AppNotifier.error('Failed to mark as sold: ${error.message}');
        state = state.copyWith(errorMessage: error.message);
      },
    );
  }

  void selectIssue(DealerIssueEntity issue) {
    state = state.copyWith(selectedIssue: issue);
  }

  void clearSelection() {
    state = state.copyWith(selectedIssue: null);
  }
}

final dealerIssueStateProvider = StateNotifierProvider<DealerIssueStateNotifier, DealerIssueState>((ref) {
  final repository = ref.watch(dealerIssueRepositoryProvider);
  return DealerIssueStateNotifier(repository);
});

final dealerIssueRepositoryProvider = Provider<DealerIssueRepository>((ref) {
  final appDatabase = ref.watch(appDatabaseProvider).value!;
  return SqliteDealerIssueRepository(appDatabase: appDatabase);
});