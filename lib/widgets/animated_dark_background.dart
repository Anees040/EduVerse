import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// A premium animated dark-mode background with subtle floating orbs
/// and a slowly shifting gradient. Only animates in dark mode —
/// in light mode it falls back to the standard background color.
///
/// Usage:
/// ```dart
/// Scaffold(
///   backgroundColor: Colors.transparent,
///   body: AnimatedDarkBackground(
///     child: YourContent(),
///   ),
/// );
/// ```
class AnimatedDarkBackground extends StatefulWidget {
  final Widget child;

  /// If true, the animation is always active; otherwise only in dark mode.
  final bool forceAnimate;

  const AnimatedDarkBackground({
    super.key,
    required this.child,
    this.forceAnimate = false,
  });

  @override
  State<AnimatedDarkBackground> createState() => _AnimatedDarkBackgroundState();
}

class _AnimatedDarkBackgroundState extends State<AnimatedDarkBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    if (!isDark && !widget.forceAnimate) {
      // Light mode — plain background, no animation overhead
      return Container(
        color: AppTheme.getBackgroundColor(context),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _DarkBackgroundPainter(_controller.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// The orb specification, generated once per painter instance.
class _Orb {
  final double cx; // center-x ratio (0-1)
  final double cy; // center-y ratio (0-1)
  final double radius; // fraction of screen width
  final Color color;
  final double speed; // multiplier for animation offset
  final double phase; // starting phase offset

  const _Orb({
    required this.cx,
    required this.cy,
    required this.radius,
    required this.color,
    required this.speed,
    required this.phase,
  });
}

class _DarkBackgroundPainter extends CustomPainter {
  final double t; // animation progress 0..1

  // Pre-defined orbs for a consistent premium look.
  // Using const so they're created once.
  static final List<_Orb> _orbs = [
    // Large cyan glow — top-right area
    _Orb(
      cx: 0.78,
      cy: 0.15,
      radius: 0.45,
      color: AppTheme.darkPrimary.withValues(alpha: 0.04),
      speed: 1.0,
      phase: 0.0,
    ),
    // Medium violet glow — bottom-left
    _Orb(
      cx: 0.20,
      cy: 0.80,
      radius: 0.38,
      color: AppTheme.darkGlowAlt.withValues(alpha: 0.035),
      speed: 0.7,
      phase: 0.33,
    ),
    // Small teal orb — center
    _Orb(
      cx: 0.50,
      cy: 0.50,
      radius: 0.30,
      color: AppTheme.darkAccent.withValues(alpha: 0.025),
      speed: 1.3,
      phase: 0.66,
    ),
    // Tiny gold accent — top-left
    _Orb(
      cx: 0.15,
      cy: 0.25,
      radius: 0.20,
      color: AppTheme.darkGold.withValues(alpha: 0.02),
      speed: 0.9,
      phase: 0.50,
    ),
    // Extra cyan glow — bottom-right
    _Orb(
      cx: 0.85,
      cy: 0.70,
      radius: 0.32,
      color: AppTheme.darkSecondary.withValues(alpha: 0.03),
      speed: 1.1,
      phase: 0.15,
    ),
  ];

  _DarkBackgroundPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // Fill with dark background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppTheme.darkBackground,
    );

    // Draw each animated orb
    for (final orb in _orbs) {
      final phase = (t * orb.speed + orb.phase) % 1.0;
      // Gentle figure-eight motion
      final dx = sin(phase * 2 * pi) * size.width * 0.05;
      final dy = sin(phase * 4 * pi) * size.height * 0.03;

      final center = Offset(
        orb.cx * size.width + dx,
        orb.cy * size.height + dy,
      );
      final radius = orb.radius * size.width;

      final gradient = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [orb.color, orb.color.withValues(alpha: 0.0)],
        stops: const [0.0, 1.0],
      );

      final paint = Paint()
        ..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: radius),
        );

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_DarkBackgroundPainter oldDelegate) => oldDelegate.t != t;
}

/// Helper: wraps a Scaffold body with the animated background.
/// Use this to quickly add the animated background to any screen.
///
/// ```dart
/// return Scaffold(
///   backgroundColor: Colors.transparent,
///   body: buildAnimatedBody(context, child: myContent),
/// );
/// ```
Widget buildAnimatedBody(BuildContext context, {required Widget child}) {
  return AnimatedDarkBackground(child: child);
}
