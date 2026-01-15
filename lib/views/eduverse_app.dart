import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:eduverse/views/splash_screen.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/services/theme_service.dart';

class EduVerseApp extends StatelessWidget {
  const EduVerseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return MaterialApp(
          title: 'eduVerse',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeService.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          // Fix for the 1px white line on the right side
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                // Remove any padding that might cause misalignment
                padding: MediaQuery.of(context).padding,
              ),
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  scrollbars: false, // Hide scrollbars to prevent white line
                ),
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: const Splashscreen(),
        );
      },
    );
  }
}
