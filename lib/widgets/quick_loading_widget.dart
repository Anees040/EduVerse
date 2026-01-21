import 'package:flutter/material.dart';
import 'package:eduverse/utils/app_theme.dart';

/// A simple, fast loading widget for quick screen transitions.
/// Uses minimal animations for better performance.
class QuickLoadingWidget extends StatelessWidget {
  final String? message;
  final double size;
  final double strokeWidth;

  const QuickLoadingWidget({
    super.key,
    this.message,
    this.size = 36,
    this.strokeWidth = 3,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final primaryColor = isDark
        ? AppTheme.darkPrimaryLight
        : AppTheme.primaryColor;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              strokeWidth: strokeWidth,
              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              backgroundColor: primaryColor.withOpacity(0.2),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: TextStyle(
                color: AppTheme.getTextSecondary(context),
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A full-screen loading overlay with fast transition.
class QuickLoadingOverlay extends StatelessWidget {
  final String? message;
  final bool isTransparent;

  const QuickLoadingOverlay({
    super.key,
    this.message,
    this.isTransparent = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Container(
      color: isTransparent
          ? Colors.black26
          : (isDark ? AppTheme.darkBackground : Colors.white),
      child: QuickLoadingWidget(message: message),
    );
  }
}

/// An inline loading placeholder for lists and cards.
class InlineLoadingWidget extends StatelessWidget {
  final double height;

  const InlineLoadingWidget({super.key, this.height = 60});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    final primaryColor = isDark
        ? AppTheme.darkPrimaryLight
        : AppTheme.primaryColor;

    return SizedBox(
      height: height,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
          ),
        ),
      ),
    );
  }
}
