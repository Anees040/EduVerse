import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Moderation Service - Content filtering and flagging
class ModerationService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Default banned words list (can be extended via admin panel)
  static const List<String> _defaultBannedWords = [
    // Add common profanity/abuse words here - keeping it minimal for code review
    'spam',
    'scam',
    // The actual list would be more comprehensive
  ];

  // Cache for banned words from database
  List<String>? _cachedBannedWords;
  DateTime? _lastFetch;

  /// Get the complete list of banned words (cached)
  Future<List<String>> getBannedWords() async {
    // Refresh cache every 5 minutes
    if (_cachedBannedWords != null &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!).inMinutes < 5) {
      return _cachedBannedWords!;
    }

    try {
      final snapshot = await _db.child('moderation/bannedWords').get();
      if (snapshot.exists && snapshot.value != null) {
        final words = List<String>.from(snapshot.value as List);
        _cachedBannedWords = [..._defaultBannedWords, ...words];
      } else {
        _cachedBannedWords = _defaultBannedWords;
      }
      _lastFetch = DateTime.now();
      return _cachedBannedWords!;
    } catch (e) {
      return _defaultBannedWords;
    }
  }

  /// Check if text contains banned words
  /// Returns the list of found banned words, or empty list if clean
  Future<List<String>> checkForBannedWords(String text) async {
    final bannedWords = await getBannedWords();
    final lowerText = text.toLowerCase();
    final foundWords = <String>[];

    for (final word in bannedWords) {
      // Check for whole word match using word boundaries
      final pattern = RegExp(r'\b' + RegExp.escape(word.toLowerCase()) + r'\b');
      if (pattern.hasMatch(lowerText)) {
        foundWords.add(word);
      }
    }

    return foundWords;
  }

  /// Filter/redact banned words from text
  /// Returns cleaned text with banned words replaced by asterisks
  Future<String> filterText(String text) async {
    final bannedWords = await getBannedWords();
    String filteredText = text;

    for (final word in bannedWords) {
      final pattern = RegExp(
        r'\b' + RegExp.escape(word) + r'\b',
        caseSensitive: false,
      );
      filteredText = filteredText.replaceAll(
        pattern,
        '*' * word.length,
      );
    }

    return filteredText;
  }

  /// Log a moderation event (blocked content attempt)
  Future<void> logModerationEvent({
    required String userId,
    required String userRole,
    required String contentType,
    required String originalText,
    required List<String> detectedWords,
  }) async {
    try {
      await _db.child('moderation/logs').push().set({
        'userId': userId,
        'userRole': userRole,
        'contentType': contentType,
        'originalText': originalText,
        'detectedWords': detectedWords,
        'timestamp': ServerValue.timestamp,
        'status': 'blocked',
      });
    } catch (e) {
      // Silent fail for logging
    }
  }

  /// Flag content for review
  Future<bool> flagContent({
    required String contentId,
    required String contentType,
    required String contentPath,
    required String reason,
    String? reportedBy,
  }) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      
      // Update the content with flagged status
      await _db.child(contentPath).update({
        'isReported': true,
        'flagged': true,
        'reportedBy': reportedBy ?? currentUser?.uid,
        'reportReason': reason,
        'reportedAt': ServerValue.timestamp,
      });

      // Add to moderation queue
      await _db.child('moderation/queue').push().set({
        'contentId': contentId,
        'contentType': contentType,
        'contentPath': contentPath,
        'reason': reason,
        'reportedBy': reportedBy ?? currentUser?.uid,
        'timestamp': ServerValue.timestamp,
        'status': 'pending',
      });

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Hide content locally (for the user who flagged it)
  /// This stores hidden content IDs in user's local preferences in Firebase
  Future<void> hideContentForUser(String contentId, String contentType) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      await _db
          .child('userPreferences/${currentUser.uid}/hiddenContent')
          .child(contentId)
          .set({
        'contentType': contentType,
        'hiddenAt': ServerValue.timestamp,
      });
    } catch (e) {
      // Silent fail
    }
  }

  /// Check if content is hidden for current user
  Future<bool> isContentHiddenForUser(String contentId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return false;

      final snapshot = await _db
          .child('userPreferences/${currentUser.uid}/hiddenContent/$contentId')
          .get();

      return snapshot.exists;
    } catch (e) {
      return false;
    }
  }

  /// Get all hidden content IDs for current user
  Future<Set<String>> getHiddenContentIds() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return {};

      final snapshot = await _db
          .child('userPreferences/${currentUser.uid}/hiddenContent')
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final map = Map<String, dynamic>.from(snapshot.value as Map);
        return map.keys.toSet();
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  /// Add banned word (admin only)
  Future<bool> addBannedWord(String word) async {
    try {
      final existing = await getBannedWords();
      if (!existing.contains(word.toLowerCase())) {
        final snapshot = await _db.child('moderation/bannedWords').get();
        List<String> words = [];
        if (snapshot.exists && snapshot.value != null) {
          words = List<String>.from(snapshot.value as List);
        }
        words.add(word.toLowerCase());
        await _db.child('moderation/bannedWords').set(words);
        _cachedBannedWords = null; // Clear cache
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Remove banned word (admin only)
  Future<bool> removeBannedWord(String word) async {
    try {
      final snapshot = await _db.child('moderation/bannedWords').get();
      if (snapshot.exists && snapshot.value != null) {
        final words = List<String>.from(snapshot.value as List);
        words.remove(word.toLowerCase());
        await _db.child('moderation/bannedWords').set(words);
        _cachedBannedWords = null; // Clear cache
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get moderation logs for admin
  Future<List<Map<String, dynamic>>> getModerationLogs({int limit = 50}) async {
    try {
      final snapshot = await _db
          .child('moderation/logs')
          .orderByChild('timestamp')
          .limitToLast(limit)
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final logsMap = Map<String, dynamic>.from(snapshot.value as Map);
        final logs = logsMap.entries.map((entry) {
          return {
            'id': entry.key,
            ...Map<String, dynamic>.from(entry.value as Map),
          };
        }).toList();
        
        // Sort by timestamp descending
        logs.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
        return logs;
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
