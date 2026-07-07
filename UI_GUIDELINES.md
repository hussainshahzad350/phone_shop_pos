# UI Design Guidelines — Phone Shop POS

> Design, color, and UI patterns only. No business logic here.
> Start here before building any new screen or widget.
> **Accuracy rule:** this file must describe what the code actually renders. If you change the theme or a core widget, update this file in the same PR.

---

## App Visual Style

**Soft Card Style** — Material 3 base, clean and light.

- Background: off-white (`#F6F8FC`) — not pure white, slight bluish tint
- Cards: translucent white (`82% opacity` light / `7% opacity` dark) + subtle shadow + border
- Primary accent: Indigo-blue (`#5167F6`, applied via `ColorScheme.fromSeed`)
- Corners: rounded (4px to 16px — depends on purpose)
- Glass/frosted blur: **components exist but are NOT wired into the app shell yet** — see §12 before using

---

## 1. Color Palette

### Primary Colors
| Token | Value | Where used |
|-------|-------|------------|
| Primary | seed `#5167F6` → `colorScheme.primary` | Buttons, active states, links |
| Scaffold background | `#F6F8FC` (light) / `colorScheme.surface` (dark) | Screen background |
| Card surface | `white @ 82%` (light) / `white @ 7%` (dark) | Cards |
| Card border | `#E3E8F2` (light) / `outlineVariant` (dark) | Card outline |
| Input fill | `#FAFBFE` (light) / `surfaceContainerHighest @ 35%` (dark) | Text field background |
| Input border | `#D7DBE7` (light) / `outlineVariant` (dark) | Text field outline |
| Input focused | `colorScheme.primary @ 1.2px` | Active input border |

> Never hardcode these hex values in widgets — they come from `app_theme.dart`. Hardcoding light-mode hex breaks dark mode (see the known issue in §7).

### Semantic Colors — ALWAYS use these for status
```dart
final semantic = Theme.of(context).semantic;

semantic.success          // #1B873F  — available, profit, complete
semantic.successContainer // #D7F4DF  — success background

semantic.warning          // #B7791F  — low stock, pending
semantic.warningContainer // #FCEBC9  — warning background

semantic.danger           // #D13438  — error, out of stock, loss
semantic.dangerContainer  // #FBDADB  — danger background

semantic.info             // #2F6FED  — neutral info
semantic.infoContainer    // #DBE7FE  — info background
```

Each role also has an `on*` pair (`semantic.onSuccess`, …) for text/icons placed **on** the solid color.

> Dark mode automatically uses different shades — hardcoding `Colors.green` etc. breaks in dark mode.
> **Don't rely on color alone** to communicate status — pair it with an icon or label (color-blind users, ~8% of men, cannot distinguish the success/danger pair).

---

## 2. Spacing — 4px Grid

```
xs = 4    sm = 8    md = 12    lg = 16    xl = 24    xxl = 32
```

```dart
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

// ✅ Use tokens
const SizedBox(height: AppSpacing.sm)   // 8
Padding(padding: EdgeInsets.all(AppSpacing.md))  // 12

// ✅ Pre-built gaps
AppSpacing.gapSm   // SizedBox 8×8
AppSpacing.gapMd   // SizedBox 12×12
AppSpacing.gapLg   // SizedBox 16×16

// ✅ Pre-built paddings
AppSpacing.paddingSm / paddingMd / paddingLg

// ❌ Magic numbers
const SizedBox(height: 8)
Padding(padding: EdgeInsets.all(12))
```

---

## 3. Corner Radii

```
xs = 4    sm = 8    md = 12    lg = 16
```

| Radius | Use |
|--------|-----|
| `AppRadii.lgRadius` (16) | Cards, dialogs, panels |
| `AppRadii.mdRadius` (12) | Buttons, chips, dropdowns |
| `AppRadii.smRadius` (8) | Inner containers, badges |
| `AppRadii.xsRadius` (4) | Table cells, tight elements |

```dart
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

borderRadius: AppRadii.lgRadius    // ✅
BorderRadius.circular(16)          // ❌
```

---

## 4. Typography

Scale is defined — do not use `fontWeight: FontWeight.bold` ad hoc. If text needs emphasis, pick the correct style from the scale instead.

| Style | Size | Weight | Where |
|-------|------|--------|-------|
| `titleLarge` | 17 | w600 | Page section headings |
| `titleMedium` | 15 | w600 | Card titles, dialog titles |
| `titleSmall` | 13 | w600 | Table headers, filter labels |
| `bodyLarge` | 15 | w400 | Primary body text |
| `bodyMedium` | 13 | w400 | Default text, list items |
| `bodySmall` | 12 | w400 | Secondary text, hints (muted) |
| `labelLarge` | 13 | w600 | Button labels |
| `labelMedium` | 12 | w600 | Chips, badges |
| `labelSmall` | 11 | w500 | Metadata, timestamps (muted) |

Larger display/headline styles (19–40px) also exist for KPI values and hero numbers — see `app_typography.dart`.

### Tabular figures — REQUIRED wherever money or counts render in columns
```dart
import 'package:phone_shop_pos/core/theme/app_typography.dart';

Text(
  FormattingHelpers.currencyPkr(1234),   // 'PKR 1,234.00'
  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
    fontFeatures: AppTypography.tabularFigures,  // digits stay aligned in columns
  ),
)
```

### Number & currency formatting
Always use `FormattingHelpers` (`lib/core/utils/formatting_helpers.dart`) — never `toStringAsFixed` inline:

```dart
FormattingHelpers.currencyPkr(amount)   // 'PKR 12,345.00'
FormattingHelpers.decimal(value)        // grouped: '12,345.00'
FormattingHelpers.dateYmd(dt)           // '2026-07-03'
FormattingHelpers.dateYmdHm(dt)         // '2026-07-03 14:05'
```

---

## 5. Cards

Comes automatically from the theme — just wrap with `Card()`:

```dart
Card(
  child: Padding(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: ...,
  ),
)
```

What you get automatically:
- `elevation: 1.5` — subtle shadow
- `borderRadius: 16` (AppRadii.lgRadius)
- Border: `#E3E8F2` (light) / `outlineVariant` (dark)
- Color: `white @ 82%` (light) / `white @ 7%` (dark)
- No surface tint (M3 elevation tint is off)
- `margin: EdgeInsets.zero` — add spacing with layout, not card margins

**Clickable cards:** wrap the content in `InkWell` **inside** the card and pass the matching radius, and give the user a visual cue (chevron, hover state):
```dart
Card(
  child: InkWell(
    onTap: _open,
    borderRadius: AppRadii.lgRadius,
    child: ...,
  ),
)
```

**Colored cards** (for status):
```dart
Card(
  color: Theme.of(context).colorScheme.secondaryContainer,  // ✅ theme-aware
  // or
  color: semantic.successContainer,  // ✅ semantic
  // ❌ avoid
  color: Colors.green.withOpacity(0.1),
)
```

---

## 6. Buttons

Three types — when to use which:

| Widget | When |
|--------|------|
| `FilledButton` / `FilledButton.icon` | Primary action — only one per screen |
| `OutlinedButton` / `OutlinedButton.icon` | Secondary action — multiple per page is fine |
| `TextButton` | Tertiary / destructive / cancel |

```dart
// Primary
FilledButton.icon(
  onPressed: _isLoading ? null : _submit,
  icon: const Icon(Icons.add),
  label: Text(_isLoading ? 'Saving…' : 'Save'),
)

// Secondary
OutlinedButton.icon(
  onPressed: _openScan,
  icon: const Icon(Icons.qr_code_scanner, size: 18),
  label: const Text('Scan'),
)

// Cancel / close
TextButton(
  onPressed: () => Navigator.of(context).pop(),
  child: const Text('Cancel'),
)
```

**Loading state pattern:**
```dart
FilledButton(
  onPressed: _isLoading ? null : _submit,      // null = disabled
  child: _isLoading
      ? const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : const Text('Submit'),
)
```

**Icon-only buttons:** always set `tooltip:` — it doubles as the accessible label:
```dart
IconButton(
  icon: const Icon(Icons.refresh, size: 18),
  tooltip: 'Refresh (F5)',
  onPressed: _refresh,
)
```

---

## 7. Form Fields

Default theme already styles inputs (filled, rounded, dense). Just follow these rules:

```dart
// Standard input
TextFormField(
  decoration: const InputDecoration(
    labelText: 'Field Name',
    // border, fill, radius come from the theme automatically
    // isDense: true also comes from the theme — don't write it explicitly
  ),
)

// With icon
InputDecoration(
  labelText: 'Search',
  prefixIcon: const Icon(Icons.search, size: 18),  // size: 18 for compact layout
)

// ❌ Avoid writing OutlineInputBorder() inline — the theme already has the right setup
// Only write it when you need to override something specific
```

> `appDesktopInputDecoration()` in `desktop_components.dart` is a thin theme-driven wrapper (label/hint/icons/isDense only) — borders and fill always come from the theme, so it is dark-mode safe.

**Dropdown:**
```dart
// ✅ Use initialValue (value is deprecated in Flutter 3.33+)
// ✅ Always pass borderRadius + menuMaxHeight so the popup opens as a compact,
//    rounded, scrollable panel instead of a full-height sheet with sharp corners
//    that covers the field. Tokens live in core/theme/app_spacing.dart.
DropdownButtonFormField<String>(
  initialValue: _selected,
  borderRadius: kAppDropdownMenuRadius,      // rounds the menu to match the field
  menuMaxHeight: kAppDropdownMenuMaxHeight,   // caps height → mouse/scrollbar scrolling
  decoration: const InputDecoration(labelText: 'Select'),
  items: [...],
  onChanged: (v) { if (v != null) setState(() => _selected = v); },
)
```

> The same two tokens apply to plain `DropdownButton<T>`. For a **typeable** search
> that must open anchored directly under the field (never overlapping it), follow
> the `CustomerSelectorWidget` / `SupplierSelectorWidget` pattern — an
> `OverlayPortal` + `CompositedTransformFollower` anchored list — rather than a
> `DropdownButton`.

**Search fields:** use `AppSearchField` (`core/widgets/desktop_components.dart`) — it wires the clear (×) button and `TextInputAction.search` for you.

---

## 8. Dialogs

```dart
AlertDialog(
  title: const Text('Title'),
  content: SizedBox(
    width: 420,        // narrow: 380-420  |  medium: 500-600  |  wide: 700
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [...],
    ),
  ),
  actions: [
    TextButton(                          // Cancel — always on the left
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Cancel'),
    ),
    FilledButton(                        // Confirm — always on the right
      onPressed: _isLoading ? null : _submit,
      child: Text(_isLoading ? 'Saving…' : 'Confirm'),
    ),
  ],
)
```

**Yes/No confirmations:** use `AppConfirmationDialog` — it already handles **Enter = confirm, Esc = cancel** and returns `bool`:

```dart
final confirmed = await showDialog<bool>(
  context: context,
  builder: (context) => const AppConfirmationDialog(
    title: 'Close app during active work?',
    message: '…',
    confirmLabel: 'Close App',
    cancelLabel: 'Stay Open',
  ),
);
```

> For **destructive** confirmations (void sale, delete record) do not let Enter be a silent yes — require the user to explicitly reach the confirm button, and style it with `semantic.danger`.

---

## 9. Status Badges

```dart
import 'package:phone_shop_pos/core/widgets/desktop_components.dart';

AppStatusBadge(
  label: 'Active',
  color: semantic.successContainer,
  foreground: semantic.success,
)

AppStatusBadge(label: 'Returned', color: semantic.warningContainer, foreground: semantic.warning)
AppStatusBadge(label: 'Sold', color: Theme.of(context).colorScheme.primaryContainer)
```

If `foreground` is omitted it is auto-derived from the background brightness.

---

## 10. Empty, Loading & Error States

Every async region needs all **three** states. Never leave a bare spinner or a dead-end error text.

### Empty
```dart
// ✅ Use this — not Center(Text('No data'))
AppEmptyState(
  message: 'No records found.',
  icon: Icons.inbox_outlined,       // optional, this is the default
  action: FilledButton(             // optional CTA
    onPressed: _openAdd,
    child: const Text('Add First'),
  ),
)
```

### Loading — skeletons for content, spinners for actions
```dart
import 'package:phone_shop_pos/core/widgets/app_skeleton.dart';

// Card/KPI areas while loading:
Row(children: const [
  Expanded(child: AppSkeletonCard()),
  AppSpacing.gapSm,
  Expanded(child: AppSkeletonCard()),
])

// Arbitrary placeholder line/block:
AppSkeleton(width: 120, height: 14)
```
Rule of thumb: **content areas skeleton** (they show the shape of what's coming), **buttons/short actions spin** (§6 loading pattern). Full-screen blocking work uses `AppLoadingOverlay(isLoading: …, child: …)`.

### Error — always offer a way out
Error branches of `AsyncValue.when` must show a short human message **and a Retry action** (usually `ref.invalidate(...)`). A plain `Text('Failed to load.')` with no action is not acceptable.

### Notifications / snackbars
All transient feedback goes through `AppNotifier` — never call `ScaffoldMessenger` directly (raw snackbars are unthemed and ignore the app's duration rules):

```dart
AppNotifier.success('Sale completed.');
AppNotifier.warning('Stock is low for this model.');
AppNotifier.error('Could not save. Try again.');
AppNotifier.errorFrom(error, operation: 'saving sale');  // maps exceptions to user-safe text
```

Durations are built in (success 3s, info 4s, warning 5s, error 6s + close icon).

---

## 11. Tables

Use `AppDataTable` — zebra rows, sticky header, and pagination are all automatic:

```dart
AppDataTable(
  columns: const [
    DataColumn(label: Text('#')),      // serial number — ALWAYS the first column
    DataColumn(label: Text('Date')),
    DataColumn(label: Text('Amount'), numeric: true),
  ],
  rows: items.asMap().entries.map((e) => DataRow(
    cells: [
      DataCell(Text('${e.key + 1}')),
      DataCell(Text(e.value.date)),
      DataCell(Text(e.value.amount)),
    ],
  )).toList(),
  emptyMessage: 'No records.',
)
```

**Table heading color:** `#EFF2FA` (light) — comes from theme automatically.
**Pagination:** switches to paginated mode automatically at 80+ rows (25/50/100 per page).
**Sticky header:** automatic whenever the table has a bounded height (inside `Expanded` or a fixed-height box). With unbounded height it falls back to whole-table scrolling.
**Money columns:** mark `numeric: true` and use tabular figures (§4).

---

## 12. Glass / Frosted Effect — ⚠️ opt-in, not wired into the shell

`GlassSurface` and `AppGlassBackground` exist in `lib/core/widgets/glass_surface.dart`, **but the app shell does not use them yet**: `AppDesktopScaffold` renders a plain scaffold, and no screen currently applies the gradient background or blur. Do not assume a screen is "glass" because this file exists.

If (and only if) the glass direction is adopted for the shell:

- **Background:** wrap the scaffold body in `AppGlassBackground` — gradient canvas with 3 radial orbs (blue, purple, sky-blue). `GlassSurface` blur is invisible without a colorful backdrop behind it.
- **Panels:**

```dart
import 'package:phone_shop_pos/core/widgets/glass_surface.dart';

GlassSurface(
  borderRadius: AppRadii.lgRadius,   // default
  blur: 12,                          // blur strength (default 12)
  lightOpacity: 0.70,                // surface opacity in light mode (default)
  darkOpacity: 0.13,                 // surface opacity in dark mode (default)
  showBorder: true,                  // subtle white border (default)
  child: YourWidget(),
)
```

- Full-height panels (sidebar/topbar) use `borderRadius: BorderRadius.zero` and `showBorder: false`.

> **Performance note:** `BackdropFilter` is expensive — only use it on hero elements (sidebar, topbar, modal overlay). Never on data tables, form fields, or per-row widgets.

---

## 13. Navigation Rail (Sidebar)

```dart
// Width behavior (automatic from AppSidebar):
// < 1600px window width  → collapsed rail, icons + labels underneath
// ≥ 1600px window width  → extended rail (208px min), labels beside icons

// Background: white @ 82% opacity (light) / surfaceContainer (dark) — translucent, not blurred
// Indicator shape: AppRadii.lgRadius
```

The top bar (`AppTopBar`, 56px) shows app name + current section; status chips (pending prints, active operations) each watch their own provider so they rebuild independently.

---

## 14. Dark Mode

- `MaterialApp` wires both `theme:` and `darkTheme:`; with no explicit `themeMode` the app **follows the OS setting**. (A user-facing Light/Dark/System toggle is planned — see `UI_UX_AUDIT_REPORT.md`.)
- Everything theme-driven (cards, inputs, tables, semantic colors) adapts automatically. Things that break dark mode:
  - `Colors.*` literals, hardcoded hex values, `Colors.white`/`black` text
  - `Colors.green.withOpacity(...)`-style status colors — use `semantic.*`
  - Hardcoded light border colors in custom `InputDecoration`s (§7 known issue)
- **Before merging any new screen: run it once in dark mode.** Set your OS to dark or temporarily force `themeMode: ThemeMode.dark` in `main.dart`.

---

## 15. Keyboard & Focus

This is a keyboard-first POS. Every new screen must be operable without a mouse.

- Register screen-level shortcuts with `Shortcuts`/`Actions` (see `dashboard_screen.dart` F5 refresh) or via `AppShortcutManager` for global ones.
- Conventions already in use: **F1/Ctrl+F** focus search · **F5** refresh · **F10** save/complete · **Ctrl+/** shortcuts help · **Enter/Esc** in confirmation dialogs.
- After a scan/add action, return focus to the input the operator uses next (see `_clearSearchAfterAdd` in the sales screen).
- Set `autofocus: true` on the primary field of every dialog/form.
- Use `FocusNode` + `textInputAction: TextInputAction.next` chains so Tab/Enter walk the form in order.

---

## 16. Accessibility Checklist (per new screen/widget)

- [ ] Every icon-only button has `tooltip:` (doubles as the semantic label)
- [ ] Status is never conveyed by color alone — pair with icon or text
- [ ] Interactive custom widgets (tappable cards, rows) are wrapped in `Semantics` or built on `InkWell`/buttons that provide semantics for free
- [ ] Text on `*Container` colors uses the matching foreground (`semantic.success` on `successContainer`, `on*` on solids)
- [ ] Works at 1366×768 (minimum window) without overflow errors
- [ ] Checked once in dark mode (§14)

---

## Quick Reference

| Task | File |
|------|------|
| Spacing & radii tokens | `lib/core/theme/app_spacing.dart` |
| Semantic colors (success/warning/danger) | `lib/core/theme/app_semantic_colors.dart` |
| Typography scale + tabular figures | `lib/core/theme/app_typography.dart` |
| Full theme definition | `lib/core/theme/app_theme.dart` |
| Core UI widgets (scaffold, table, badges, empty state, dialogs) | `lib/core/widgets/desktop_components.dart` |
| Loading skeletons | `lib/core/widgets/app_skeleton.dart` |
| Glass components (opt-in, unwired) | `lib/core/widgets/glass_surface.dart` |
| Snackbars / notifications | `lib/core/notifications/app_notifier.dart` |
| Number / currency / date formatting | `lib/core/utils/formatting_helpers.dart` |
| Keyboard shortcuts | `lib/core/shortcuts/app_shortcut_manager.dart` |
| UI/UX audit & improvement roadmap | `UI_UX_AUDIT_REPORT.md` |
