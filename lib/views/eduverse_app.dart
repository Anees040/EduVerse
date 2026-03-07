import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eduverse/views/splash_screen.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/services/theme_service.dart';
import 'package:eduverse/services/user_customization_service.dart';
import 'package:eduverse/widgets/animated_dark_background.dart';
import 'package:eduverse/widgets/session_timeout_wrapper.dart';

class EduVerseApp extends StatelessWidget {
  const EduVerseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeService, UserCustomizationService>(
      builder: (context, themeService, customization, child) {
        return MaterialApp(
          title: 'eduVerse',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme.copyWith(
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
                textScaleFactor: (mediaQuery.textScaleFactor *
                        customization.fontScale)
                    .clamp(0.7, 1.5),
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
                          child: SessionTimeoutWrapper(
                            child: child ?? const SizedBox.shrink(),
                          ),
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
