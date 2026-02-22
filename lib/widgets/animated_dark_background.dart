import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

/// Premium animated dark-mode background with mesh gradients, floating
/// particles, and subtle grid lines. Designed for a modern fintech / gaming
/// premium feel. Only animates in dark mode — light mode gets a plain
/// background color with zero overhead.
class AnimatedDarkBackground extends StatefulWidget {
  final Widget child;
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
      duration: const Duration(seconds: 30),
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
      return ColoredBox(color: AppTheme.backgroundColor, child: widget.child);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _PremiumDarkPainter(_controller.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ─── Mesh Blob Spec ─────────────────────────────────────────────────────────
class _MeshBlob {
  final double cx, cy, rx, ry;
  final Color color;
  final double speed, phase;

  const _MeshBlob({
    required this.cx,
    required this.cy,
    required this.rx,
    required this.ry,
    required this.color,
    required this.speed,
    required this.phase,
  });
}

// ─── Particle Spec ──────────────────────────────────────────────────────────
class _Particle {
  final double x, y, size, speed, phase;
  final Color color;

  const _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.phase,
    required this.color,
  });
}

// ─── Painter ────────────────────────────────────────────────────────────────
class _PremiumDarkPainter extends CustomPainter {
  final double t;

  _PremiumDarkPainter(this.t);

  // Large mesh-gradient blobs — clearly visible, slowly drifting
  static final List<_MeshBlob> _blobs = [
    // Cyan-teal blob — top-right quadrant
    _MeshBlob(
      cx: 0.80,
      cy: 0.10,
      rx: 0.55,
      ry: 0.35,
      color: const Color(0xFF4CC9F0).withValues(alpha: 0.12),
      speed: 0.6,
      phase: 0.0,
    ),
    // Deep violet blob — bottom-left
    _MeshBlob(
      cx: 0.15,
      cy: 0.85,
      rx: 0.50,
      ry: 0.40,
      color: const Color(0xFF7B68EE).withValues(alpha: 0.10),
      speed: 0.4,
      phase: 0.5,
    ),
    // Teal-green center
    _MeshBlob(
      cx: 0.45,
      cy: 0.45,
      rx: 0.40,
      ry: 0.30,
      color: const Color(0xFF2EC4B6).withValues(alpha: 0.08),
      speed: 0.8,
      phase: 0.25,
    ),
    // Blue blob — top-left corner
    _MeshBlob(
      cx: 0.10,
      cy: 0.20,
      rx: 0.35,
      ry: 0.28,
      color: const Color(0xFF4895EF).withValues(alpha: 0.09),
      speed: 0.5,
      phase: 0.75,
    ),
    // Pink-magenta accent — bottom-right
    _MeshBlob(
      cx: 0.85,
      cy: 0.70,
      rx: 0.38,
      ry: 0.32,
      color: const Color(0xFFE040FB).withValues(alpha: 0.07),
      speed: 0.7,
      phase: 0.4,
    ),
  ];

  // Floating particles — twinkling dots
  static final List<_Particle> _particles = List.generate(25, (i) {
    final rng = Random(i * 31 + 7);
    final colors = [
      const Color(0xFF4CC9F0),
      const Color(0xFF72EFDD),
      const Color(0xFF7B68EE),
      const Color(0xFF4895EF),
      const Color(0xFFE3B341),
      const Color(0xFF2EC4B6),
    ];
    return _Particle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      size: 1.0 + rng.nextDouble() * 2.0,
      speed: 0.3 + rng.nextDouble() * 0.7,
      phase: rng.nextDouble(),
      color: colors[i % colors.length].withValues(
        alpha: 0.3 + rng.nextDouble() * 0.4,
      ),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Base gradient fill (dark → slightly lighter bottom)
    final basePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF12141A), // Deep dark top-left
          Color(0xFF1A1D24), // Standard dark
          Color(0xFF1E2230), // Slightly lighter bottom-right
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, basePaint);

    // 2. Subtle grid lines for depth
    _drawGrid(canvas, size);

    // 3. Mesh gradient blobs
    for (final blob in _blobs) {
      _drawBlob(canvas, size, blob);
    }

    // 4. Floating particles
    for (final p in _particles) {
      _drawParticle(canvas, size, p);
    }

    // 5. Subtle top edge glow line
    _drawEdgeGlow(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF2A2F3A).withValues(alpha: 0.25)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 60.0;
    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawBlob(Canvas canvas, Size size, _MeshBlob blob) {
    final phase = (t * blob.speed + blob.phase) % 1.0;
    // Smooth orbit / drift
    final dx = sin(phase * 2 * pi) * size.width * 0.06;
    final dy = cos(phase * 2 * pi * 0.7 + 0.3) * size.height * 0.04;

    final center = Offset(
      blob.cx * size.width + dx,
      blob.cy * size.height + dy,
    );
    final rx = blob.rx * size.width;
    final ry = blob.ry * size.height;

    // Pulsing alpha
    final pulseAlpha = 0.85 + 0.15 * sin(phase * 2 * pi);

    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        blob.color.withValues(alpha: (blob.color.a * pulseAlpha)),
        blob.color.withValues(alpha: (blob.color.a * pulseAlpha * 0.4)),
        blob.color.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final rect = Rect.fromCenter(center: center, width: rx * 2, height: ry * 2);
    final paint = Paint()..shader = gradient.createShader(rect);

    // Draw as ellipse for more organic shape
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(phase * pi * 0.3);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawOval(rect, paint);
    canvas.restore();
  }

  void _drawParticle(Canvas canvas, Size size, _Particle p) {
    final phase = (t * p.speed + p.phase) % 1.0;
    // Gentle upward drift + slight horizontal sway
    final x = (p.x + sin(phase * 2 * pi) * 0.02) * size.width;
    final rawY = (p.y - phase * 0.3) % 1.0;
    final y = rawY * size.height;

    // Twinkle effect
    final alpha = (0.4 + 0.6 * sin(phase * 4 * pi).abs());
    final paint = Paint()
      ..color = p.color.withValues(alpha: p.color.a * alpha)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.size * 0.8);

    canvas.drawCircle(Offset(x, y), p.size, paint);

    // Tiny bright core
    final corePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5 * alpha);
    canvas.drawCircle(Offset(x, y), p.size * 0.3, corePaint);
  }

  void _drawEdgeGlow(Canvas canvas, Size size) {
    // Animated glow line at the very top
    final phase = (t * 0.5) % 1.0;
    final glowX = phase * size.width * 1.5 - size.width * 0.25;

    final glowPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF4CC9F0).withValues(alpha: 0.15),
          const Color(0xFF7B68EE).withValues(alpha: 0.12),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(glowX, 0, size.width * 0.5, 2));

    canvas.drawRect(Rect.fromLTWH(glowX, 0, size.width * 0.5, 2), glowPaint);
  }

  @override
  bool shouldRepaint(_PremiumDarkPainter oldDelegate) => oldDelegate.t != t;
}

/// Convenience helper
Widget buildAnimatedBody(BuildContext context, {required Widget child}) {
  return AnimatedDarkBackground(child: child);
}
