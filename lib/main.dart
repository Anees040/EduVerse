import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:eduverse/views/eduverse_app.dart';
import 'package:eduverse/firebase_options.dart';
import 'package:eduverse/services/theme_service.dart';
import 'package:eduverse/services/user_customization_service.dart';
import 'package:eduverse/services/offline_service.dart';
import 'package:eduverse/features/admin/providers/admin_provider.dart';
import 'package:eduverse/services/platform_settings_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase and dotenv in parallel for faster startups
    await Future.wait([
      Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
      dotenv.load(fileName: ".env").catchError((error) {
        // If .env file is not found, continue anyway
        debugPrint('Warning: Could not load .env file: $error');
        return;
      }),
    ]);

    // Enable Firebase Database persistence for offline support and faster reads
    // Note: setPersistenceEnabled and keepSynced are not supported on web platform
    if (!kIsWeb) {
      FirebaseDatabase.instance.setPersistenceEnabled(true);
    }

    // Pre-load platform settings so they're cached for all screens
    await PlatformSettingsService.instance.ensureLoaded().catchError((e) {
      debugPrint('Warning: Could not load platform settings: $e');
    });

    // Start offline connectivity monitoring
    OfflineService().startMonitoring();
  } catch (e) {
    debugPrint('Initialization error: $e');
  }
  // Run the app with providers
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider.value(value: UserCustomizationService.instance),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
      ],
      child: const EduVerseApp(),
    ),
  );
}
