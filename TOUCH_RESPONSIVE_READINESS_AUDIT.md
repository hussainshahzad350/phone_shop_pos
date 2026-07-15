# Touch & Responsive Readiness Audit — Phone Shop POS

> **Version:** 1.0 · **Audit date:** 2026-07-14
> **Scope:** Full `lib/` tree (347 Dart files, ~54,000 lines), `windows/` runner, `pubspec.yaml`, all 12 feature modules.
> **Objective:** Determine whether the current Windows Desktop Flutter POS can support touch-enabled devices (Windows touch laptop, Windows tablet) and a future Android tablet without major architectural changes.
> **Constraint honored:** No source code was modified. This document is the only artifact added.

---

## Implementation Progress

> **Updated 2026-07-15 — Target 1 (Windows Touch Laptop) is COMPLETE** on this PR, behind a persisted **Settings → Display & Input → Touch mode** toggle (desktop behavior with the toggle off is unchanged and pinned by regression tests). CI green (`analyze-and-test`, 517 tests).

| Audit item | Status | Delivered as |
|---|---|---|
| C-01 Scanner focus stealing / IME summoning | ✅ **Completed (partial scope as planned)** — touch mode uses `TextInputType.none`, skips metrics force-reclaim, softens resume reclaim; wedge scanners unaffected. Camera transport remains for the Android phase. | `feat(scanner)` |
| H-01 Compact density / sub-48dp targets | ✅ **Completed** — touch theme profile + `AppInteractionTokens`; hotspots (repair row actions, cart stepper, product cards, all `AppDataTable` rows) inflate to ≥48dp | `feat(theme)`, `feat(ui)` |
| H-02 Fixed-width dialogs | ✅ **Completed** — `AppDialogContentBox` clamps all 35 dialog sites to the screen (unconditional) | `fix(ui)` |
| M-05 Tooltip-only disabled reasons | ✅ **Completed** — `AppDisabledReasonTap` snackbar on tap in touch mode (repair Mark Delivered; Complete Sale already showed inline text) | `feat(ux)` |
| M-06 No SafeArea | ✅ **Completed** — shell body wrapped | `feat(ux)` |
| L-04 Keyboard-help chrome | ✅ **Completed** — hidden in touch mode | `feat(ux)` |
| L-05 Min window size | ✅ **Already implemented** — audit correction: `win32_window.cpp:28-29` + `WM_GETMINMAXINFO` enforce 1366×768; no change needed | verify-only |
| M-01 Desktop-only table tiers | ✅ **Completed (step 1)** — below 900px `AppDataTable` renders a single aligned table in a width-preserving horizontal scroll; desktop sticky header unchanged. A card-list tier remains optional polish. | `feat(responsive)` |
| M-02 Fixed side panels (Sales/Purchase) | ✅ **Completed** — below 900px both screens stack: full-width cart/items table + summary bar opening the checkout/supplier panel in a bottom sheet (keyboard-inset aware). Wide layouts unchanged. | `feat(responsive)` ×2 |
| Portrait pass (filter/action rows) | ✅ **Completed** — Inventory actions wrap; Repairing filter actions stack below 700px; Reports/ledger filters and Master Data tabs verified already adaptive (audit Part 2 was pessimistic here). | `fix(responsive)` |
| C-02, H-03, H-04, M-03, M-04 (Android platform work) | ⬜ Pending — Target 3 | — |

---

## Executive Summary

The application is **architecturally far more portable than a typical Windows-first Flutter POS** — but its **interaction layer is engineered around three desktop assumptions** that will actively break on touch devices:

1. **A hidden keyboard-wedge scanner field that steals focus every 500 ms** (`lib/modules/scanner/presentation/widgets/global_scanner_input.dart:28`). On any device with an on-screen keyboard this is catastrophic: the OS treats the hidden field as an editable text input, so the virtual keyboard pops open on app start, reappears after every dismissal, and fights the user for focus between timer ticks.
2. **A globally compact density profile** (`VisualDensity.compact` at `lib/core/theme/app_theme.dart:22`, `isDense: true` at `app_theme.dart:60`, plus `MaterialTapTargetSize.shrinkWrap` and 18 px icons in row actions). Nearly every interactive control lands **below the Material 48×48 dp touch-target minimum**.
3. **Desktop-only responsive tiers.** Breakpoints exist and are used consistently — but the *smallest* tier assumes ~1,000–1,220 px of width. There is no phone/portrait-tablet tier, no `SafeArea` anywhere in the app, and dialogs are hard-coded up to **980 px wide**.

On the positive side: there are **no Win32 packages, no `window_manager`, no `Platform.isWindows` branches, and no right-click menus anywhere**. Storage roots come from `path_provider`, the database and printer are behind clean abstractions, and every keyboard shortcut has an equivalent on-screen button. The scanner *validation/business* pipeline is transport-agnostic and unit-tested — only its input widget is wedge-coupled.

**Verdict (detail in Part 14):**

| Question | Answer |
|---|---|
| Can it support touch on Windows today? | **Partially** — usable but error-prone (small targets, focus stealing, hover-only tooltips) |
| Can it support Android tablets today? | **No** — no `android/` platform folder exists, and 4 concrete blockers (Parts 8–10) |
| Is the architecture future-proof? | **Mostly yes** — service/data layers are portable; the *presentation input model* is not |
| Recommendation | **B — Moderate responsive refactor** (no rewrite; no major redesign) |

**Overall readiness score: 43 / 100** (Part 11).

---

## Part 1 — Current Input System

### 1.1 Input dependency map (per screen)

Every screen sits inside `DesktopNavigationShell` (`lib/core/widgets/desktop_navigation_shell.dart`), which wraps content in `AppShortcutManager` and overlays `GlobalScannerInput`. Input characteristics are therefore largely uniform:

| Screen | Mouse | Keyboard | Barcode scanner | Touch-compatible today? |
|---|---|---|---|---|
| Dashboard (`dashboard_screen.dart`) | tap only | F5 refresh (optional) | no | ✅ mostly (small KPI menu icons) |
| Sales (`sales_billing_screen.dart`) | tap only | **heavy** — Ctrl+F, F2, F10, ↑/↓, +/−, Delete, Esc | **primary workflow** | ⚠️ buttons exist for everything, but scanner focus + dense cart controls |
| Purchases (`purchase_screen.dart`) | tap only | bulk IMEI paste, focus traversal (tested in `test/widget/phase2_purchases_p038_p039_keyboard_focus_test.dart`) | yes | ⚠️ same pattern |
| Inventory (`inventory_screen.dart`) | tap only | Ctrl+F search | yes (lookup mode) | ⚠️ row tap opens edit dialog — OK |
| Master Data (4 panels) | tap only | dialog Enter/Esc | no | ⚠️ dense forms |
| Repairing (`repairing_screen.dart`) | tap only | dialog Enter/Esc | no | ⚠️ 18 px row-action icons |
| Dealer Issues | tap only | scan-return dialog | yes | ⚠️ |
| Reports (9 tabs) | tap + scroll | Ctrl+R, F5 | no | ⚠️ fixed-width table columns |
| Settings (`settings_screen.dart`) | tap only | — | no | ✅ mostly |
| Login / Welcome (`login_screen.dart`) | tap only | autofocus PIN, Enter submit | no | ✅ (numeric field works on touch) |

### 1.2 Interaction-pattern findings

**Hover interactions — LOW risk.**
Only 7 files use hover-capable widgets (`InkWell`/`MouseRegion`/`GestureDetector` sweep). The only functional hover usage is the row-hover highlight in `AppDataTable` (`lib/core/widgets/desktop_components.dart:321`) — cosmetic; nothing is *gated* behind hover.

**Tooltips — MEDIUM risk.** 47 `tooltip:` usages across 25 files. On touch, tooltips require long-press, which users don't discover. Critically, some tooltips are the *only* explanation of disabled states — e.g. `lib/modules/repairing/presentation/widgets/repair_jobs_row_actions.dart:65-69` explains *why* "Mark Delivered" is disabled solely via tooltip text. A touch user sees a dead button with no feedback.

**Right-click / context menus — NONE. ✅**
Zero `onSecondaryTap` / custom context-menu usages. Row actions use explicit buttons or `PopupMenuButton` (tap-triggered — touch-safe): `purchase_history_tab.dart:296`, `daily_sales_tab.dart:203`, `customer_ledger_detail_screen.dart:165`.

**Keyboard shortcuts — extensive, but with touch fallbacks.**
Global layer at `lib/core/shortcuts/app_shortcut_manager.dart:77-107`: Ctrl+F, F2, F5, F10, Esc, Ctrl+L/B/R/I/S, F1. Sales adds ↑/↓, +/−, Delete (`sales_shortcut_helpers.dart`). Dialogs bind Enter/Esc (`desktop_components.dart:484-521`). **Every shortcut action has an on-screen equivalent** (nav rail, qty steppers, Complete Sale button, dialog buttons), so shortcuts are accelerators, not gates. The F1 help dialog (`keyboard_shortcuts_dialog.dart`) is desktop-culture UI but harmless on touch.

**Mouse-only interactions — NONE found.** All primary actions are single-tap (buttons, row `onSelectChanged`, chips).

**Drag & drop — one benign usage.** `ReorderableListView.builder` in `kpi_customize_dialog.dart:57` (KPI reorder). Long-press drag works on touch; acceptable.

**Scroll-wheel dependency — LOW risk.** All scrollables use standard `ScrollController` + `Scrollbar(thumbVisibility: true)`; touch drag works out of the box. The horizontal product bar even provides explicit arrow buttons (`product_grid_widget.dart:90-103`) that double as touch affordances.

**Focus management — HIGH risk (the core problem).**
- `GlobalScannerInput` (`global_scanner_input.dart:28-31`) runs a **500 ms periodic timer** that re-focuses a hidden 1×1, opacity-0 `TextField` whenever `primaryFocus` is null or a bare `FocusScopeNode`. Its `keyboardType: TextInputType.number` (`:127`) means **on any touch platform the OS will raise the numeric on-screen keyboard whenever this field takes focus** — i.e., at app start and within 500 ms of the user dismissing the keyboard or unfocusing any field.
- Sales uses `FocusTraversalOrder`/`NumericFocusOrder` (`sales_billing_screen.dart:538-687`) and programmatic `requestFocus` after adds (`:124`, `:215-221`) — designed for a physical-keyboard rhythm; on touch each `requestFocus` on a `TextField` will also summon the virtual keyboard mid-flow.

**Why these fail on touch, summarized:** touch platforms bind *focus on an editable field* to *show the IME*. The app treats focus as a free, invisible resource it can grab at will (scanner reclaim, search re-focus after every cart add). On desktop that's invisible; on touch every grab is a full-screen-third keyboard animation.

---

## Part 2 — Responsive Layout Audit

### 2.1 What exists (genuinely good foundations)

- **Shared responsive table system** — `lib/core/widgets/responsive_table_layout.dart` centralizes width tiers (≥1600 wide / ≥1220 medium / below = "compact") controlling column spacing, row heights, and *column hiding* (`showMediumColumns` / `showCompactColumns`). Reused by Reports (`report_table_styling.dart:18-30`), Inventory (`stock_table_widget.dart:36`), Repairs, Dealer Issues.
- **Adaptive grids** — Dashboard KPI grid: 4/3/2/1 columns at 1500/1100/760 (`dashboard_kpi_grid.dart:60-76`); brand stock: 8/6/4/3 columns at 1500/1200/800/520 (`brand_stock_section.dart:34-37`); repair KPIs likewise (`repairing_kpi_row.dart:61-65`).
- **`LayoutBuilder`/`MediaQuery`** in 28 files (33 usages) — breakpoints are constraint-driven, not window-size guesses.
- **Correct `Expanded`/`Flexible` composition** — e.g., Sales gives the cart `Expanded` and only the side panel a fixed width (`sales_billing_screen.dart:554-729`).
- Content max-width clamp at 2200 px for huge monitors (`desktop_components.dart:531-545`).

### 2.2 Where it breaks

| Finding | Evidence | Breaks at |
|---|---|---|
| **Lowest breakpoint tier is still desktop-sized.** "Compact" table tier is *everything below 1220 px* — it still lays out 6+ fixed-width columns designed for ~1000 px. | `responsive_table_layout.dart:40-67`; column width switches in `stock_table_widget.dart`, `purchase_history_tab.dart:159-295`, `expenses_tab.dart:490-576` (360 px description column) | < ~1000 px |
| **Fixed-width dialogs up to 980 px.** `SizedBox(width: N)` inside `AlertDialog` content: 980 (`sales_invoice_dialog.dart:21`), 960 (`dashboard_sales_invoice_dialog.dart:22`), 920 (`purchase_detail_dialog.dart:21`), 860 (`inventory_screen.dart:561`), 820 (`invoice_print_preview_dialog.dart:57`), 800, 700, 640, 560×6, 520×5, 420×12… none clamp to `MediaQuery` size. | grep `width: \d{3,}` — 100+ hits, ~40 of them dialog widths | portrait tablet (~750–800 lp) and split-screen |
| **Sales/Purchase split view floors.** Right panel fixed 300/320/360 px at <1200/≥1200/≥1500 (`sales_billing_screen.dart:557-561`, `purchase_screen.dart:322-324`); no single-column stacking mode below that. | | < ~900 px the cart/table area starves |
| **No `SafeArea` anywhere in `lib/`.** Fine for Windows; on Android the nav rail and top bar will sit under status bar/display cutouts. | grep `SafeArea` → 0 hits | all Android |
| **No `OrientationBuilder`, no portrait designs.** Every layout assumes landscape. | grep → 0 hits | tablet portrait |
| **Fixed heights.** Product stock bar hard-coded to 118 px with 168/180 px card extents (`product_grid_widget.dart:44, 57`); top bar fixed 56 px (`desktop_components.dart:110`). | | large text scales / small heights |
| **Windows runner fixes the initial window to 1366×768** (`windows/runner/main.cpp:29`) — coincidentally *below* the 1600 "wide" tier and just above table-medium, so the app already ships in its middle tier. No minimum-size enforcement found; shrinking the window below ~1000 px produces the overflow risks above. | | |

**Screen-by-screen layout notes**

- **Dashboard** — best-in-class here; grid tiers go down to 1 column at <760 (`dashboard_screen.dart:159-174`). Would survive a tablet with cosmetic issues only.
- **Sales** — three fixed vertical bands (search / 118 px product bar / cart+panel row). Works ≥1200; degrades but survives to ~900; below that the fixed 300 px right panel makes the cart unusable.
- **Purchase** — same skeleton as Sales (`purchase_screen.dart:322-348`), plus a wide items table with 120 px input cells (`purchase_items_table.dart:208`).
- **Inventory** — search/filter header + `AppDataTable`; compact tier hides brand/cost columns (`stock_table_widget.dart:100-121`). OK to ~1000 px.
- **Repairs** — KPI row adapts; jobs table has a 5-button action cluster per row (Part 3).
- **Reports** — 9 tabs share `report_table_styling.dart`; fixed column widths sum to ~1100+ px in Purchase History and Daily Sales; the 980/920 px detail dialogs open from here.
- **Master Data** — 4 side-by-side/tabbed panels with 560 px form dialogs; forms are short, dialogs would fit landscape tablets.
- **Settings** — single scrolling column with 420–460 px cards (`settings_screen.dart:285-593`); most tablet-friendly screen.

---

## Part 3 — Touch Target Audit

Material Design minimum: **48×48 dp** (Windows fluent guidance: 40×40 min, 48 recommended for POS-style use).

| Widget class | Evidence | Effective size | Verdict |
|---|---|---|---|
| **All Material controls (global)** | `visualDensity: VisualDensity.compact` — `app_theme.dart:22` | −8 dp on both axes vs. default for buttons, checkboxes, radios, list tiles | ❌ systemic |
| **All text inputs (global)** | `isDense: true` — `app_theme.dart:60`, `appDesktopInputDecoration` (`desktop_components.dart:18`), 60+ per-field `isDense` | ~40 dp tall | ⚠️ borderline |
| Filled/Outlined buttons | `padding: vertical: AppSpacing.md` (12) — `app_theme.dart:96,104` | ~40–44 dp | ⚠️ borderline |
| **Row-action icon buttons** | `Icon(..., size: 18)` + `VisualDensity.compact`, 6 px gaps, up to 4 per row — `repair_jobs_row_actions.dart:33-82` | ~34–38 dp, tight cluster | ❌ high mis-tap risk (Archive sits next to Mark Delivered) |
| **Cart qty stepper** | compact `IconButton`s with 6 px padding — `cart_table_widget.dart:362-380`; delete icon 44 px to the right at `:196-201` | −/+ ~36 dp; delete adjacent to line total | ❌ mis-tap: "−" vs. row-select vs. delete |
| **Product bar cards** | `minimumSize: Size.zero, tapTargetSize: shrinkWrap` — `product_grid_widget.dart:163-164` | as small as text renders; 10–12 px fonts | ❌ these are the *primary sale-entry* touch targets |
| Top-bar chips / help | `materialTapTargetSize: shrinkWrap`, 16–18 px icons — `desktop_navigation_shell.dart:194-258` | ~28–32 dp | ❌ (low frequency, low impact) |
| Data table rows | min 38–46 px default (`desktop_components.dart:244-245`), 40–60 responsive (`responsive_table_layout.dart:42-63`), theme floor 40 (`app_theme.dart:129`) | 38–52 dp | ⚠️ wide tier passes; compact tier fails |
| NavigationRail destinations | Material default sizing, `minWidth: 76` (`app_theme.dart:114`) | ✅ passes | ✅ |
| Checkboxes/dropdowns in dialogs | compact density + `dense: true` list tiles (`app_searchable_dropdown_field.dart:220,233`, `kpi_detail_sheet.dart:229`) | ~36–40 dp | ❌ |

**Dense-layout hotspots:** repair job rows (5 icons), cart item card (5 interactive elements in one row: select / − / + / price field / delete), master-data panel rows (2 compact icon buttons, `brands_panel.dart:327-339`).

**Compliance summary:** the app has effectively a **desktop density profile baked into the theme**. The single highest-leverage fix for touch is a runtime density/touch profile (see Part 12, R-01/R-02) — most controls are standard Material widgets and would inflate automatically.

---

## Part 4 — Text Input Audit

**Positives (genuinely Android-ready):**
- **Numeric keyboards are consistently declared** — 57 `keyboardType`/`TextInputType` usages in 25 files. Price/qty/discount fields use `TextInputType.numberWithOptions(decimal: true)` (`cart_table_widget.dart:233`, `totals_panel_widget.dart`, `payment_section_widget.dart`); PIN uses number + `digitsOnly` + length 6 (`pin_input_field.dart:32-38`); OTP recovery similar (`recovery_code_dialog.dart`).
- **Input validation is formatter-based**, not keystroke-event-based: `FilteringTextInputFormatter` (`cart_table_widget.dart:234-238`), CNIC/IMEI helpers (`cnic_helpers.dart`, `imei_helpers.dart`) — all IME-safe.
- `textInputAction` is set (search/done), enabling correct virtual-keyboard action buttons (`desktop_components.dart:167`, `global_scanner_input.dart:128`).
- Form dialogs wrap content in `SingleChildScrollView` (`imei_entry_widget.dart:127`, `product_form_dialog.dart`), so `AlertDialog`'s built-in viewport-inset handling gives basic keyboard avoidance for free.

**Problems:**

1. **Keyboard summoning/dismissal is broken by design** — the scanner focus timer (Part 1) means the numeric keyboard reappears ≤500 ms after any dismissal. **This single widget makes every form on a touch device malfunction.**
2. **IMEI entry assumes paste/scan of multi-line text** — `ImeiEntryWidget` parses newline/comma-separated bulk text (`imei_entry_widget.dart:66-92`). Fine with a wedge scanner or clipboard; typing 15-digit IMEIs on a virtual keyboard into a multiline field is error-prone. A camera-scan path feeds naturally into the same parser later.
3. **Focus traversal (`FocusTraversalOrder`, `NumericFocusOrder`)** is tuned for Tab-key flows (`sales_billing_screen.dart:538, 629, 664, 686`); harmless on touch but the F2 "focus payment" accelerator has no touch-visible equivalent hint.
4. **No `scrollPadding` tuning or `viewInsets` handling** outside dialogs — full-screen forms (settings, ledger detail filter rows) could be obscured by the IME on tablets.
5. **Search fields auto-refocus after actions** (`_focusSearchAfterAdd`, `sales_billing_screen.dart:215-221`) — desirable on desktop, keyboard-thrash on touch.

---

## Part 5 — Data Grid Audit

All tables funnel through **`AppDataTable`** (`desktop_components.dart:235-443`): sticky-header dual-`DataTable` when height-bounded, `PaginatedDataTable` at ≥80 rows (`:355-370`), zebra striping, hover highlight.

| Question | Answer | Evidence |
|---|---|---|
| Can rows be selected by touch? | **Yes** — `DataRow.onSelectChanged` and `onRowTap` patterns are plain taps | `desktop_components.dart:310`, `stock_table_widget.dart:17-23` |
| Does horizontal scrolling work? | **There is none.** Tables *hide columns* by width tier instead of scrolling horizontally. Only two horizontal scrollables exist (product bar, purchase items strip: `purchase_screen.dart:565`) — both drag-scrollable on touch | `responsive_table_layout.dart`; grep `Axis.horizontal` → 2 hits |
| Can buttons inside rows be tapped? | **Physically yes, reliably no** — 18 px compact icons in 4–5-button clusters (Part 3) | `repair_jobs_row_actions.dart` |
| Is row height sufficient? | Wide tier (52–60 px) ✅; default/compact (38–48 px) ❌ for touch | `desktop_components.dart:244-245`, `responsive_table_layout.dart` |
| Can context-menu actions be replaced? | Already replaced — inline buttons and tap-triggered `PopupMenuButton`s; no right-click anywhere | Part 1.2 |
| Vertical scrolling on touch? | ✅ standard scrollables + always-visible scrollbars | `desktop_components.dart:394-410` |

**Recommendations:** raise `dataRowMinHeight` to ≥52 in a touch profile; replace icon clusters with a row overflow menu (or swipe actions) on compact tiers; the pagination controls of `PaginatedDataTable` are touch-friendly already; consider card-list rendering below ~700 px (the codebase already has the pattern — the Sales cart is a card list, `cart_table_widget.dart:51-69`).

---

## Part 6 — Dialog Audit

Inventory of surfaces: ~35 `AlertDialog`s, **1** bottom sheet (`kpi_detail_sheet.dart:21`), 3 `PopupMenuButton`s, 12 `showDatePicker` call sites, 0 time pickers, shared `AppConfirmationDialog`.

| Check | Finding |
|---|---|
| Touch friendliness | Dialog *buttons* are standard `TextButton`/`FilledButton` — acceptable. Dialog *content* is dense (Part 3). |
| Button spacing | Standard `AlertDialog.actions` spacing — ✅ |
| Close behavior | Esc + barrier tap + explicit Cancel; `barrierDismissible: false` only on progress/critical dialogs (`repairing_action_service.dart:17,35`, `settings_screen.dart:563,587`) — correct pattern for touch too ✅ |
| Enter/Esc bindings | `AppConfirmationDialog` (`desktop_components.dart:484-521`) — accelerators only; buttons remain — ✅ |
| Date pickers | Material `showDatePicker` — fully touch/tablet compatible ✅ |
| **Landscape tablet (~1280×800)** | Dialogs ≤700 px fit; 820/860/920/960/980 px dialogs clip or overflow |
| **Portrait tablet (~800×1280)** | Every dialog ≥560 px risks horizontal overflow; the five invoice/detail dialogs (920–980 px) are unusable |
| Bottom sheets | The one usage (KPI detail) is the *right* tablet pattern — a model to extend |

**Core defect:** widths are constants (`SizedBox(width: 980)`) instead of `min(constant, MediaQuery.sizeOf(context).width - inset)`. This is a mechanical, low-risk fix repeated ~40 times.

---

## Part 7 — Navigation Audit

**Structure** (`lib/core/routing/app_router.dart`): `go_router` 14 with `StatefulShellRoute.indexedStack` — 9 flat branches, each a single screen, wrapped by `DesktopNavigationShell` (permanent `NavigationRail`). Two pushed detail screens exist (customer/supplier ledger, with `PopScope` at `customer_ledger_detail_screen.dart:128`). A leave-guard protects the sales cart (`navigation_leave_guard.dart`).

| Aspect | Status |
|---|---|
| Desktop assumptions | Permanent sidebar always visible; no drawer/modal/bottom variant. Rail auto-extends ≥1600 px (`desktop_components.dart:88-91`). At tablet-portrait widths the 76 px rail is tolerable but unaccounted for. |
| Keyboard navigation | Ctrl+S/I/R/B accelerators + Esc→`maybePop` (`app_shortcut_manager.dart:143-147`) — accelerators only ✅ |
| Back navigation | Almost no back stack exists (IndexedStack tabs). On Android, the hardware/gesture back would immediately background the app from any tab — no `PopScope` at shell level to confirm exit, and no in-app back affordance except the 2 ledger screens. |
| Touch gestures | None required, none supported (no swipe-between-tabs, no pull-to-refresh — refresh is F5/buttons). Acceptable. |
| Navigation stack | `go_router` is fully Android-compatible; predictive-back needs the shell `PopScope` work. |
| Future Android | The flat-tabs + rail model maps cleanly to `NavigationDrawer`/`NavigationBar` adaptive switch. **A config seam already exists**: `AppNavigationMode` enum (`lib/core/config/navigation_mode.dart`) with `sidebar`/`dashboardLauncher` — evidence the team planned alternative nav modes. |

**Risk: LOW-MEDIUM.** Navigation is the *easiest* subsystem to adapt.

---

## Part 8 — Barcode Scanner Audit

**Architecture (layered — this is well designed):**

```
GlobalScannerInput (hidden TextField + 500ms focus timer)   ← ONLY wedge-coupled layer
        ↓ submitRawScan(raw)
ScannerController (Riverpod StateNotifier, per-route modes) ← transport-agnostic
        ↓
ScannerService.normalizeAndValidate                          ← pure Dart, unit-tested
        ↓
ScannerModeRouter → mode handlers (sales / purchase / inventory / dealer-return)
```
Files: `lib/modules/scanner/presentation/widgets/global_scanner_input.dart`, `controller/scanner_controller.dart`, `services/scanner_service.dart`, `services/scanner_mode_router.dart`; tests in `test/unit/scanner_service_test.dart`, `test/integration/scanner_mode_handlers_integration_test.dart`.

| Question | Assessment |
|---|---|
| USB scanner (keyboard wedge) | ✅ Works today on Windows — that's the whole design. Digits-only, 8–20 length, control-char stripping, "finish" sentinel `9999999999999` (`scanner_service.dart:9-49`). |
| Bluetooth scanner | ✅ HID-mode BT scanners present as keyboards → works unchanged on Windows. ⚠️ On Android, HID scanners work **but** the focused-hidden-TextField trick still summons the IME; Android apps normally suppress it (`TextInputType.none` / raw key listener). |
| Android camera scanning | **Feasible with low friction**: a camera widget (e.g. `mobile_scanner`) needs only to call `scannerControllerProvider.notifier.submitRawScan(value)` — the entire validation/mode pipeline is reused untouched. |
| Keyboard-wedge assumptions | Confined to one widget (**good**), but that widget is mounted globally in the shell (`desktop_navigation_shell.dart:175`) and owns the focus-stealing timer (**bad**, see Parts 1/4). |
| Focus handling | The reclaim policy (`global_scanner_input.dart:55-72`) is the single most touch-hostile code path in the app. |
| Service architecture | ✅ Transport-agnostic core; recommend formalizing a `ScannerTransport` interface with `WedgeTransport` (current widget, desktop-only) and future `CameraTransport`/`HidTransport` implementations selected per platform. |

**Migration effort:** the pipeline needs ~0 changes; the transport layer needs 1 new widget + a platform switch + IME suppression (`keyboardType: TextInputType.none` on Android for wedge mode). **Estimated: days, not weeks** — the abstraction already exists.

---

## Part 9 — Window Management & Windows-Specific Code

| Item | Finding |
|---|---|
| `dart:io` usage | **8 files only**: `cloud_backup_service.dart`, `printer_service.dart` (file spool), `csv_export_service.dart`, `startup_health_service.dart`, `kpi_preferences_service.dart`, `invoice_print_preview_dialog.dart`, `app_database.dart` (WAL sidecar cleanup), `database_backup_service.dart`. **All are `File`/`Directory` operations — every one is valid on Android.** No `Process.run`, no sockets. |
| `Platform.isX` branches | **Zero.** |
| Win32 / FFI packages | **None** in `pubspec.yaml`. No `window_manager`, no `win32`, no `ffi` direct dependency. |
| Storage roots | `path_provider` everywhere: `getApplicationSupportDirectory()` (`database_provider.dart:18`, `printing_providers.dart:138`), `getApplicationDocumentsDirectory()` (`kpi_preferences_service.dart:12`, `invoice_print_preview_dialog.dart:233`). ✅ Android-compatible. |
| Window sizing | Only in the native runner: `Win32Window::Size size(1366, 768)` (`windows/runner/main.cpp:29`) — standard Flutter template, no custom min/max enforcement, irrelevant to other platforms. |
| Mouse-cursor logic | None beyond framework defaults. |
| Desktop launch code | Standard template `flutter_window.cpp`/`win32_window.cpp` — untouched boilerplate. |
| Platform folders | **Only `windows/` exists.** No `android/`, `ios/`, `linux/`, `macos/`, `web/` — Android support requires `flutter create --platforms=android .` plus signing/manifest work. |
| Printing | `FileSpoolPrinterService` writes receipt text files to a spool dir (`printer_service.dart:26-85`) — an external agent presumably prints them on Windows. **This model has no Android equivalent**; Android would use the already-included `printing` package (which supports Android natively) or ESC/POS over BT. |

**Migration difficulty for this part: LOW.** This is the cleanest Windows-first Flutter codebase layer audited — the team clearly wrote services to be portable (see also `AppPlatformTarget.futureAndroidCompanion` in `app_environment.dart:3`, proving intent).

---

## Part 10 — Platform Dependency Matrix

From `pubspec.yaml` (10 direct dependencies — remarkably lean):

| Package | Windows | Android | Tablet concerns | Action needed |
|---|---|---|---|---|
| `flutter_riverpod` 2.5 | ✅ | ✅ | none | — |
| `go_router` 14.2 | ✅ | ✅ | none | predictive-back config only |
| `crypto`, `path`, `http` | ✅ | ✅ | none | — |
| **`sqflite_common_ffi` 2.4** | ✅ | ⚠️ technically runs via FFI, but non-standard on Android | — | Swap to `sqflite`'s native factory on Android. **Trivial**: the app already isolates this behind `LocalDatabaseService` (`sqlite_service.dart:5-9`) — one new 20-line implementation + a platform switch in `database_provider.dart`. |
| `path_provider` 2.1 | ✅ | ✅ | none | — |
| **`file_selector` 1.0** | ✅ | ⚠️ partial | `openFile` ✅; **`getDirectoryPath` returns SAF content-URIs on Android that `dart:io File` cannot write to.** Used by CSV export (`report_export_action_widget.dart:34` → `csv_export_service.dart:24-30` writes `File(p.join(...))`) and stock export (`brand_stock_section.dart:42`), backup folder pick (`settings_screen.dart:947`). | On Android: export to app documents + system share sheet (`share_plus`), or adopt SAF-aware writing. Medium-small task. |
| `pdf` 3.11 | ✅ | ✅ (pure Dart) | none | — |
| `printing` 5.13 | ✅ | ✅ | Android print framework supported | Route receipts through `printing` on Android instead of the file spool. |
| *(spool-print model — not a package)* | ✅ | ❌ | — | Needs `PrinterService` Android implementation (abstraction exists). |

**Desktop-only/Windows-only plugins: none. Plugins unsupported on Android: none outright — two behavioral gaps (`file_selector` directories, spool printing).** No replacements required, only additional platform implementations behind existing interfaces.

---

## Part 11 — Responsive Architecture Score

| Dimension | Score | Justification (evidence) |
|---|---|---|
| Responsive Layout | **4/10** | Real breakpoint system exists and is consistently reused (`responsive_table_layout.dart`, KPI grids), but every tier targets desktop widths; ~40 fixed-width dialogs (up to 980 px); no `SafeArea`/orientation handling; fixed 118 px product bar. |
| Touch Support | **3/10** | No hover/right-click/drag gates (good), buttons back every shortcut (good) — but global `VisualDensity.compact` + `isDense` + shrink-wrapped 18 px targets put nearly all controls under 48 dp, and the scanner focus timer is actively touch-hostile. |
| Android Readiness | **2/10** | No `android/` folder; scanner IME storm; SAF-incompatible exports; spool printing has no Android path. Offset by: `path_provider` roots, portable `dart:io` usage, DB abstraction, `printing` already a dependency. |
| Tablet Readiness | **4/10** | Landscape ≥1200 px mostly works today; portrait breaks dialogs and split views; one bottom sheet shows the target pattern exists. |
| Desktop Independence | **6/10** | Zero Win32/FFI/platform branches; services abstracted (`LocalDatabaseService`, `PrinterService`); only the wedge-scanner transport and file-spool printing are desktop-bound. |
| Input Flexibility | **5/10** | Excellent keyboard layer that never *gates* functionality; scanner pipeline transport-agnostic; but single input transport implemented, focus model assumes physical keyboard. |
| Accessibility | **2/10** | Exactly 2 `Semantics` usages in 347 files (`imei_picker_dialog.dart:201,207`); compact density harms motor accessibility; tooltip-only disabled-state explanations; no large-text audit (fixed 10–12 px fonts in product cards). |
| Maintainability | **8/10** | Clean modular architecture (domain/data/presentation per module), design tokens (`AppSpacing`, `AppRadii`, semantic colors), shared component library, 100+ test files including keyboard/focus and scanner integration tests. Changes proposed below are *localized* thanks to this. |
| **Overall** | **43/100** | *(34/80 scaled)* — "portable core, desktop-bound shell." |

---

## Part 12 — Risk Analysis

### CRITICAL

| ID | Location | Problem | Impact | Future risk | Recommended fix | Complexity |
|---|---|---|---|---|---|---|
| C-01 | `global_scanner_input.dart:28-31, 55-72, 110-141` | Hidden autofocus `TextField` + 500 ms focus-reclaim timer (keyboard-wedge transport) | On touch: virtual keyboard opens at launch and re-opens ≤500 ms after every dismissal; steals focus from form fields between ticks | Blocks *all* touch/Android targets; nothing else matters until fixed | Introduce `ScannerTransport` abstraction; on touch platforms use `TextInputType.none` + `Focus`/`KeyboardListener` wedge mode, or camera transport; gate the reclaim timer to desktop + hardware-keyboard sessions | **Medium** (pipeline unchanged; 1 widget + platform switch) |
| C-02 | No `android/` platform folder (repo root) | Android target does not exist | Cannot build for Android at all | — | `flutter create --platforms=android .`, manifest/signing, CI lane | **Low** (mechanical) but unlocks everything |

### HIGH

| ID | Location | Problem | Impact | Future risk | Recommended fix | Complexity |
|---|---|---|---|---|---|---|
| H-01 | `app_theme.dart:22,60`; `product_grid_widget.dart:163-164`; `repair_jobs_row_actions.dart`; `cart_table_widget.dart:362-380` | Global compact density; shrink-wrapped primary targets; 18 px row icons | Sub-48 dp targets everywhere → mis-taps on money-touching actions (delete cart line, archive job) | Every touch device | Add an input-mode–aware density profile: `VisualDensity.adaptivePlatformDensity` or a settings toggle ("Touch mode") switching density/`isDense`/row heights via theme | **Low-Medium** (theme-level; verify layouts don't overflow at comfortable density) |
| H-02 | ~40 dialogs, e.g. `sales_invoice_dialog.dart:21` (980), `dashboard_sales_invoice_dialog.dart:22` (960), `purchase_detail_dialog.dart:21` (920) | Hard-coded dialog widths | Overflow/clipping below ~1000 px; unusable on portrait tablets | All tablets | Shared `AppDialogShell` that clamps width to `min(target, screenWidth − 2×inset)` and switches to full-screen dialog / bottom sheet under ~700 px | **Low** (mechanical, repetitive) |
| H-03 | `csv_export_service.dart:24-30` + `report_export_action_widget.dart:34`, `brand_stock_section.dart:42`, `settings_screen.dart:947` | `getDirectoryPath()` + `dart:io File` writes | Exports and backup-folder selection break on Android (SAF content URIs) | Android only | On Android: write to app storage + share sheet; keep folder-pick on desktop behind the existing service seam | **Low-Medium** |
| H-04 | `sqlite_service.dart` / `database_provider.dart:18` | FFI-only database factory | Non-standard SQLite stack on Android | Android only | Second `LocalDatabaseService` impl returning `sqflite`'s factory; select by platform | **Low** (abstraction already in place) |

### MEDIUM

| ID | Location | Problem | Impact | Recommended fix | Complexity |
|---|---|---|---|---|---|
| M-01 | `responsive_table_layout.dart:40-67` + per-tab fixed column widths (`expenses_tab.dart:490-576`, `purchase_history_tab.dart:159-295`) | No tier below ~1000 px; fixed columns | Tables overflow/cram on tablet portrait | Add a ≤900 px tier that switches to card-list rendering (pattern already exists in the sales cart) | **Medium** |
| M-02 | `sales_billing_screen.dart:557-561`, `purchase_screen.dart:322-324` | Fixed 300–360 px right panels, no stacking | Sales/Purchase unusable < ~900 px | Below breakpoint, move totals/payment to a bottom sheet or second step | **Medium** |
| M-03 | `printer_service.dart` (file spool) | No Android print path | Receipts can't print on Android | `PrinterService` impl using `printing` package (already a dependency) or BT ESC/POS | **Medium** |
| M-04 | Shell (`app_router.dart:103`, no `PopScope` at shell) | Android back button backgrounds the app from any tab; no exit confirm; `didRequestAppExit` (`main.dart:62`) is desktop-only | Data-loss-adjacent UX on Android | Shell-level `PopScope` mirroring the cart leave-guard + exit confirm | **Low** |
| M-05 | 47 tooltips, e.g. `repair_jobs_row_actions.dart:65-69` | Disabled-state reasons are hover-only | Touch users get dead buttons with no explanation | Surface reasons inline (helper text) or on-tap snackbar for disabled actions | **Low** |
| M-06 | No `SafeArea` in `lib/` | Status-bar/cutout overlap on Android | Cosmetic-to-functional | `SafeArea` in `AppDesktopScaffold` | **Trivial** |

### LOW

| ID | Location | Problem | Fix | Complexity |
|---|---|---|---|---|
| L-01 | `product_grid_widget.dart:44,57,176-186` | Fixed 118 px bar, 10–12 px fonts on primary sale buttons | Scale with breakpoint/text scale | Low |
| L-02 | 2 `Semantics` usages app-wide | Screen-reader support effectively absent | Label icon buttons/tables incrementally | Medium (spread) |
| L-03 | `desktop_components.dart:110` | Fixed 56 px top bar | MediaQuery-derived height | Trivial |
| L-04 | `keyboard_shortcuts_dialog.dart` | Help content assumes physical keyboard | Hide/replace in touch mode | Trivial |
| L-05 | `main.cpp:29` | 1366×768 initial window, no min size | Set minimum window size on Windows | Trivial |

---

## Part 13 — Migration Estimate

Assumes one developer familiar with the codebase; test effort included. The clean module boundaries and existing widget/integration test suite (e.g. `test/widget/phase2_purchases_p038_p039_keyboard_focus_test.dart`, `test/integration/scanner_mode_handlers_integration_test.dart`) materially reduce regression risk.

### Target 1 — Windows Touch Laptop (landscape, ≥1366 px, keyboard still present) — ✅ COMPLETED (see Implementation Progress)

| Area | Work | Estimate |
|---|---|---|
| Architecture | None required | 0 |
| UI | Touch density profile (H-01); dialog width clamps (H-02); row-action target sizes; disabled-state feedback (M-05) | 2–3 weeks |
| Input | Scanner focus policy — keep wedge transport but stop IME summoning / focus theft when touch input detected (C-01 partial) | 3–5 days |
| Plugins | None | 0 |
| Testing | Widget tests for density profile; manual touch pass per screen | 1 week |
| **Total** | | **~3–4 weeks · Complexity: LOW-MEDIUM** |

### Target 2 — Windows Tablet (touch-primary, portrait possible, ~800–1280 px) — 🔨 IN PROGRESS

Everything in Target 1, plus:

| Area | Work | Estimate |
|---|---|---|
| Architecture | Adaptive navigation (rail ↔ bar/drawer via existing `AppNavigationMode` seam); on-screen-keyboard-aware layouts | 1–2 weeks |
| UI | Sub-1000 px tier: stack Sales/Purchase panels (M-02); card-list tables (M-01); full-screen dialogs (H-02 extension); portrait passes on all 10 screens | 3–4 weeks |
| Plugins | None | 0 |
| Testing | Portrait/landscape matrix, IME-overlap tests | 1–2 weeks |
| **Total (incremental over Target 1)** | | **~5–8 weeks · Complexity: MEDIUM** |

### Target 3 — Android Tablet

Everything in Targets 1–2, plus:

| Area | Work | Estimate |
|---|---|---|
| Architecture | `android/` bootstrap (C-02); DB factory swap (H-04); lifecycle/back handling (M-04); `SafeArea` (M-06); session/keep-alive review (500 ms timers vs. Doze) | 2–3 weeks |
| Input | `ScannerTransport` completion: camera scanning (`mobile_scanner`) feeding `submitRawScan`, HID-scanner IME suppression (C-01 full) | 2–3 weeks |
| Plugins | SAF-safe export/share (H-03); Android `PrinterService` via `printing` or BT ESC/POS (M-03) | 2–3 weeks |
| UI | Android polish: predictive back, splash, adaptive icons, text-scale audit | 1–2 weeks |
| Testing | Device matrix, DB migration verification on Android, printer/scanner hardware testing | 2–3 weeks |
| **Total (incremental over Targets 1–2)** | | **~9–14 weeks · Complexity: MEDIUM-HIGH** |

**Cumulative to full Android tablet support: roughly 4–6 months of focused work — a refactor program, not a rewrite.** No module's domain/data layer needs to change.

---

## Part 14 — Final Verdict

**Can the existing application support touch devices today?**
*Partially.* A user can operate every workflow by tapping — no feature is gated behind hover, right-click, or keyboard. But they will fight the scanner focus timer (C-01), mis-tap sub-40 dp controls on money-touching actions (H-01), and hit clipped 900+ px dialogs on smaller screens (H-02). "Works" ≠ "supported."

**Can it support Android tablets?**
*Not today* — the Android platform target literally does not exist in the repo (C-02), and four concrete blockers (scanner IME storm, SAF exports, spool printing, FFI-only DB factory) sit on top of that. *But* every blocker lands behind an abstraction the team already built (`LocalDatabaseService`, `PrinterService`, the transport-agnostic scanner pipeline, `path_provider` storage roots), which is why the estimate is months, not quarters.

**Is the architecture future-proof?**
The **service and data layers: yes** — zero platform branches, zero Win32 dependencies, lean dependency list, explicit future-Android intent (`AppPlatformTarget.futureAndroidCompanion`, `AppNavigationMode`). The **presentation input model: no** — it hard-codes three desktop assumptions (wedge scanner owns focus, compact density, ≥1000 px viewports) at the theme/shell level rather than behind capability checks.

**Recommendation: B — Moderate responsive refactor.**

- **Not A (minor UI improvements):** the scanner transport (C-01) and density system (H-01) are cross-cutting; touching them is more than cosmetics, and A would leave Android permanently out of reach.
- **B (chosen):** every identified fix is *localized by existing architecture* — one theme profile, one dialog shell, one transport interface, two service implementations, one sub-1000 px layout tier. The domain/data/business layers (the majority of the 54k lines, protected by the integration test suite) need **zero** changes. That is the definition of a moderate refactor.
- **Not C (major redesign):** the design system, navigation model, module structure, and component library are assets, not liabilities — the existing breakpoint system just needs one more tier, not replacement.
- **Not D (rewrite):** a rewrite would discard a clean, tested, portable core to fix problems that live in ~15 files of shell/theme/transport code. Evidence throughout this report shows the expensive parts (data integrity, scanner pipeline, printing queue, ledger logic) are already platform-neutral.

**Suggested sequencing:** Target 1 (touch profile + dialog clamps + scanner focus policy) ships value to Windows touch-laptop users in ~a month and de-risks everything after; Target 2's portrait tier then makes Windows tablets viable; Target 3 bootstraps Android on an already-touch-ready UI.

---

*All file/line references are to the repository state at audit time (branch base: `main`, July 2026). Line numbers may drift with future commits; widget and class names are stable anchors.*
