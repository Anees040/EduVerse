import 'package:flutter/material.dart';
import 'package:eduverse/utils/app_theme.dart';

/// KPI Card Widget for displaying key performance indicators
/// Responsive and theme-aware
class KPICard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final bool isLoading;
  final String? trend; // e.g., "+12%" or "-5%"
  final bool? isTrendPositive;

  const KPICard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.iconColor,
    this.backgroundColor,
    this.onTap,
    this.isLoading = false,
    this.trend,
    this.isTrendPositive,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: backgroundColor ?? AppTheme.getCardColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppTheme.darkBorder.withOpacity(0.5)
                  : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: isLoading ? _buildLoadingState(isDark) : _buildContent(isDark),
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
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: 80,
          height: 16,
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.darkBorder.withOpacity(0.3)
                : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 60,
          height: 12,
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.darkBorder.withOpacity(0.2)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(bool isDark) {
    final effectiveIconColor =
        iconColor ?? (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: effectiveIconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: effectiveIconColor, size: 24),
            ),
            if (trend != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      (isTrendPositive == true
                              ? (isDark
                                    ? AppTheme.darkSuccess
                                    : AppTheme.success)
                              : (isDark ? AppTheme.darkError : AppTheme.error))
                          .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isTrendPositive == true
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 14,
                      color: isTrendPositive == true
                          ? (isDark ? AppTheme.darkSuccess : AppTheme.success)
                          : (isDark ? AppTheme.darkError : AppTheme.error),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      trend!,
                      style: TextStyle(
                        color: isTrendPositive == true
                            ? (isDark ? AppTheme.darkSuccess : AppTheme.success)
                            : (isDark ? AppTheme.darkError : AppTheme.error),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          value,
          style: TextStyle(
            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: TextStyle(
              color: isDark
                  ? AppTheme.darkTextTertiary
                  : AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

/// Grid of KPI Cards with responsive layout
class KPICardGrid extends StatelessWidget {
  final List<KPICard> cards;

  const KPICardGrid({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive column count
    int crossAxisCount;
    if (screenWidth >= 1400) {
      crossAxisCount = 4;
    } else if (screenWidth >= 1000) {
      crossAxisCount = 3;
    } else if (screenWidth >= 600) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 1;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) => cards[index],
    );
  }
}
