# UI Design Guidelines — Phone Shop POS

> Design, color, and UI patterns only. No business logic here.
> Start here before building any new screen or widget.

---

## App Visual Style

**Soft Card Style** — Material 3 base, clean and light.

- Background: off-white (`#F6F8FC`) — not pure white, slight bluish tint
- Cards: near-opaque white (`94% opacity`) + subtle shadow + border
- Primary accent: Indigo-blue (`#5167F6`)
- Corners: rounded (4px to 16px — depends on purpose)
- **Glass/frosted blur effect: IS IMPLEMENTED** — see pattern below

---

## 1. Color Palette

### Primary Colors
| Token | Hex | Where used |
|-------|-----|------------|
| Primary | `#5167F6` | Buttons, active states, links |
| Scaffold background | `#F6F8FC` | Screen background (light mode) |
| Card surface | `rgba(255,255,255, 0.94)` | Cards |
| Card border | `#E3E8F2` | Card outline |
| Input fill | `#FAFBFE` | Text field background |
| Input border | `#D7DBE7` | Text field outline |
| Input focused | `#5167F6 @ 1.2px` | Active input border |

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

> Dark mode automatically uses different shades — hardcoding `Colors.green` etc. breaks in dark mode.

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

Scale is defined — do not use `fontWeight: FontWeight.bold` ad hoc.

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

### Tabular figures — for currency/numbers
```dart
import 'package:phone_shop_pos/core/theme/app_typography.dart';

Text(
  'Rs. 1,234',
  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
    fontFeatures: AppTypography.tabularFigures,  // digits stay aligned in columns
  ),
)
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
- Border: `#E3E8F2`
- Color: `white @ 94%`
- No surface tint (M3 elevation tint is off)

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

**Dropdown:**
```dart
// ✅ Use initialValue (value is deprecated in Flutter 3.33+)
DropdownButtonFormField<String>(
  initialValue: _selected,
  decoration: const InputDecoration(labelText: 'Select'),
  items: [...],
  onChanged: (v) { if (v != null) setState(() => _selected = v); },
)
```

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

---

## 10. Empty States

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
**Pagination:** Switches to paginated mode automatically at 80+ rows.
**Sticky header:** Only works when the table is inside an `Expanded` widget.

---

## 12. Glass / Frosted Effect

**The glass effect IS implemented** (`lib/core/widgets/glass_surface.dart`).

**Background:** `AppGlassBackground` — gradient canvas with 3 radial orbs (blue, purple, sky-blue). `AppDesktopScaffold` applies this automatically — no need to add it manually.

**Glass panels:** `GlassSurface` — wrap it around any widget:

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

**Sidebar / TopBar** use `borderRadius: BorderRadius.zero` and `showBorder: false` (for full-height panels).

> **Performance note:** `BackdropFilter` is expensive — only use it on hero elements (sidebar, topbar, modal overlay). Do not apply to data tables or form fields.

---

## 13. Navigation Rail (Sidebar)

```dart
// Width behavior (automatic from theme):
// < 1600px wide screen  → icons + labels (collapsed rail)
// ≥ 1600px wide screen  → extended rail (208px min)

// Background: white @ 82% opacity — slightly transparent, not blurred
// Indicator shape: AppRadii.lgRadius
```

---

## Quick Reference

| Task | File |
|------|------|
| Colors, spacing, radii tokens | `lib/core/theme/app_spacing.dart` |
| Semantic colors (success/warning/danger) | `lib/core/theme/app_semantic_colors.dart` |
| Typography scale | `lib/core/theme/app_typography.dart` |
| Full theme definition | `lib/core/theme/app_theme.dart` |
| Core UI widgets | `lib/core/widgets/desktop_components.dart` |
