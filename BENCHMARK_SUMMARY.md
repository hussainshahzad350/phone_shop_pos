# Benchmark Summary

## Status
- Benchmark tooling added:
  - `tool/generate_stress_dataset.dart`
  - `tool/run_benchmarks.dart`
- Live benchmark numbers were **not collected in this sandbox** because Flutter/Dart CLI tooling was unavailable here.

## Required benchmark capture
- Startup time
- IMEI search latency
- Inventory filter latency
- Sales report generation time
- Current stock report time
- Profit report time
- Backup duration
- Restore duration
- Memory growth during benchmark run

## Recommended commands
```bash
dart run tool/generate_stress_dataset.dart --root=<staging-db-folder> --reset=true
dart run tool/run_benchmarks.dart --root=<staging-db-folder> --out=<summary.json>
```

## Expected review rule
- Do not approve single-shop deployment until a real Windows benchmark summary is attached to the release artifact.
