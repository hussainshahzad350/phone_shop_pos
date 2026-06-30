import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:phone_shop_pos/core/routing/current_route_provider.dart';

/// Wraps a top-level screen that is kept alive inside the indexed-stack shell
/// so its transient UI state (selected tab, filters, search text, scroll
/// position) is reset once the user navigates away — the screen is shown fresh
/// on the next visit instead of where it was left.
///
/// Local widget state is reset by recreating the child subtree (a new key).
/// Global, provider-backed UI state is reset via the optional [onReset]
/// callback (e.g. invalidating filter/tab providers). Persistent data and user
/// preferences stored in their own providers are left untouched.
class RouteResetBoundary extends ConsumerStatefulWidget {
  const RouteResetBoundary({
    super.key,
    required this.routePath,
    required this.child,
    this.onReset,
  });

  final String routePath;
  final Widget child;
  final void Function(WidgetRef ref)? onReset;

  @override
  ConsumerState<RouteResetBoundary> createState() => _RouteResetBoundaryState();
}

class _RouteResetBoundaryState extends ConsumerState<RouteResetBoundary> {
  int _generation = 0;

  bool _matches(String path) =>
      path == widget.routePath || path.startsWith('${widget.routePath}/');

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(currentRoutePathProvider, (previous, next) {
      final leftScreen =
          previous != null && _matches(previous) && !_matches(next);
      if (leftScreen) {
        widget.onReset?.call(ref);
        setState(() => _generation++);
      }
    });
    return KeyedSubtree(
      key: ValueKey<int>(_generation),
      child: widget.child,
    );
  }
}
