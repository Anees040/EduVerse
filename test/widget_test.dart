// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:eduverse/services/theme_service.dart';
import 'package:eduverse/services/user_customization_service.dart';
import 'package:eduverse/features/admin/providers/admin_provider.dart';
import 'package:eduverse/views/eduverse_app.dart';

void main() {
  testWidgets('EduVerse app smoke test', (WidgetTester tester) async {
    // Build our app with required providers and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeService()),
          ChangeNotifierProvider.value(value: UserCustomizationService.instance),
          ChangeNotifierProvider(create: (_) => AdminProvider()),
        ],
        child: const EduVerseApp(),
      ),
    );

    // Verify that the app loads (splash screen shown)
    expect(find.byType(MaterialApp), findsOneWidget);

    // Drain the splash screen's 3-second navigation timer to avoid
    // "pending timer" test errors. Suppress Firebase errors from
    // the navigation attempt (Firebase not initialized in tests).
    final originalHandler = FlutterError.onError;
    FlutterError.onError = (details) {};
    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    FlutterError.onError = originalHandler;
  });
}
