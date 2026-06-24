# UI Guidelines — Phone Shop POS

> Ye document in-house UI decisions aur patterns record karta hai.
> Koi bhi naya screen/widget banane se pehle ye zaroor parho — isi liye yahan hai.

---

## 1. Design Tokens — kabhi hardcode mat karo

### Spacing (`AppSpacing`)
```dart
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

// Values: xs=4, sm=8, md=12, lg=16, xl=24, xxl=32
Padding(padding: const EdgeInsets.all(AppSpacing.md))  // ✅
Padding(padding: const EdgeInsets.all(12))              // ❌

// Pre-built gaps — re-allocate mat karo
AppSpacing.gapSm   // SizedBox(width:8, height:8)
AppSpacing.gapMd   // SizedBox(width:12, height:12)
AppSpacing.gapLg   // SizedBox(width:16, height:16)
```

### Corner Radii (`AppRadii`)
```dart
// xs=4, sm=8, md=12, lg=16
borderRadius: AppRadii.lgRadius   // cards, dialogs
borderRadius: AppRadii.mdRadius   // buttons, inputs
borderRadius: AppRadii.smRadius   // chips, inner containers
```

### Semantic Colors
```dart
// NEVER use Colors.green / Colors.orange / Colors.red directly.
// Ye dark mode main toot jaate hain.
final semantic = Theme.of(context).semantic;  // AppSemanticColorsX extension

color: semantic.success   // hara — stock available, profit positive
color: semantic.warning   // narnji — low stock, pending amount
color: semantic.danger    // lal — error, critical
color: semantic.info      // neela — informational

// Container variants bhi hain (light background ke liye):
color: semantic.successContainer
```

---

## 2. Core Widgets — naya mat banao, yahi use karo

Sab `lib/core/widgets/desktop_components.dart` main hain.

| Widget | Kab use karo |
|--------|-------------|
| `AppDataTable` | Har jagah table ke liye — sticky header, pagination, zebra rows automatic |
| `AppEmptyState` | Jab list/table khaali ho — `Center(Text('No records'))` mat likho |
| `AppSearchField` | Har search bar — clear button automatic aata hai |
| `AppConfirmationDialog` | Delete/confirm dialogs — Esc/Enter keyboard bhi handle karta hai |
| `AppStatusBadge` | Status chips (active, sold, returned, etc.) |
| `AppLoadingOverlay` | Jab operation chal raha ho aur screen block karni ho |

### AppDataTable usage
```dart
AppDataTable(
  columns: const [
    DataColumn(label: Text('#')),         // serial number hamesha pehla column
    DataColumn(label: Text('Date')),
    DataColumn(label: Text('Actions'), numeric: true),
  ],
  rows: items.map((item) => DataRow(cells: [...])).toList(),
  emptyMessage: 'No issues found.',
  emptyIcon: Icons.inbox_outlined,
)
```

**Zaruri rules:**
- `#` (serial number) column hamesha pehla hona chahiye
- Table `Expanded` widget ke andar honi chahiye taki sticky header kaam kare
- Paginated mode automatic activate hota hai jab rows ≥ 80

---

## 3. Form Fields

Har input field ka yahi style hona chahiye:

```dart
TextField(
  decoration: const InputDecoration(
    labelText: 'Field Name',
    border: OutlineInputBorder(),
    isDense: true,              // compact height — hamesha lagao
  ),
)
```

### Scanner-aware IMEI fields
Jab bhi IMEI scan hone wala ho:
```dart
TextField(
  decoration: const InputDecoration(
    labelText: 'Scan or enter IMEI',
    hintText: 'Scan barcode or type manually',
    border: OutlineInputBorder(),
    isDense: true,
    prefixIcon: Icon(Icons.qr_code_scanner, size: 18),
  ),
  onSubmitted: (_) => _handleImei(),  // scanner Enter bhejta hai — yahi trigger hai
)
```

### Dropdown — deprecated API se bachao
```dart
// ✅ Sahi — initialValue use karo
DropdownButtonFormField<String>(
  initialValue: _selectedValue,
  onSaved: (v) { if (v != null) _selectedValue = v; },
  ...
)

// ❌ Galat — value deprecated ho gaya hai Flutter 3.33+
DropdownButtonFormField<String>(
  value: _selectedValue,
  ...
)
```

---

## 4. Dialog Patterns

### Standard AlertDialog
```dart
AlertDialog(
  title: const Text('Title'),
  content: SizedBox(
    width: 420,            // narrow: 380-420, medium: 500-600, wide: 700
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [...],
    ),
  ),
  actions: [
    TextButton(
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Cancel'),
    ),
    FilledButton(
      onPressed: _isLoading ? null : _submit,
      child: Text(_isLoading ? 'Saving…' : 'Save'),
    ),
  ],
)
```

**Rules:**
- Cancel button: hamesha `TextButton` — left side
- Primary action: hamesha `FilledButton` — right side
- Loading state: button ko `null` karo, text change karo (`'Saving…'`)
- Loading indicator inline buttons main: `SizedBox(width:16, height:16, child: CircularProgressIndicator(strokeWidth:2))`

### Dialog jis main "Add New" option bhi ho
```dart
Row(
  children: [
    Expanded(child: DropdownButtonFormField<String>(...)),
    const SizedBox(width: 8),
    IconButton.outlined(
      tooltip: 'Add new dealer',
      icon: const Icon(Icons.person_add_outlined, size: 18),
      onPressed: () async {
        final created = await AddDealerDialog.show(context);
        if (created != null) {
          ref.invalidate(dealerListProvider);
          setState(() => _selectedId = created.id);
        }
      },
    ),
  ],
)
```

---

## 5. Screen Layout Pattern

Har module screen ka yahi structure hoga:

```dart
Scaffold(
  body: Padding(
    padding: const EdgeInsets.all(AppSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),           // Row(mainAxisAlignment: end, [buttons])
        const SizedBox(height: 8),
        FilterWidget(...),        // filter bar
        const SizedBox(height: 8),
        Expanded(                 // yahan table sticky header ke liye bounded height milti hai
          child: DataTableWidget(...),
        ),
      ],
    ),
  ),
)
```

### Header buttons order
```dart
Row(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    OutlinedButton.icon(     // secondary action pehle
      icon: const Icon(Icons.qr_code_scanner, size: 18),
      label: const Text('Scan Return'),
      onPressed: _openScanReturn,
    ),
    const SizedBox(width: 8),
    FilledButton.icon(       // primary action baad main
      icon: const Icon(Icons.add),
      label: const Text('Add / Issue'),
      onPressed: _openDialog,
    ),
  ],
)
```

---

## 6. State Management (Riverpod)

### Mutation ke baad refresh karna
```dart
// Dialog return ke baad hamesha explicitly reload karo:
final result = await showDialog<bool>(...);
if (result == true) {
  ref.read(myStateProvider.notifier).loadData();  // state notifier
  // ya
  ref.invalidate(myListProvider);                  // FutureProvider
}
```

### Dealer providers
```dart
// List lena
final dealers = ref.watch(dealerListProvider);   // AsyncValue<List<DealerEntity>>

// CRUD
final repo = ref.read(dealerRepositoryProvider);
await repo.createDealer(dealer);
await repo.updateDealer(dealer);
await repo.deleteDealer(dealerId);   // soft delete — is_active=0

// New dealer create karke auto-select karna
final created = await AddDealerDialog.show(context);
if (created != null) {
  ref.invalidate(dealerListProvider);
  setState(() => _selectedDealerId = created.id);
}
```

### Provider naming convention
- `xxxListProvider` — `FutureProvider<List<T>>` for read-only lists
- `xxxRepositoryProvider` — `Provider<Repository>` for CRUD
- `xxxStateProvider` — `StateNotifierProvider` for complex screen state

---

## 7. Database Migrations

DB version: `lib/core/database/database_constants.dart` → `databaseVersion`  
Current version: **31**

### Naya migration add karne ka tareeqa
```dart
// 1. database_constants.dart main version badhao: 31 → 32
static const int databaseVersion = 32;

// 2. migration_service.dart main _applyMigration() main entry add karo:
if (version == 32) { await _applyMigrationV32(database); return; }

// 3. Method likho:
Future<void> _applyMigrationV32(Database database) async {
  await database.execute('''
    ALTER TABLE some_table ADD COLUMN new_col TEXT;
  ''');
}
```

**Rules:**
- Har migration `IF NOT EXISTS` / `IF NOT EXISTS column` safe banao
- Fresh install aur upgrade dono test karo — `onCreate` dono call karta hai
- Soft delete pattern: `is_active INTEGER NOT NULL DEFAULT 1` with `UPDATE SET is_active=0`

### Table names — hardcode mat karo
```dart
// lib/core/database/table_names.dart main constant add karo
static const String dealers = 'dealers';

// Query main use karo
'SELECT * FROM ${TableNames.dealers}'
```

---

## 8. Dashboard KPI Card Add Karne Ka Tareeqa

Naya KPI card add karna 6 jagah kaam hai:

1. **`dashboard_kpis_entity.dart`** — field add karo (optional with default 0)
2. **`dashboard_service.dart`** — `getDashboardKpis()` main rawQuery add karo, entity main pass karo
3. **`dashboard_providers.dart`** — agar detail view chahiye to alag `FutureProvider` banao
4. **`kpi_card_config.dart`** — `kpiCardDefaults` list main entry add karo
5. **`dashboard_kpi_grid.dart`** — `_buildCard()` switch main `case 'your_id':` add karo
6. **`kpi_detail_sheet.dart`** — `_buildContent()` main case add karo, `_iconForCard()` main icon

Example (dealer_stock ki tarah):
```dart
// kpi_card_config.dart
KpiCardConfig(id: 'your_kpi', label: 'Your Label', order: 9),

// dashboard_kpi_grid.dart
case 'your_kpi':
  label = 'Your Label';
  value = kpis.yourCount.toString();
  icon = Icons.your_icon;
  color = kpis.yourCount > 0 ? semantic.warning : accent;
  break;
```

---

## 9. Dealer Module Architecture

Dealer = chota dukandar jo phones consignment pe leta hai main shop se.

```
lib/modules/dealer_issue/
├── data/repositories/
│   ├── sqlite_dealer_issue_repository.dart   # issue CRUD + markAsSoldViaDealer()
│   └── sqlite_dealer_repository.dart         # dealer CRUD
├── domain/
│   ├── entities/
│   │   ├── dealer_entity.dart                # id, name, phone, address
│   │   └── dealer_issue_entity.dart          # issueId, dealerId, imeiList, statuses
│   └── repositories/
│       ├── dealer_repository.dart
│       └── dealer_issue_repository.dart
└── presentation/
    ├── providers/
    │   ├── dealer_providers.dart              # dealerRepositoryProvider, dealerListProvider
    │   └── dealer_issue_state_provider.dart   # issue screen state + actions
    ├── screens/
    │   └── dealer_issue_screen.dart
    └── widgets/
        ├── add_dealer_dialog.dart             # naam/phone/address form
        ├── scan_return_dialog.dart            # IMEI scan → wapsi confirm
        ├── dealer_issue_dialog_widget.dart    # issue banao (dealer select + IMEI scan)
        ├── dealer_issue_filter_widget.dart    # filter + Add Dealer button
        ├── dealer_issue_table_widget.dart     # table with mark-sold action
        └── dealer_issue_mark_sold_dialog.dart # price + payment method
```

### Issue IMEI List Format
`imei_list` comma-separated string hai: `"358492901234567,358492901234568"`

IMEI search karte waqt charon positions cover karo:
```dart
// exact (single IMEI) | first | middle | last
WHERE imei_list = ? OR imei_list LIKE ? OR imei_list LIKE ? OR imei_list LIKE ?
// args: [imei, '$imei,%', '%,$imei,%', '%,$imei']
```

---

## 10. Lint Rules — CI fail hoti hai in se

`analysis_options.yaml` main sirf do extra rules hain lekin CI exit code 1 return karta hai:

```yaml
prefer_single_quotes: true
always_use_package_imports: true
```

### prefer_single_quotes
```dart
// ✅
final label = 'hello';
'SELECT * FROM ${TableNames.dealers}';

// ❌ — CI fail hoga
final label = "hello";
"SELECT * FROM ${TableNames.dealers}";

// SQL main single quote wala value? Parameterize karo:
db.rawQuery('WHERE status = ?', ['with_dealer']);  // ✅
db.rawQuery("WHERE status = 'with_dealer'");       // ❌
```

### always_use_package_imports
```dart
// ✅
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

// ❌
import '../../core/theme/app_spacing.dart';
```

---

## 11. Feature Flags

Naya module gating ke liye `AppRuntimeConfig` use karo:

```dart
// lib/core/services/app_runtime_config.dart
static bool get showMyModule =>
    FeatureFlags.currentBehaviorDefaults().myModule;

// UI main check
if (AppRuntimeConfig.showMyModule)
  _QuickActionButton(label: 'My Module', ...),
```

Router main feature flag check `lib/core/config/feature_access.dart` main hota hai.

---

## 12. Quick Reference

| Kaam | File |
|------|------|
| Spacing / radii tokens | `lib/core/theme/app_spacing.dart` |
| Semantic colors (success/warning/danger) | `lib/core/theme/app_semantic_colors.dart` |
| Core widgets (table, dialog, search) | `lib/core/widgets/desktop_components.dart` |
| App routes | `lib/core/routing/app_router.dart` |
| Table names | `lib/core/database/table_names.dart` |
| DB version | `lib/core/database/database_constants.dart` |
| Migrations | `lib/core/database/migration_service.dart` |
| Feature flags | `lib/core/services/app_runtime_config.dart` |
| KPI card list | `lib/modules/dashboard/domain/entities/kpi_card_config.dart` |
| KPI grid renderer | `lib/modules/dashboard/presentation/widgets/dashboard_kpi_grid.dart` |
| KPI detail sheet | `lib/modules/dashboard/presentation/widgets/kpi_detail_sheet.dart` |
| Dashboard providers | `lib/modules/dashboard/presentation/providers/dashboard_providers.dart` |
| Dealer providers | `lib/modules/dealer_issue/presentation/providers/dealer_providers.dart` |
