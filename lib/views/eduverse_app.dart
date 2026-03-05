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
        final accent = customization.accentColor;

        // Build light theme with user's accent color overrides
        final lightBase = AppTheme.lightTheme;
        final lightTheme = lightBase.copyWith(
          scaffoldBackgroundColor: AppTheme.backgroundColor,
          canvasColor: AppTheme.backgroundColor,
          colorScheme: lightBase.colorScheme.copyWith(
            primary: accent,
          ),
          appBarTheme: lightBase.appBarTheme.copyWith(
            backgroundColor: accent,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: const Color(0xFFF5F5F5),
              padding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              shadowColor: accent.withOpacity(0.4),
              textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: accent,
              textStyle: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          bottomNavigationBarTheme:
              lightBase.bottomNavigationBarTheme.copyWith(
            backgroundColor: accent,
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            elevation: 4,
          ),
          snackBarTheme: lightBase.snackBarTheme.copyWith(
            backgroundColor: accent,
          ),
          inputDecorationTheme:
              lightBase.inputDecorationTheme.copyWith(
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accent, width: 2),
            ),
          ),
          tabBarTheme: lightBase.tabBarTheme.copyWith(
            indicatorColor: accent,
          ),
        );

        // Build dark theme with user's accent color overrides.
        // Adapt the accent so it always looks good on a dark background.
        final darkAccent = AppTheme.adaptAccentForDarkMode(accent);
        final darkBase = AppTheme.darkTheme;
        final darkThemeData = darkBase.copyWith(
          scaffoldBackgroundColor: Colors.transparent,
          canvasColor: AppTheme.darkBackground,
          colorScheme: darkBase.colorScheme.copyWith(
            primary: darkAccent,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: darkBase.elevatedButtonTheme.style?.copyWith(
              backgroundColor: WidgetStatePropertyAll(darkAccent),
              shadowColor:
                  WidgetStatePropertyAll(darkAccent.withOpacity(0.5)),
            ),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: darkAccent,
            foregroundColor: Colors.white,
            elevation: 4,
          ),
          tabBarTheme: darkBase.tabBarTheme.copyWith(
            indicatorColor: darkAccent,
          ),
          // Also adapt switch / checkbox / radio / slider accents
          switchTheme: darkBase.switchTheme.copyWith(
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return darkAccent;
              return AppTheme.darkTextSecondary;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return darkAccent.withOpacity(0.4);
              }
              return AppTheme.darkElevated;
            }),
          ),
          progressIndicatorTheme: darkBase.progressIndicatorTheme.copyWith(
            color: darkAccent,
          ),
          inputDecorationTheme: darkBase.inputDecorationTheme.copyWith(
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: darkAccent, width: 2),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: darkAccent,
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          bottomNavigationBarTheme: darkBase.bottomNavigationBarTheme.copyWith(
            selectedItemColor: darkAccent,
          ),
          sliderTheme: darkBase.sliderTheme.copyWith(
            activeTrackColor: darkAccent,
            thumbColor: darkAccent,
            overlayColor: darkAccent.withOpacity(0.2),
            valueIndicatorColor: darkAccent,
          ),
        );

        return MaterialApp(
          title: 'eduVerse',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkThemeData,
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
