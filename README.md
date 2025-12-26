
# EduVerse

A modern, cross-platform educational learning app built with Flutter.

EduVerse provides courses, Q&A, video lessons, bookmarks, notifications,
and AI-assisted features to enhance learning and content discovery.

## Screenshots

Add screenshots or GIFs of the app in `assets/` and reference them here.

## Key Features

- Course discovery and enrollment
- Video playback with custom player widget
- Q&A and discussion threads
- Bookmarks and offline caching
- Push notifications
- User authentication and profiles
- AI-powered assistance (chat / content suggestions)

## Tech Stack

- Flutter (Dart)
- Firebase (Auth, Firestore, Cloud Functions, Messaging)
- Cloudinary (media upload service integration)

## Prerequisites

- Flutter SDK (stable channel)
- Dart
- Android Studio / Xcode (for mobile builds)
- Firebase project credentials (see `lib/firebase_options.dart`)

## Getting Started (Development)

1. Clone the repository

	```bash
	git clone <your-repo-url>
	cd EduVerse
	```

2. Install dependencies

	```bash
	flutter pub get
	```

3. Configure Firebase

	- Ensure `lib/firebase_options.dart` is generated for your Firebase project.
	- Place platform Firebase config files in `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist` as needed.

4. Run the app

	```bash
	flutter run
	```

## Building

- Android (APK): `flutter build apk --release`
- iOS (ipa): Follow Xcode export workflow after `flutter build ios --release`
- Web: `flutter build web`

## Testing

Run unit and widget tests with:

```bash
flutter test
```

## Contributing

Contributions are welcome. Please open issues for bugs or feature requests and
submit pull requests for changes. Follow these guidelines:

- Fork the repository
- Create a feature branch
- Run and add tests for your changes
- Open a pull request with a clear description

## License

This project does not include a license file. Add a `LICENSE` file if you
intend to publish under an open-source license (MIT, Apache-2.0, etc.).

## Contact

Project maintained by the EduVerse team. For questions, open an issue or contact the repository owner.

## Chat migration (chat_history → chat_sessions + chat_messages)

We added a migration tool to move legacy `chat_history` data into the new chat model without deleting the original data.

Files:
- `scripts/migrate_chat_history.js` — idempotent Node.js script. Supports `--dry-run` and `--apply`.

Usage:

```bash
# dry-run (no writes)
node scripts/migrate_chat_history.js --dry-run

# apply (perform writes). Ensure GOOGLE_APPLICATION_CREDENTIALS points to a service account JSON
node scripts/migrate_chat_history.js --apply
```

What the script does:
- For each `uid` under `chat_history/{uid}`, creates a deterministic legacy session `chat_sessions/legacy-{uid}` if it does not already exist.
- Copies messages from `chat_history/{uid}/{chatId}/messages/{msgId}` into `chat_messages/legacy-{uid}/{msgId}` preserving timestamps and message ids.
- Adds `student/{uid}/chatIds/{legacyChatId}: true` or `teacher/{uid}/chatIds/{legacyChatId}: true` depending on which node exists.
- Does NOT delete or modify `chat_history`. Run the script and verify results before deleting legacy data.

Rollback: Keep a record of created legacy chatIds (they follow `legacy-{uid}` naming). To rollback, remove the created `chat_sessions/legacy-{uid}` and `chat_messages/legacy-{uid}` and the `chatIds` references.

