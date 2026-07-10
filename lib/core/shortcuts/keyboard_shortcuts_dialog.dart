import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

/// A single keyboard shortcut row: one or more key "chords" and a description.
///
/// Each chord is a list of keycaps pressed together (e.g. `['Ctrl', 'F']`).
/// When more than one chord is supplied they are shown as alternatives
/// separated by "or" (e.g. `↑` **or** `↓`).
class _ShortcutSpec {
  const _ShortcutSpec({
    required this.chords,
    required this.description,
  });

  final List<List<String>> chords;
  final String description;
}

class _ShortcutGroup {
  const _ShortcutGroup({
    required this.title,
    required this.shortcuts,
  });

  final String title;
  final List<_ShortcutSpec> shortcuts;
}

// Single source of truth for what the help sheet displays. Keep this in sync
// with the actual bindings in:
//   - lib/core/shortcuts/app_shortcut_manager.dart   (global)
//   - lib/modules/sales/presentation/helpers/sales_shortcut_helpers.dart (sales)
const List<_ShortcutGroup> _shortcutGroups = <_ShortcutGroup>[
  _ShortcutGroup(
    title: 'Navigation',
    shortcuts: <_ShortcutSpec>[
      _ShortcutSpec(
        chords: <List<String>>[
          <String>['Ctrl', 'S']
        ],
        description: 'Go to Sales',
      ),
      _ShortcutSpec(
        chords: <List<String>>[
          <String>['Ctrl', 'I']
        ],
        description: 'Go to Inventory',
      ),
      _ShortcutSpec(
        chords: <List<String>>[
          <String>['Ctrl', 'R']
        ],
        description: 'Go to Reports',
      ),
      _ShortcutSpec(
        chords: <List<String>>[
          <String>['Ctrl', 'B']
        ],
        description: 'Open Settings (for One-Click Backup)',
      ),
      _ShortcutSpec(
        chords: <List<String>>[
          <String>['Ctrl', 'L']
        ],
        description: 'Lock the app',
      ),
    ],
  ),
  _ShortcutGroup(
    title: 'Sales Screen',
    shortcuts: <_ShortcutSpec>[
      _ShortcutSpec(
        chords: <List<String>>[
          <String>['Ctrl', 'F'],
        ],
        description: 'Focus the product search',
      ),
      _ShortcutSpec(
        chords: <List<String>>[
          <String>['F2']
        ],
        description: 'Focus the payment section',
      ),
      _ShortcutSpec(
        chords: <List<String>>[
          <String>['↑'],
          <String>['↓'],
        ],
        description: 'Move between cart rows',
      ),
      _ShortcutSpec(
        chords: <List<String>>[
          <String>['+'],
          <String>['−'],
        ],
        description: 'Increase / decrease quantity of the selected row',
      ),
      _ShortcutSpec(
        chords: <List<String>>[
          <String>['Delete']
        ],
        description: 'Remove the selected cart row',
      ),
      _ShortcutSpec(
        chords: <List<String>>[
          <String>['F10']
        ],
        description: 'Complete the sale',
      ),
      _ShortcutSpec(
        chords: <List<String>>[
          <String>['Esc']
        ],
        description: 'Clear search / close',
      ),
    ],
  ),
  _ShortcutGroup(
    title: 'General',
    shortcuts: <_ShortcutSpec>[
      _ShortcutSpec(
        chords: <List<String>>[
          <String>['F5']
        ],
        description: 'Refresh the current screen',
      ),
      _ShortcutSpec(
        chords: <List<String>>[
          <String>['F1']
        ],
        description: 'Show this shortcuts help',
      ),
    ],
  ),
];

/// A read-only reference sheet listing every keyboard shortcut, grouped by
/// area. Opened on demand via `F1` or the "?" button in the top bar.
class KeyboardShortcutsDialog extends StatelessWidget {
  const KeyboardShortcutsDialog({super.key});

  // Guards against stacking multiple copies when the open shortcut (F1) is
  // pressed repeatedly while the sheet is already visible.
  static bool _isOpen = false;

  /// Convenience helper so callers don't need to import `showDialog` plumbing.
  static Future<void> show(BuildContext context) async {
    if (_isOpen) {
      return;
    }
    _isOpen = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (_) => const KeyboardShortcutsDialog(),
      );
    } finally {
      _isOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      title: Row(
        children: <Widget>[
          const Icon(Icons.keyboard_outlined, size: 20),
          const SizedBox(width: AppSpacing.sm),
          const Text('Keyboard Shortcuts'),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int i = 0; i < _shortcutGroups.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: AppSpacing.lg),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    _shortcutGroups[i].title.toUpperCase(),
                    style: textTheme.titleSmall?.copyWith(
                      letterSpacing: 0.6,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                for (final _ShortcutSpec spec
                    in _shortcutGroups[i].shortcuts)
                  _ShortcutRow(spec: spec),
              ],
            ],
          ),
        ),
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.spec});

  final _ShortcutSpec spec;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 168,
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                for (int c = 0; c < spec.chords.length; c++) ...<Widget>[
                  if (c > 0)
                    Text(
                      'or',
                      style: textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ..._buildChord(context, spec.chords[c]),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                spec.description,
                style: textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChord(BuildContext context, List<String> keys) {
    final List<Widget> widgets = <Widget>[];
    for (int k = 0; k < keys.length; k++) {
      if (k > 0) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '+',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        );
      }
      widgets.add(_Keycap(label: keys[k]));
    }
    return widgets;
  }
}

/// A small "keycap" chip that renders a single key label with a subtle
/// bordered, slightly-raised look — theme-aware for light and dark mode.
class _Keycap extends StatelessWidget {
  const _Keycap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 26),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadii.smRadius,
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelMedium?.copyWith(
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          height: 1.1,
        ),
      ),
    );
  }
}
