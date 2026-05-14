# phone_shop_pos

Desktop-first, offline-ready Flutter POS architecture for Pakistani mobile retail.

## Goals
- Fast local POS workflow (Windows-first)
- IMEI-ready mobile inventory foundation
- Quantity-stock accessories foundation
- Keyboard-first desktop mindset
- Future-ready architecture for Android companion app

## Tech Stack
- Flutter
- Riverpod
- SQLite (`sqflite_common_ffi`)
- Clean modular architecture

## Project Structure

```text
lib/
 ├── core/
 │    ├── database/
 │    ├── services/
 │    ├── utils/
 │    ├── constants/
 │    ├── theme/
 │    ├── widgets/
 │    ├── routing/
 │    └── errors/
 │
 ├── modules/
 │    ├── dashboard/
 │    ├── sales/
 │    ├── inventory/
 │    ├── purchases/
 │    ├── customers/
 │    ├── reports/
 │    ├── settings/
 │    └── auth/
 │
 ├── shared/
 │    ├── models/
 │    ├── providers/
 │    ├── extensions/
 │    └── enums/
 │
 └── main.dart
```

Each module follows:
- `data/`
  - `datasource/`
  - `models/`
  - `repositories/`
- `domain/`
  - `entities/`
  - `repositories/`
  - `usecases/`
- `presentation/`
  - `screens/`
  - `widgets/`
  - `providers/`

## Base Infrastructure Added
- Riverpod root setup (`ProviderScope`)
- App router placeholder (`core/routing/app_router.dart`)
- App theme placeholder (`core/theme/app_theme.dart`)
- SQLite abstraction (`core/database/sqlite_service.dart`)
- Base repository contract (`core/database/base_repository.dart`)
- Result/error pattern (`core/errors/result.dart`, `core/errors/app_error.dart`)
- Shared core provider for database initialization (`shared/providers/core_providers.dart`)

## Desktop-First Standards
- Minimum target layout: **1366x768**
- Windows as primary runtime target
- Keep flows keyboard-first and low-latency
- Prefer synchronous-feeling UX backed by local SQLite

## Naming Conventions
- Folders: `snake_case`
- Files: `snake_case.dart`
- Classes/Enums: `PascalCase`
- Variables/Methods: `camelCase`
- Provider names: `*Provider`
- Repository contracts in `domain/repositories`, implementations in `data/repositories`

## Future Expansion (without rewrites)
The same module pattern supports adding:
- Grocery POS modules
- Pharmacy retail modules
- Hardware store modules

by introducing new feature folders under `modules/` with the same `data/domain/presentation` split.

## Recommended Package List (next phase)
- `flutter_riverpod`
- `go_router`
- `sqflite_common_ffi`
- `path`
- `path_provider`
- `freezed_annotation` + `json_serializable` (when model generation starts)
- `intl` (when receipt/report formatting starts)

> Business logic and UI screens are intentionally not implemented in this phase.
