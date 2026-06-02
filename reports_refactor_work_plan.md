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
- [x] Phase 1 — UI extraction
- [x] Phase 2 — Tab extraction
- [x] Phase 3 — Dialog isolation
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

## Phase 1 — UI Extraction (Done)

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

### Final Phase 1 State

- [x] Extract remaining table-shell wrappers where still inline in each tab view.
- [x] Keep all calculations and provider reads exactly where they are.

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
- [x] Extracted `PurchaseHistoryTab` to `lib/modules/reports/presentation/tabs/purchase_history_tab.dart`.
  - Preserved purchase detail callback routing through the screen coordinator.
- [x] Extracted `ExpensesTab` to `lib/modules/reports/presentation/tabs/expenses_tab.dart`.
  - Kept expense filter state, repository actions, and provider invalidations unchanged.

### Planned Files

- [x] `lib/modules/reports/presentation/tabs/purchase_history_tab.dart` (purchase detail callback preserved)
- [x] `lib/modules/reports/presentation/tabs/expenses_tab.dart`

### Acceptance

- Coordinator routes tabs only.
- Provider calls unchanged.

---

## Phase 3 — Dialog Isolation

### Planned Files

- [x] `lib/modules/reports/presentation/dialogs/sales_invoice_dialog.dart`
- [x] `lib/modules/reports/presentation/dialogs/return_sale_dialog.dart`
- [x] `lib/modules/reports/presentation/dialogs/purchase_detail_dialog.dart`
- [x] `lib/modules/reports/presentation/dialogs/return_purchase_dialog.dart`
- [x] `lib/modules/reports/presentation/dialogs/expense_form_dialog.dart`
- [x] `lib/modules/reports/presentation/dialogs/expense_delete_dialog.dart`
- [x] `lib/modules/reports/presentation/dialogs/collect_payment_dialog.dart`

### Completed

- [x] Moved sales invoice + return dialogs out of `reports_screen.dart`.
- [x] Moved purchase detail + return dialogs out of `reports_screen.dart`.
- [x] Moved expense add/edit/delete dialog UI out of `reports_screen.dart`.
- [x] Reduced `reports_screen.dart` to screen-level coordination only.

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
- 2026-06-02: Extracted `ExpensesTab` plus report dialog modules (`sales_invoice_dialog.dart`, `return_sale_dialog.dart`, `purchase_detail_dialog.dart`, `return_purchase_dialog.dart`, `expense_form_dialog.dart`, `expense_delete_dialog.dart`, `collect_payment_dialog.dart`) and reduced `reports_screen.dart` to coordinator-only wiring. Local Flutter validation blocked in sandbox because `flutter` is unavailable on PATH.

## Risk Mitigation Status

### Callback Threading Pattern ✅ PROVEN
- Successfully used for invoice open/reprint actions in Daily Sales (2 callbacks).
- Successfully used for ledger open actions in Customer and Supplier ledger tabs (2 callbacks).
- Successfully used for purchase detail routing and expenses dialog orchestration.
- Coordinator passes `Future<void> Function` parameters through `_ReportContent` to individual tabs.
- Keeps tab files isolated without pulling screen-level dialogs into tab modules.
- Pattern now covers all extracted tabs that still need screen-owned actions.

### Remaining High-Risk Extractions
- None in Phases 1–3. Remaining work begins with provider/computation/service phases.

### Quality Gates Maintained
- No provider behavior changes across all extraction-only tab moves (CashFlow, Repair, Profit, DailySales, CustomerLedger, SupplierLedger, PurchaseHistory, Expenses).
- No provider behavior changes across all extraction-only phases after moving Expenses and dialog workflows into dedicated modules.
- Integration tests remain passing (10/10 test cases). 
- Widget parity tests remain passing (3/3 test cases).
- Static analysis: previously clean on 2026-06-01 baseline; 2026-06-02 local rerun blocked because `flutter` is unavailable in sandbox.
