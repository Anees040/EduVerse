import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eduverse/views/splash_screen.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/services/theme_service.dart';
import 'package:eduverse/widgets/animated_dark_background.dart';

class EduVerseApp extends StatelessWidget {
  const EduVerseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          title: 'eduVerse',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme.copyWith(
            // Ensure no gaps in light theme
            scaffoldBackgroundColor: AppTheme.backgroundColor,
            canvasColor: AppTheme.backgroundColor,
          ),
          darkTheme: AppTheme.darkTheme.copyWith(
            // Transparent so AnimatedDarkBackground shows through
            scaffoldBackgroundColor: Colors.transparent,
            canvasColor: AppTheme.darkBackground,
          ),
          themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) {
            // Aggressive fix for white line - use LayoutBuilder for accurate sizing
            final mediaQuery = MediaQuery.of(context);
            final theme = Theme.of(context);

            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaleFactor: mediaQuery.textScaleFactor.clamp(0.8, 1.3),
              ),
              child: ScrollConfiguration(
                behavior: _NoOverscrollBehavior(),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDark =
                        Theme.of(context).brightness == Brightness.dark;
                    final bg = isDark
                        ? const AnimatedDarkBackground(
                            child: SizedBox.expand(),
                          )
                        : ColoredBox(
                            color: theme.scaffoldBackgroundColor,
                            child: const SizedBox.expand(),
                          );

                    return Stack(
                      children: [
                        bg,
                        SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: child ?? const SizedBox.shrink(),
                        ),
                      ],
                    );
                  },
                ),
              ),
            );
          },
          home: const Splashscreen(),
        );
      },
    );
  }
}

// Custom scroll behavior to prevent scrollbars and overflow indicators
class _NoOverscrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child; // Remove overscroll glow effect
  }

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics(); // Prevent bouncing that can cause visual gaps
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child; // Hide scrollbars completely
  }
}
