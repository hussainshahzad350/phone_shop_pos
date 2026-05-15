# Phone Shop POS — Real-Shop Beta Deployment Notes

## Scope
- Windows desktop deployment readiness
- SQLite operational stability
- Backup/restore safety
- Invoice print foundation and retry workflow
- Durable receipt queue recovery and critical-operation exit protection

## Real-Shop Operator Instructions
1. Start app and verify **Startup Health = Healthy** in Settings.
2. Confirm DB location and backup location are on writable local disk.
3. Run **One-Click Backup** at start-of-day and end-of-day.
4. Complete sale; use **Print Preview** action to print or defer.
5. If printing fails or the app restarts mid-print, retry from **Settings → Invoice Print Queue**.
6. Before restoring backup, create a fresh backup first.

## Deployment Checklist (Windows)
- [ ] Release build created with production runtime defines:
  - `--dart-define=POS_RELEASE_CHANNEL=beta`
  - `--dart-define=POS_APP_VERSION=<version>`
  - `--dart-define=POS_BUILD_NUMBER=<build>`
  - `--dart-define=POS_ENABLE_DEMO_SEED=false`
- [ ] Startup opens database without lock errors.
- [ ] Startup Health reports DB + backup paths writable.
- [ ] Backup creation and restore tested once on target machine.
- [ ] Print preview opens and spool files are created in `print_spool`.
- [ ] Pending or failed print retry tested from Settings after app restart.
- [ ] Window close warning appears during save, backup, restore, or print work.

## Known Limitations
- Current print service is a **file-spool foundation** (text output) and not a direct hardware driver integration.
- Physical USB/network thermal printer transport binding is not yet implemented.
- Windows native runner files are not included in this repository snapshot; final packaging must be validated in an environment with Flutter Windows scaffolding enabled.

## Stability Notes
- DB open has lock-recovery retry and stale sidecar cleanup.
- Repository layer maps lock/busy database errors to retry-friendly messages.
- Restore flow remains transactional with rollback protection.
