# Release Checklist

- [ ] Build with production defines:
  - [ ] `--dart-define=POS_RELEASE_CHANNEL=production`
  - [ ] `--dart-define=POS_APP_VERSION=<version>`
  - [ ] `--dart-define=POS_BUILD_NUMBER=<build>`
  - [ ] `--dart-define=POS_ENABLE_DEMO_SEED=false`
- [ ] Confirm startup opens the live SQLite database without recovery warnings.
- [ ] Confirm `Settings -> Startup Health` reports writable database and backup paths.
- [ ] Confirm no demo seed data exists in the production database.
- [ ] Confirm pending/failed print jobs are visible in `Settings -> Invoice Print Queue`.
- [ ] Confirm physical printer retry flow is tested after forcing one spool failure.
- [ ] Confirm backup creation succeeds on the target machine.
- [ ] Confirm backup restore succeeds on a cloned machine or cloned database folder.
- [ ] Confirm Windows Defender / antivirus does not block the database, backup, or print spool folders.
- [ ] Confirm long path storage locations are avoided.
- [ ] Confirm any placeholder or unused navigation targets remain hidden in release.
- [ ] Archive the benchmark summary and final deployment report with the build artifact.
