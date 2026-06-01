# Reports Module Audit Baseline

Date: 2026-06-01
Module: `lib/modules/reports`
Primary screen: `lib/modules/reports/presentation/screens/reports_screen.dart`

## Scope

This baseline freezes expected behavior before refactor phases.

## Snapshot Checklist

- [ ] Daily Sales tab screenshot (default filters)
- [ ] Profit tab screenshot (default filters)
- [ ] Customer Ledger tab screenshot
- [ ] Supplier Ledger tab screenshot
- [ ] Purchase History tab screenshot
- [ ] Cash Flow tab screenshot
- [ ] Expenses tab screenshot
- [ ] Repair Analytics tab screenshot
- [ ] Sales detail export sample
- [ ] Profit export sample
- [ ] Ledger totals snapshot (customer + supplier)
- [ ] Cash flow totals snapshot

## Invariants (Must Not Break)

1. Profit summary and daily profit rows must match source sales/returns data.
2. Cash flow values must reflect payment entries and operational cash events.
3. Sales return processing must preserve financial + stock integrity.
4. Purchase return processing must preserve supplier ledger + stock integrity.
5. Expense CRUD must reflect in expense analytics and cash flow reporting.
6. Ledger outstanding totals must remain consistent after workflow actions.

## High-Risk Workflow Checkpoints

- Return sale item from invoice dialog.
- Return purchase item from purchase detail dialog.
- Expense add/update/delete from expenses tab.
- Reprint from daily sales table action.

## Validation During Refactor

- Run targeted report tests after each phase.
- Compare post-phase screenshots against baseline.
- Verify no provider refresh side-effects are lost.

## Notes

- Phase 1–3 are extraction-only (no business logic changes).
- Any logic movement starts in Phase 4 with explicit parity checks.
