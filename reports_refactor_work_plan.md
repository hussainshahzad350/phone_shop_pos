# Reports Refactor Work Plan (Execution Tracker)

Date started: 2026-06-01
Module root: `lib/modules/reports`
Target: safe phased extraction of reports god screen and provider layer

## Guardrails

- No behavior change in Phase 1–3.
- No financial/business rule edits before Phase 4.
- Keep rollback-safe commits at each phase boundary.
- Validate after every phase with targeted tests + manual smoke checks.

## Phase Status Overview

- [x] Phase 0 — Safety baseline
- [~] Phase 1 — UI extraction (in progress)
- [ ] Phase 2 — Tab extraction
- [ ] Phase 3 — Dialog isolation
- [ ] Phase 4 — Computed layer extraction
- [ ] Phase 5 — Workflow centralization
- [ ] Phase 6 — Domain service migration
- [ ] Phase 7 — Provider restructure
- [ ] Phase 8 — Final simplification

---

## Phase 0 — Safety Baseline (Done)

### Deliverables

- [x] Create `reports_audit_baseline.md` with invariants and snapshot checklist.
- [ ] Attach actual screenshot/export artifacts (manual capture step).

### Acceptance

- Baseline invariants documented.
- Team can compare post-phase behavior against baseline.

---

## Phase 1 — UI Extraction (In Progress)

### Goal

Extract visual sections only from `reports_screen.dart`; do not change provider wiring or calculations.

### Completed

- [x] Extract refresh header widget.
  - `lib/modules/reports/presentation/widgets/report_header.dart`
- [x] Extract tab chips widget.
  - `lib/modules/reports/presentation/widgets/report_tab_chips.dart`
- [x] Extract legacy pagination widget.
  - `lib/modules/reports/presentation/widgets/report_pagination_bar.dart`
- [x] Wire extracted widgets into `reports_screen.dart` with callback parity.
- [x] Extract reusable date filter button UI.
  - `lib/modules/reports/presentation/widgets/report_date_filter_button.dart`
- [x] Extract reusable summary row UI.
  - `lib/modules/reports/presentation/widgets/report_summary_row.dart`
- [x] Replace repeated date-picker and summary-row UI blocks with extracted widgets.

### Remaining in Phase 1

- [ ] Extract remaining table-shell wrappers where still inline in each tab view.
- [ ] Keep all calculations and provider reads exactly where they are.

### Acceptance

- `reports_screen.dart` reduced structurally.
- No change to provider dependency graph.
- Widget/integration smoke tests pass (or known pre-existing failures documented).

---

## Phase 2 — Tab Extraction

### Completed So Far

- [x] Extracted `CashFlowTab` to `lib/modules/reports/presentation/tabs/cash_flow_tab.dart`.
- [x] Extracted `RepairAnalyticsTab` to `lib/modules/reports/presentation/tabs/repair_analytics_tab.dart`.
- [x] Wired both tabs into `reports_screen.dart`.
- [x] Extracted `ProfitTab` to `lib/modules/reports/presentation/tabs/profit_tab.dart`.
- [x] Extracted `DailySalesTab` to `lib/modules/reports/presentation/tabs/daily_sales_tab.dart`.
  - Wired coordinator helper methods `_showInvoiceDialog()` and `_reprint()` into tab via callbacks.
  - Threaded callbacks through `_ReportContent` to maintain action routing.
  - Fixed multi-site wiring: all _ReportContent call sites now include required callbacks.
- [x] Extracted `CustomerLedgerTab` to `lib/modules/reports/presentation/tabs/customer_ledger_tab.dart`.
  - Wired coordinator helper method `_openCustomerLedger()` into tab via callback.
- [x] Extracted `SupplierLedgerTab` to `lib/modules/reports/presentation/tabs/supplier_ledger_tab.dart`.
  - Wired coordinator helper method `_openSupplierLedger()` into tab via callback.

### Planned Files

  - `lib/modules/reports/presentation/tabs/purchase_history_tab.dart` (medium-risk: has purchase detail dialogs)
- `lib/modules/reports/presentation/tabs/purchase_tab.dart`
- `lib/modules/reports/presentation/tabs/cash_flow_tab.dart`
- `lib/modules/reports/presentation/tabs/expenses_tab.dart`
- `lib/modules/reports/presentation/tabs/repair_analytics_tab.dart`
- `lib/modules/reports/presentation/tabs/ledger_tab.dart`

### Acceptance

- Coordinator routes tabs only.
- Provider calls unchanged.

---

## Phase 3 — Dialog Isolation

### Planned Files

- `lib/modules/reports/presentation/dialogs/sales_invoice_dialog.dart`
- `lib/modules/reports/presentation/dialogs/return_sale_dialog.dart`
- `lib/modules/reports/presentation/dialogs/purchase_detail_dialog.dart`
- `lib/modules/reports/presentation/dialogs/return_purchase_dialog.dart`
- `lib/modules/reports/presentation/dialogs/expense_form_dialog.dart`
- `lib/modules/reports/presentation/dialogs/expense_delete_dialog.dart`
- `lib/modules/reports/presentation/dialogs/collect_payment_dialog.dart`

### Acceptance

- Dialog behavior and submit side-effects unchanged.

---

## Phase 4 — Computed Layer Extraction

### Planned Files

- `lib/modules/reports/application/providers/report_computed_providers.dart`
- `lib/modules/reports/domain/services/report_calculation_service.dart`

### Move Scope

- Totals, aggregates, row transformations, financial summaries.

### Acceptance

- UI becomes display-only for computed values.
- Parity checks for totals before/after extraction.

---

## Phase 5 — Workflow Centralization

### Planned File

- `lib/modules/reports/application/controllers/report_workflow_coordinator.dart`

### Acceptance

- Replace scattered invalidation calls with coordinator actions.

---

## Phase 6 — Domain Service Migration

### Planned Files

- `lib/modules/reports/domain/services/sales_report_service.dart`
- `lib/modules/reports/domain/services/profit_report_service.dart`
- `lib/modules/reports/domain/services/cash_report_service.dart`
- `lib/modules/reports/domain/services/ledger_report_service.dart`
- `lib/modules/reports/domain/services/expense_report_service.dart`
- `lib/modules/reports/domain/services/purchase_report_service.dart`

### Acceptance

- UI contains no transactional/business rule orchestration.

---

## Phase 7 — Provider Restructure

### Planned Files

- `lib/modules/reports/application/providers/report_tab_provider.dart`
- `lib/modules/reports/application/providers/report_filter_providers.dart`
- `lib/modules/reports/application/providers/report_query_providers.dart`
- `lib/modules/reports/application/providers/report_state_providers.dart`

### Acceptance

- Reduced provider duplication and clean UI/domain state split.

---

## Phase 8 — Final Simplification

### Target

- `lib/modules/reports/presentation/screens/reports_screen.dart` as coordinator only (~300–400 lines target).

### Acceptance

- Routes tabs and high-level composition only.

---

## Verification Log

- 2026-06-01: `flutter test test/integration/phase4_returns_payments_rp001_rp010_test.dart` ✅
- 2026-06-01: `flutter test test/widget/reports_pagination_test.dart` ✅ (updated test overrides to match current daily-sales provider usage)
- 2026-06-01: `flutter test test/widget/reports_pagination_test.dart` ✅ (still passing after Phase 2 tab extraction)
- 2026-06-01: `flutter test test/integration/phase4_returns_payments_rp001_rp010_test.dart` ✅ (still passing after Phase 2 tab extraction)
- 2026-06-01: `flutter test test/widget/reports_pagination_test.dart` ✅ (passing after Daily Sales extraction and callback wiring)
- 2026-06-01: `flutter test test/integration/phase4_returns_payments_rp001_rp010_test.dart` ✅ (passing after Daily Sales extraction)
- 2026-06-01: `flutter test test/widget/reports_pagination_test.dart` + `phase4_returns_payments_rp001_rp010_test.dart` ✅ (All 13 tests passing after ledger tabs extraction with callbacks; fixed missing import in report_ledger_overview.dart)

## Risk Mitigation Status

### Callback Threading Pattern ✅ PROVEN
- Successfully used for invoice open/reprint actions in Daily Sales (2 callbacks).
- Successfully used for ledger open actions in Customer and Supplier ledger tabs (2 callbacks).
- Coordinator passes `Future<void> Function` parameters through `_ReportContent` to individual tabs.
- Keeps tab files isolated without pulling screen-level dialogs into tab modules.
- Pattern is replicable for remaining tabs (purchase history, expenses).

### Remaining High-Risk Extractions
- Purchase History tab: Contains purchase detail and return dialogs.
  - Mitigation: Thread purchase open and return item callbacks similar to ledger pattern.
- Expenses tab: Contains form dialogs, category dropdowns, search controller, and delete confirmation logic.
  - Mitigation: Thread all callbacks; keep _ExpenseFormDialog scoped to coordinator or extract to separate module.

### Quality Gates Maintained
- No provider behavior changes across all 6 extractions (CashFlow, Repair, Profit, DailySales, CustomerLedger, SupplierLedger).
- Integration tests remain passing (10/10 test cases). 
- Widget parity tests remain passing (3/3 test cases).
- Static analysis: 0 errors across all touched files.
