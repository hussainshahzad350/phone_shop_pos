import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phone_shop_pos/core/services/app_runtime_config.dart';

const int _kDefaultPaginateThreshold = 80;
const double _kDesktopContentMaxWidth = 2200.0;
const double _kDesktopCardRadius = 16.0;

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
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
    ),
    enabledBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: Color(0xFFD7DBE7)),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: Color(0xFF5167F6), width: 1.2),
    ),
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
                const Divider(height: 1),
                const _AppFooterBar(),
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
        padding: const EdgeInsets.symmetric(horizontal: 16),
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

class AppDataTable extends StatefulWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyMessage = 'No records found.',
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
  late final ScrollController _horizontalScrollController;
  late final ScrollController _verticalScrollController;

  @override
  void initState() {
    super.initState();
    _horizontalScrollController = ScrollController();
    _verticalScrollController = ScrollController();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return Center(child: Text(widget.emptyMessage));
    }

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

    if (widget.rows.length >= widget.paginateThreshold) {
      return Scrollbar(
        controller: _horizontalScrollController,
        thumbVisibility: true,
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.horizontal,
        child: SingleChildScrollView(
          controller: _horizontalScrollController,
          scrollDirection: Axis.horizontal,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kDesktopCardRadius),
            child: PaginatedDataTable(
              columns: widget.columns,
              source: _StaticDataSource(effectiveRows),
              rowsPerPage: widget.rowsPerPage,
              availableRowsPerPage: const <int>[25, 50, 100],
              columnSpacing: widget.columnSpacing,
              dataRowMinHeight: widget.dataRowMinHeight,
              dataRowMaxHeight: widget.dataRowMaxHeight,
              headingRowHeight: 44,
              showCheckboxColumn: widget.showCheckboxColumn,
              showFirstLastButtons: true,
            ),
          ),
        ),
      );
    }

    return Scrollbar(
      controller: _verticalScrollController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalScrollController,
        scrollDirection: Axis.vertical,
        child: Scrollbar(
          controller: _horizontalScrollController,
          thumbVisibility: true,
          notificationPredicate: (notification) =>
              notification.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_kDesktopCardRadius),
              child: DataTable(
                columns: widget.columns,
                rows: effectiveRows,
                columnSpacing: widget.columnSpacing,
                dataRowMinHeight: widget.dataRowMinHeight,
                dataRowMaxHeight: widget.dataRowMaxHeight,
                headingRowHeight: 44,
                dividerThickness: 0.6,
                showCheckboxColumn: widget.showCheckboxColumn,
              ),
            ),
          ),
        ),
      ),
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

class AppShortcutHint extends StatelessWidget {
  const AppShortcutHint({
    super.key,
    required this.label,
    required this.shortcut,
  });

  final String label;
  final String shortcut;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$label ($shortcut)',
      child: Chip(
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        label: Text('$label: $shortcut', style: const TextStyle(fontSize: 11)),
      ),
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

class _AppFooterBar extends StatelessWidget {
  const _AppFooterBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: <Widget>[
            Text(
              '${AppRuntimeConfig.appName} • ${AppRuntimeConfig.contactPhone}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            Text(
              'Developed by ${AppRuntimeConfig.developerName}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final brightness = ThemeData.estimateBrightnessForColor(color);
    final foreground =
        brightness == Brightness.dark ? Colors.white : Colors.black87;
    return Chip(
      label: Text(
        label,
        style: TextStyle(fontSize: 11, color: foreground),
      ),
      backgroundColor: color,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
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
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
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
