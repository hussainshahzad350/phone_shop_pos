import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

/// A pulsing placeholder block used while real content loads.
///
/// Skeletons communicate the shape of incoming content and read as more
/// premium than a bare [CircularProgressIndicator] spinning in empty space.
/// Dependency-free: a gentle opacity pulse rather than a gradient shimmer.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = AppRadii.smRadius,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.35, end: 0.75).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.10);
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: widget.borderRadius,
        ),
      ),
    );
  }
}

/// A card-shaped skeleton matching the app's KPI / summary cards: a short
/// value line over a longer label line. Use a row/grid of these in a
/// `loading:` branch where cards will eventually render.
class AppSkeletonCard extends StatelessWidget {
  const AppSkeletonCard({super.key, this.height = 84});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.paddingLg,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            AppSkeleton(width: 96, height: 20),
            AppSpacing.gapSm,
            AppSkeleton(width: 64, height: 12),
          ],
        ),
      ),
    );
  }
}
