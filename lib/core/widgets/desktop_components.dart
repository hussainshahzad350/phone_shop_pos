import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phone_shop_pos/core/services/app_runtime_config.dart';
import 'package:phone_shop_pos/core/theme/app_interaction_tokens.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

const int _kDefaultPaginateThreshold = 80;
const double _kDesktopContentMaxWidth = 2200.0;
const double _kDesktopCardRadius = 16.0;

// Borders, fill and radius intentionally come from InputDecorationTheme so
// the field adapts to light/dark mode — hardcoded colors here previously
// rendered light-mode borders in dark mode.
InputDecoration appDesktopInputDecoration({
  String? labelText,
  String? hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  bool isDense = true,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    isDense: isDense,
  );
}

class AppDesktopScaffold extends StatelessWidget {
  const AppDesktopScaffold({
    super.key,
    required this.sidebar,
    required this.topBar,
    required this.child,
  });

  final Widget sidebar;
  final Widget topBar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: <Widget>[
          sidebar,
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: <Widget>[
                topBar,
                const Divider(height: 1),
                Expanded(
                  child: _DesktopContentArea(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: child,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationRailDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      labelType: width >= 1600
          ? NavigationRailLabelType.none
          : NavigationRailLabelType.all,
      extended: width >= 1600,
      minExtendedWidth: 208,
      destinations: destinations,
    );
  }
}

class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  AppRuntimeConfig.appName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.focusNode,
    this.hintText = 'Search',
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final String hintText;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: appDesktopInputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, child) {
            if (value.text.isEmpty) {
              return const SizedBox.shrink();
            }
            return IconButton(
              tooltip: 'Clear',
              onPressed: () {
                controller.clear();
                onChanged('');
              },
              icon: const Icon(Icons.clear),
            );
          },
        ),
      ),
    );
  }
}

/// Consistent empty-state placeholder: a muted icon above a short message,
/// with an optional call-to-action. Replaces ad-hoc `Center(Text('No …'))`
/// blocks so empty lists/tables read intentionally instead of looking broken.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 44, color: muted.withValues(alpha: 0.55)),
            AppSpacing.gapMd,
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
            if (action != null) ...<Widget>[
              AppSpacing.gapLg,
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class AppDataTable extends StatefulWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyMessage = 'No records found.',
    this.emptyIcon = Icons.inbox_outlined,
    this.rowsPerPage = 25,
    this.paginateThreshold = _kDefaultPaginateThreshold,
    this.dataRowMinHeight = 38,
    this.dataRowMaxHeight = 46,
    this.columnSpacing = 16,
    this.showCheckboxColumn = true,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final String emptyMessage;
  final IconData emptyIcon;
  final int rowsPerPage;
  final int paginateThreshold;
  final double dataRowMinHeight;
  final double dataRowMaxHeight;
  final double columnSpacing;
  final bool showCheckboxColumn;

  @override
  State<AppDataTable> createState() => _AppDataTableState();
}

class _AppDataTableState extends State<AppDataTable> {
  late final ScrollController _verticalScrollController;

  @override
  void initState() {
    super.initState();
    _verticalScrollController = ScrollController();
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    super.dispose();
  }

  // Returns columns with invisible labels — used in the body DataTable so the
  // header row occupies zero height while column widths still match the pinned
  // header above (cells carry explicit SizedBox widths that DataTable honours).
  static List<DataColumn> _inertColumns(List<DataColumn> columns) {
    return columns
        .map(
          (c) => DataColumn(
            label: const SizedBox.shrink(),
            numeric: c.numeric,
            onSort: c.onSort,
            mouseCursor: c.mouseCursor,
          ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return AppEmptyState(
        message: widget.emptyMessage,
        icon: widget.emptyIcon,
      );
    }

    // In touch mode, floor every table's row heights at the 48dp touch
    // minimum without touching the ~15 call sites that pass desktop-tier
    // heights. Max is raised together with min (the framework asserts
    // min <= max).
    final tokens = AppInteractionTokens.of(context);
    final dataRowMinHeight = tokens.isTouch
        ? math.max(widget.dataRowMinHeight, tokens.dataRowMinHeight)
        : widget.dataRowMinHeight;
    final dataRowMaxHeight = tokens.isTouch
        ? math.max(widget.dataRowMaxHeight, tokens.dataRowMaxHeight)
        : widget.dataRowMaxHeight;

    final effectiveRows = List<DataRow>.generate(widget.rows.length, (index) {
      final row = widget.rows[index];
      return DataRow(
        key: row.key,
        selected: row.selected,
        onSelectChanged: row.onSelectChanged,
        onLongPress: row.onLongPress,
        color: row.color ??
            WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.selected)) {
                return Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.10);
              }
              // Pointer hover highlight — makes tappable rows feel interactive.
              if (states.contains(WidgetState.hovered)) {
                return Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.05);
              }
              return index.isEven
                  ? Theme.of(context).colorScheme.surface
                  : Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.35);
            }),
        cells: row.cells,
      );
    });

    final effectiveColumns = widget.columns
        .map(
          (column) => DataColumn(
            label: DefaultTextStyle.merge(
              softWrap: true,
              overflow: TextOverflow.visible,
              maxLines: 2,
              child: column.label,
            ),
            tooltip: column.tooltip,
            numeric: column.numeric,
            onSort: column.onSort,
            mouseCursor: column.mouseCursor,
          ),
        )
        .toList(growable: false);

    if (widget.rows.length >= widget.paginateThreshold) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(_kDesktopCardRadius),
        child: PaginatedDataTable(
          columns: effectiveColumns,
          source: _StaticDataSource(effectiveRows),
          rowsPerPage: widget.rowsPerPage,
          availableRowsPerPage: const <int>[25, 50, 100],
          columnSpacing: widget.columnSpacing,
          dataRowMinHeight: dataRowMinHeight,
          dataRowMaxHeight: dataRowMaxHeight,
          headingRowHeight: 64,
          showCheckboxColumn: widget.showCheckboxColumn,
          showFirstLastButtons: true,
        ),
      );
    }

    // For non-paginated tables, use a sticky header when the widget has a
    // bounded height (i.e. it lives inside an Expanded or fixed-height
    // container). The header DataTable renders the heading row only; the body
    // DataTable renders data rows with a zero-height heading row so column
    // widths still align with the pinned header.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedHeight) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(_kDesktopCardRadius),
            child: Column(
              children: <Widget>[
                DataTable(
                  columns: effectiveColumns,
                  rows: const <DataRow>[],
                  columnSpacing: widget.columnSpacing,
                  headingRowHeight: 64,
                  dividerThickness: 0,
                  showCheckboxColumn: widget.showCheckboxColumn,
                ),
                Expanded(
                  child: Scrollbar(
                    controller: _verticalScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _verticalScrollController,
                      child: DataTable(
                        columns: _inertColumns(effectiveColumns),
                        rows: effectiveRows,
                        columnSpacing: widget.columnSpacing,
                        dataRowMinHeight: dataRowMinHeight,
                        dataRowMaxHeight: dataRowMaxHeight,
                        headingRowHeight: 0,
                        dividerThickness: 0.6,
                        showCheckboxColumn: widget.showCheckboxColumn,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Unbounded height (e.g. inside a scrolling analytics card): fall back
        // to the classic full-table scroll so the layout doesn't break.
        return Scrollbar(
          controller: _verticalScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _verticalScrollController,
            scrollDirection: Axis.vertical,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_kDesktopCardRadius),
              child: DataTable(
                columns: effectiveColumns,
                rows: effectiveRows,
                columnSpacing: widget.columnSpacing,
                dataRowMinHeight: dataRowMinHeight,
                dataRowMaxHeight: dataRowMaxHeight,
                headingRowHeight: 64,
                dividerThickness: 0.6,
                showCheckboxColumn: widget.showCheckboxColumn,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StaticDataSource extends DataTableSource {
  _StaticDataSource(this._rows);

  final List<DataRow> _rows;

  @override
  DataRow? getRow(int index) {
    if (index < 0 || index >= _rows.length) {
      return null;
    }
    return _rows[index];
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _rows.length;

  @override
  int get selectedRowCount => 0;
}

/// Sizes an [AlertDialog]'s content to a target design width, clamped to the
/// screen so wide dialogs (invoice/detail views up to 980px) never overflow
/// small windows, tablets or split screens.
///
/// On the enforced desktop minimum window (1366x768) every existing dialog
/// width fits, so this is a rendering no-op there — it only engages below
/// ~1100px of window width.
class AppDialogContentBox extends StatelessWidget {
  const AppDialogContentBox({
    super.key,
    required this.width,
    this.height,
    required this.child,
  });

  /// Design width the dialog was laid out for; used as the maximum.
  final double width;

  /// Optional fixed content height, clamped to the screen the same way.
  final double? height;

  final Widget child;

  // AlertDialog defaults: insetPadding 40px per side + content padding
  // ~24px per side. Leave that chrome out of the usable width.
  static const double _horizontalChrome = 128;
  static const double _verticalChrome = 160;
  static const double _minWidth = 280;
  static const double _minHeight = 200;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final maxWidth = math.max(_minWidth, screen.width - _horizontalChrome);
    final maxHeight = math.max(_minHeight, screen.height - _verticalChrome);
    return SizedBox(
      width: math.min(width, maxWidth),
      height: height == null ? null : math.min(height!, maxHeight),
      child: child,
    );
  }
}

class AppConfirmationDialog extends StatelessWidget {
  const AppConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): _DialogCancelIntent(),
        SingleActivator(LogicalKeyboardKey.enter): _DialogConfirmIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _DialogCancelIntent: CallbackAction<_DialogCancelIntent>(
            onInvoke: (_) {
              Navigator.of(context).pop(false);
              return null;
            },
          ),
          _DialogConfirmIntent: CallbackAction<_DialogConfirmIntent>(
            onInvoke: (_) {
              Navigator.of(context).pop(true);
              return null;
            },
          ),
        },
        child: AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(cancelLabel),
            ),
            FilledButton(
              autofocus: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopContentArea extends StatelessWidget {
  const _DesktopContentArea({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= _kDesktopContentMaxWidth) {
          return child;
        }
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: constraints.maxWidth.clamp(0.0, _kDesktopContentMaxWidth),
            child: child,
          ),
        );
      },
    );
  }
}

class _DialogCancelIntent extends Intent {
  const _DialogCancelIntent();
}

class _DialogConfirmIntent extends Intent {
  const _DialogConfirmIntent();
}

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.foreground,
  });

  final String label;
  final Color color;

  /// Explicit foreground color. When null, auto-derived from [color] brightness.
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ??
        (ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black87);
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class AppLoadingOverlay extends StatelessWidget {
  const AppLoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.label = 'Loading...',
  });

  final bool isLoading;
  final Widget child;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        child,
        if (isLoading)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.08),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Text(label),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
