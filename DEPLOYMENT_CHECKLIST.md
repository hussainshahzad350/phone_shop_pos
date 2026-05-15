# Deployment Checklist

## Before arrival on site
- [ ] Prepare a clean production database folder on a writable local disk.
- [ ] Prepare a writable backup folder on the same machine.
- [ ] Run `dart run tool/generate_stress_dataset.dart --root=<path> --reset=true` on a staging copy if stress data validation is still pending.
- [ ] Run `dart run tool/run_benchmarks.dart --root=<path>` and save the output.

## On the target Windows PC
- [ ] Launch the app once and verify startup recovery succeeds.
- [ ] Verify `Settings -> Startup Health` is healthy.
- [ ] Create a manual backup before the first live shift.
- [ ] Complete one test sale and confirm the receipt enters the print queue.
- [ ] Force one print retry and confirm the queue survives an app restart.
- [ ] Confirm the app blocks silent close while backup, restore, save, or print work is active.
- [ ] Confirm date, number, and currency fields accept both `1234.50` and `1,234.50`.

## End-of-day checks
- [ ] Confirm no failed backups remain unresolved.
- [ ] Confirm no stale failed print jobs remain unexplained.
- [ ] Confirm the latest backup file exists and validates.
- [ ] Record benchmark and operational notes for the deployment report.
