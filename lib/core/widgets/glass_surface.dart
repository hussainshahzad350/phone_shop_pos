import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:phone_shop_pos/core/theme/app_spacing.dart';

/// Full-screen gradient canvas with soft glowing orbs.
/// Wrap [AppDesktopScaffold] body with this so [GlassSurface] panels have
/// something to blur against.
class AppGlassBackground extends StatelessWidget {
  const AppGlassBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const <Color>[
                      Color(0xFF0D0B2A),
                      Color(0xFF12103A),
                      Color(0xFF0B1629),
                    ]
                  : const <Color>[
                      Color(0xFFEDF0FF),
                      Color(0xFFF3EEFF),
                      Color(0xFFECF5FF),
                    ],
            ),
          ),
        ),
        // Blue orb — top-right
        _Orb(
          alignment: const Alignment(1.2, -0.9),
          color: const Color(0xFF5167F6),
          size: 480,
          opacity: isDark ? 0.28 : 0.14,
        ),
        // Purple orb — bottom-left
        _Orb(
          alignment: const Alignment(-1.1, 0.85),
          color: const Color(0xFF7C3AED),
          size: 400,
          opacity: isDark ? 0.20 : 0.09,
        ),
        // Sky-blue orb — center-right
        _Orb(
          alignment: const Alignment(0.45, 0.55),
          color: const Color(0xFF0EA5E9),
          size: 300,
          opacity: isDark ? 0.16 : 0.07,
        ),
        child,
      ],
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.alignment,
    required this.color,
    required this.size,
    required this.opacity,
  });

  final Alignment alignment;
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: <Color>[
                color.withValues(alpha: opacity),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Glassmorphism panel: blurs the content behind it and overlays a
/// semi-transparent frosted surface.
///
/// Needs [AppGlassBackground] (or any colorful gradient) somewhere above in the
/// tree — BackdropFilter has nothing to blur against a plain white background.
///
/// [ClipRRect] is required to contain the blur within the border radius.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = AppRadii.lgRadius,
    this.blur = 12.0,

    /// Light-mode surface opacity: higher = more opaque = less glassy.
    this.lightOpacity = 0.70,

    /// Dark-mode surface opacity.
    this.darkOpacity = 0.13,
    this.showBorder = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final double blur;
  final double lightOpacity;
  final double darkOpacity;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? Colors.white.withValues(alpha: darkOpacity)
        : Colors.white.withValues(alpha: lightOpacity);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.55);

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: borderRadius,
            border: showBorder
                ? Border.all(color: borderColor, width: 0.8)
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}
