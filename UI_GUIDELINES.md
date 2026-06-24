# UI Design Guidelines — Phone Shop POS

> Sirf design, color, aur UI patterns. Business logic yahan nahi hai.
> Naya screen ya widget banane se pehle yahan se start karo.

---

## App Ka Visual Style

**Soft Card Style** — Material 3 base, clean aur light.

- Background: off-white (`#F6F8FC`) — pure white nahi, thoda bluish tint
- Cards: near-opaque white (`94% opacity`) + subtle shadow + border
- Primary accent: Indigo-blue (`#5167F6`)
- Corners: rounded (4px se 16px tak — purpose ke hisaab se)
- **Glass/frosted blur effect: NAHI HAI** — agar chahiye to neeche pattern diya hai

---

## 1. Color Palette

### Primary Colors
| Token | Hex | Kahan use hota hai |
|-------|-----|-------------------|
| Primary | `#5167F6` | Buttons, active states, links |
| Scaffold background | `#F6F8FC` | Screen background (light mode) |
| Card surface | `rgba(255,255,255, 0.94)` | Cards |
| Card border | `#E3E8F2` | Card outline |
| Input fill | `#FAFBFE` | Text field background |
| Input border | `#D7DBE7` | Text field outline |
| Input focused | `#5167F6 @ 1.2px` | Active input border |

### Semantic Colors — status ke liye HAMESHA yahi use karo
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

> Dark mode ke liye automatically alag shades hain — `Colors.green` wagera hardcode karna toot jaata hai dark mode mein.

---

## 2. Spacing — 4px Grid

```
xs = 4    sm = 8    md = 12    lg = 16    xl = 24    xxl = 32
```

```dart
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

// ✅ Token use karo
const SizedBox(height: AppSpacing.sm)   // 8
Padding(padding: EdgeInsets.all(AppSpacing.md))  // 12

// ✅ Pre-built gaps
AppSpacing.gapSm   // SizedBox 8×8
AppSpacing.gapMd   // SizedBox 12×12
AppSpacing.gapLg   // SizedBox 16×16

// ❌ Magic numbers
const SizedBox(height: 8)    // kahan se aaya 8?
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

Scale define hai — `fontWeight: FontWeight.bold` ad-hoc mat karo.

| Style | Size | Weight | Kahan |
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

### Tabular figures — currency/numbers ke liye
```dart
import 'package:phone_shop_pos/core/theme/app_typography.dart';

Text(
  'Rs. 1,234',
  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
    fontFeatures: AppTypography.tabularFigures,  // digits column mein align rehte hain
  ),
)
```

---

## 5. Cards

Theme se automatic aata hai — sirf `Card()` wrap karo:

```dart
Card(
  child: Padding(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: ...,
  ),
)
```

Jo automatically milta hai:
- `elevation: 1.5` — subtle shadow
- `borderRadius: 16` (AppRadii.lgRadius)
- Border: `#E3E8F2`
- Color: `white @ 94%`
- No surface tint (M3 ka elevation tint off hai)

**Colored cards** (status ke liye):
```dart
Card(
  color: Theme.of(context).colorScheme.secondaryContainer,  // ✅ theme-aware
  // ya
  color: semantic.successContainer,  // ✅ semantic
  // ❌ nahi
  color: Colors.green.withOpacity(0.1),
)
```

---

## 6. Buttons

Teen types hain — kab kaunsa:

| Widget | Kab |
|--------|-----|
| `FilledButton` / `FilledButton.icon` | Primary action — ek screen pe sirf ek |
| `OutlinedButton` / `OutlinedButton.icon` | Secondary action — page pe multiple ho sakte |
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

Default theme se inputs already styled hain (filled, rounded, dense). Sirf ye rules follow karo:

```dart
// Standard input
TextFormField(
  decoration: const InputDecoration(
    labelText: 'Field Name',
    // border, fill, radius theme se auto aata hai
    // isDense: true bhi theme se auto — explicit nahi likhna
  ),
)

// Icon ke saath
InputDecoration(
  labelText: 'Search',
  prefixIcon: const Icon(Icons.search, size: 18),  // size: 18 compact ke liye
)

// ❌ Avoid OutlineInputBorder() inline likhna — theme pehle se sahi set hai
// Sirf tab likhna jab kuch override karna ho
```

**Dropdown:**
```dart
// ✅ initialValue use karo (value deprecated hai Flutter 3.33+)
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
    TextButton(                          // Cancel — hamesha baya
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Cancel'),
    ),
    FilledButton(                        // Confirm — hamesha seedha
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
// ✅ Yahi use karo — Center(Text('No data')) nahi
AppEmptyState(
  message: 'No records found.',
  icon: Icons.inbox_outlined,       // optional, default yahi hai
  action: FilledButton(             // optional CTA
    onPressed: _openAdd,
    child: const Text('Add First'),
  ),
)
```

---

## 11. Tables

`AppDataTable` use karo — zebra rows, sticky header, pagination sab automatic:

```dart
AppDataTable(
  columns: const [
    DataColumn(label: Text('#')),      // serial number — HAMESHA pehla column
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

**Table heading color:** `#EFF2FA` (light) — theme se automatic aata hai.
**Pagination:** 80+ rows pe automatically paginated mode switch ho jaata hai.
**Sticky header:** Sirf tab kaam karta hai jab table `Expanded` ke andar ho.

---

## 12. Glass / Frosted Effect

**App mein glass effect IMPLEMENTED hai** (`lib/core/widgets/glass_surface.dart`).

**Background:** `AppGlassBackground` — gradient canvas with 3 radial orbs (blue, purple, sky-blue). `AppDesktopScaffold` automatically apply karta hai — manually lagane ki zaroorat nahi.

**Glass panels:** `GlassSurface` — kisi bhi widget ke around wrap karo:

```dart
import 'package:phone_shop_pos/core/widgets/glass_surface.dart';

GlassSurface(
  borderRadius: AppRadii.lgRadius,   // default
  blur: 12,                          // blur strength (default 12)
  lightOpacity: 0.70,                // surface opacity light mode (default)
  darkOpacity: 0.13,                 // surface opacity dark mode (default)
  showBorder: true,                  // subtle white border (default)
  child: YourWidget(),
)
```

**Sidebar / TopBar** mein `borderRadius: BorderRadius.zero` aur `showBorder: false` use hota hai (full-height panels ke liye).

> **Performance note:** `BackdropFilter` heavy hai — sirf hero elements pe use karo (sidebar, topbar, modal overlay). Data tables aur form fields pe nahi.

---

## 13. Navigation Rail (Sidebar)

```dart
// Width behavior (theme se automatic):
// < 1600px wide screen  → icons + labels (collapsed rail)
// ≥ 1600px wide screen  → extended rail (208px min)

// Background: white @ 82% opacity — thoda transparent but not blurred
// Indicator shape: AppRadii.lgRadius
```

---

## Quick Reference

| Kaam | File |
|------|------|
| Colors, spacing, radii tokens | `lib/core/theme/app_spacing.dart` |
| Semantic colors (success/warning/danger) | `lib/core/theme/app_semantic_colors.dart` |
| Typography scale | `lib/core/theme/app_typography.dart` |
| Full theme definition | `lib/core/theme/app_theme.dart` |
| Core UI widgets | `lib/core/widgets/desktop_components.dart` |
