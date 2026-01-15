import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:eduverse/views/eduverse_app.dart';
import 'package:eduverse/firebase_options.dart';
import 'package:eduverse/services/theme_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase and dotenv in parallel for faster startup
    await Future.wait([
      Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ),
      dotenv.load(fileName: ".env").catchError((error) {
        // If .env file is not found, continue anyway
        print('Warning: Could not load .env file: $error');
        return;
      }),
    ]);
  } catch (e) {
    print('Initialization error: $e');
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeService(),
      child: const EduVerseApp(),
    ),
  );
}
