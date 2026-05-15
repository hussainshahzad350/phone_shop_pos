# Known Limitations

- Physical printer transport is still file-spool based; this repo does not include a native printer driver integration.
- The new durable print queue prevents silent loss across restart, but operator review is still required after any mid-print crash to avoid duplicate paper output.
- Stress and benchmark scripts were added, but they were not executed in this sandbox because Flutter/Dart tooling was unavailable here.
- Windows packaging still depends on validating the final runner and installer in a machine with Flutter desktop tooling enabled.
- UI-only stability signals such as frame pacing and Riverpod rebuild counts still require on-device profiling during the first staged validation run.
