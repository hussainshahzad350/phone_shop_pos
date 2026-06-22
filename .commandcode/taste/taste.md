# Taste (Continuously Learned by [CommandCode][cmd])

[cmd]: https://commandcode.ai/

# Architecture
See [architecture/taste.md](architecture/taste.md)
# Workflow
- flutter analyze must pass with zero errors before any prompt is considered complete. Confidence: 0.85
- Every task prompt must include: file paths changed, layer, confirmation of no cross-layer change, find/replace instructions, verification step, do's and don'ts, and which feature flag (if any) gates new UI. Confidence: 0.80
- Per-feature build phases: Domain/Data (entities, repos, feature-flag plumbing, additive schema) → BLoC (events/states, failure hygiene, post-action cleanup) → UI structure (screen/dialog/widget scaffolding, 600-800 line screens with dialogs/widgets/utils subfolders) → UI polish (localization, ErrorHandler, dialog sizing, responsive breakpoints, debounced search). Confidence: 0.80

# Code-Style
- No hardcoded strings: all display strings via AppLocalizations (ARB files) for English (LTR) + Urdu (RTL) localization. Confidence: 0.85
- Reuse existing code: always use existing repositories, providers, services, and export utilities rather than writing new ones. Confidence: 0.85
- Do not break existing architecture: reuse patterns from existing codebase; do not introduce a second architecture for new features. Confidence: 0.85
- Desktop-first design: minimum target layout 1366x768, keyboard-first UX, prefer synchronous-feeling operations backed by local SQLite. Confidence: 0.80
- Module folder structure: screens at 600-800 lines max, with dialogs/, widgets/, utils/ subfolders for extracted pieces. Confidence: 0.80
