import 'package:flutter/material.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'dart:math' as math;

/// Modern KPI Card Widget matching the reference design
/// Features: Title, Value, Mini Charts, Badges, Action Buttons
class ModernKPICard extends StatelessWidget {
  final String title;
  final String value;
  final String? badgeText;
  final Color? badgeColor;
  final String buttonText;
  final VoidCallback? onButtonTap;
  final Widget? chart;
  final bool isLoading;
  final Color accentColor;

  const ModernKPICard({
    super.key,
    required this.title,
    required this.value,
    this.badgeText,
    this.badgeColor,
    required this.buttonText,
    this.onButtonTap,
    this.chart,
    this.isLoading = false,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E2942),
                  const Color(0xFF162033),
                ]
              : [
                  Colors.white,
                  Colors.grey.shade50,
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.grey.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: isLoading ? _buildLoadingState(isDark) : _buildContent(context, isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 80,
          height: 14,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: 50,
          height: 28,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const Spacer(),
        Container(
          width: double.infinity,
          height: 36,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, bool isDark) {
    return InkWell(
      onTap: onButtonTap,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Title and Action Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white.withOpacity(0.7) : Colors.grey.shade600,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: accentColor.withOpacity(0.7),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Value and Chart Row
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Value Column
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.grey.shade900,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(height: 6),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? accentColor).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (badgeColor ?? accentColor).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              badgeText!,
                              style: TextStyle(
                                color: badgeColor ?? accentColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Chart
                if (chart != null)
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: chart!,
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Subtle tap indicator instead of large button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                buttonText,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: accentColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mini Sparkline Chart Widget
class MiniSparklineChart extends StatelessWidget {
  final List<double> data;
  final Color color;

  const MiniSparklineChart({
    super.key,
    required this.data,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox();

    return CustomPaint(
      size: const Size(double.infinity, 50),
      painter: _SparklinePainter(
        data: data,
        color: color,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  _SparklinePainter({
    required this.data,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.3),
          color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final maxValue = data.reduce(math.max);
    final minValue = data.reduce(math.min);
    final range = maxValue - minValue == 0 ? 1 : maxValue - minValue;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minValue) / range) * size.height * 0.8 - size.height * 0.1;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw dots at each data point
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i] - minValue) / range) * size.height * 0.8 - size.height * 0.1;
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Mini Bar Chart Widget
class MiniBarChart extends StatelessWidget {
  final List<double> data;
  final Color color;

  const MiniBarChart({
    super.key,
    required this.data,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox();

    final maxValue = data.reduce(math.max);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.map((value) {
        final height = maxValue == 0 ? 0.0 : (value / maxValue) * 40;
        return Container(
          width: 8,
          height: height.clamp(4.0, 40.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                color.withOpacity(0.6),
                color,
              ],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }).toList(),
    );
  }
}
