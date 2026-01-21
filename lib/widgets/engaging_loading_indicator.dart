import 'package:flutter/material.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'dart:math' as math;

/// An engaging loading indicator that works well in both light and dark themes.
/// Features smooth animations with educational/course-themed visuals.
class EngagingLoadingIndicator extends StatefulWidget {
  final String? message;
  final double size;
  final bool showMessage;

  const EngagingLoadingIndicator({
    super.key,
    this.message,
    this.size = 80,
    this.showMessage = true,
  });

  @override
  State<EngagingLoadingIndicator> createState() =>
      _EngagingLoadingIndicatorState();
}

class _EngagingLoadingIndicatorState extends State<EngagingLoadingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _dotController;
  late Animation<double> _pulseAnimation;

  final List<String> _loadingMessages = [
    'Loading your content...',
    'Preparing your videos...',
    'Getting things ready...',
    'Almost there...',
    'Fetching data...',
  ];

  int _currentMessageIndex = 0;

  @override
  void initState() {
    super.initState();

    // Rotation animation for the outer ring
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Pulse animation for the inner circle
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Dot animation controller
    _dotController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat();

    // Cycle through messages
    if (widget.showMessage && widget.message == null) {
      _cycleMessages();
    }
  }

  void _cycleMessages() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _currentMessageIndex =
              (_currentMessageIndex + 1) % _loadingMessages.length;
        });
        _cycleMessages();
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final primaryColor = isDark
        ? AppTheme.darkPrimaryLight
        : AppTheme.primaryColor;
    final accentColor = isDark ? AppTheme.darkAccent : AppTheme.accentColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer rotating ring
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationController.value * 2 * math.pi,
                    child: CustomPaint(
                      size: Size(widget.size, widget.size),
                      painter: _GradientArcPainter(
                        primaryColor: primaryColor,
                        accentColor: accentColor,
                        strokeWidth: widget.size * 0.08,
                      ),
                    ),
                  );
                },
              ),
              // Inner pulsing circle with icon
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: widget.size * 0.5,
                      height: widget.size * 0.5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryColor.withOpacity(isDark ? 0.3 : 0.2),
                            accentColor.withOpacity(isDark ? 0.3 : 0.2),
                          ],
                        ),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.school_rounded,
                        size: widget.size * 0.25,
                        color: primaryColor,
                      ),
                    ),
                  );
                },
              ),
              // Orbiting dots
              ...List.generate(3, (index) {
                return AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, child) {
                    final angle =
                        _rotationController.value * 2 * math.pi +
                        (index * 2 * math.pi / 3);
                    final radius = widget.size * 0.38;
                    return Transform.translate(
                      offset: Offset(
                        math.cos(angle) * radius,
                        math.sin(angle) * radius,
                      ),
                      child: Container(
                        width: widget.size * 0.08,
                        height: widget.size * 0.08,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: [
                            primaryColor,
                            accentColor,
                            AppTheme.success,
                          ][index],
                          boxShadow: [
                            BoxShadow(
                              color: [
                                primaryColor,
                                accentColor,
                                AppTheme.success,
                              ][index].withOpacity(0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        ),
        if (widget.showMessage) ...[
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              widget.message ?? _loadingMessages[_currentMessageIndex],
              key: ValueKey(widget.message ?? _currentMessageIndex),
              style: TextStyle(
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Animated dots
          _buildAnimatedDots(isDark),
        ],
      ],
    );
  }

  Widget _buildAnimatedDots(bool isDark) {
    return AnimatedBuilder(
      animation: _dotController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final progress = (_dotController.value + delay) % 1.0;
            final opacity = (math.sin(progress * math.pi)).clamp(0.3, 1.0);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    (isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor)
                        .withOpacity(opacity),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Custom painter for the gradient arc
class _GradientArcPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;
  final double strokeWidth;

  _GradientArcPainter({
    required this.primaryColor,
    required this.accentColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - strokeWidth) / 2,
    );

    final gradient = SweepGradient(
      colors: [
        primaryColor.withOpacity(0.0),
        primaryColor.withOpacity(0.3),
        primaryColor,
        accentColor,
        accentColor.withOpacity(0.3),
        accentColor.withOpacity(0.0),
      ],
      stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect,
      0,
      2 * math.pi * 0.75, // Draw 3/4 of the circle
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GradientArcPainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// A simple compact loading indicator for smaller spaces
class CompactLoadingIndicator extends StatefulWidget {
  final double size;
  final Color? color;

  const CompactLoadingIndicator({super.key, this.size = 24, this.color});

  @override
  State<CompactLoadingIndicator> createState() =>
      _CompactLoadingIndicatorState();
}

class _CompactLoadingIndicatorState extends State<CompactLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
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
    final color =
        widget.color ??
        (isDark ? AppTheme.darkPrimaryLight : AppTheme.primaryColor);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(painter: _CompactSpinnerPainter(color: color)),
          ),
        );
      },
    );
  }
}

class _CompactSpinnerPainter extends CustomPainter {
  final Color color;

  _CompactSpinnerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    final gradient = SweepGradient(colors: [color.withOpacity(0.0), color]);

    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, 2 * math.pi * 0.75, false, paint);
  }

  @override
  bool shouldRepaint(covariant _CompactSpinnerPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

/// Full screen loading overlay with engaging animation
class FullScreenLoading extends StatelessWidget {
  final String? message;

  const FullScreenLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Container(
      color: (isDark ? AppTheme.darkBackground : Colors.white).withOpacity(0.9),
      child: Center(
        child: EngagingLoadingIndicator(message: message, size: 100),
      ),
    );
  }
}
