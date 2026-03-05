import 'package:flutter/material.dart';
import 'package:eduverse/services/offline_service.dart';
import 'package:eduverse/utils/app_theme.dart';

/// A slim banner that appears at the top of the screen when the device
/// loses connectivity. Automatically hides when back online.
class OfflineIndicator extends StatelessWidget {
  const OfflineIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: OfflineService().connectivityStream,
      initialData: OfflineService().isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1,
            child: child,
          ),
          child: isOnline
              ? const SizedBox.shrink()
              : _OfflineBanner(key: const ValueKey('offline_banner')),
        );
      },
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF3D2D00) // subtle warm dark
            : const Color(0xFFFFF3E0), // amber 50
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AppTheme.darkWarning.withOpacity(0.3)
                : Colors.orange.shade200,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 16,
            color: isDark ? AppTheme.darkWarning : Colors.orange.shade800,
          ),
          const SizedBox(width: 8),
          Text(
            'You\'re offline — saved content is still available',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkWarning : Colors.orange.shade800,
            ),
          ),
        ],
      ),
    );
  }
}
