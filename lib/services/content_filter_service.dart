import 'package:firebase_database/firebase_database.dart';

/// Content Filter Service - Comprehensive profanity and abuse detection
/// Blocks inappropriate content and auto-reports violators to admin
class ContentFilterService {
  static final ContentFilterService _instance = ContentFilterService._internal();
  factory ContentFilterService() => _instance;
  ContentFilterService._internal();

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Comprehensive list of 50+ inappropriate words/phrases
  // This list includes profanity, slurs, hate speech, and harassment terms
  // Words are kept minimal here but pattern matching catches variations
  static const List<String> _bannedWords = [
    // Profanity
    'fuck', 'fucking', 'fucker', 'fucked', 'fck', 'f*ck', 'fuk',
    'shit', 'shits', 'shitty', 'sh*t', 'bullshit',
    'ass', 'asshole', 'assholes', 'a**hole', 'arse',
    'bitch', 'bitches', 'b*tch', 'biatch',
    'damn', 'dammit', 'goddamn',
    'bastard', 'bastards',
    'crap', 'crappy',
    'piss', 'pissed', 'pissing',
    'dick', 'dicks', 'd*ck',
    'cock', 'cocks',
    'cunt', 'c*nt',
    'whore', 'wh*re', 'slut', 'sluts',
    'pussy', 'p*ssy',
    
    // Hate speech & slurs
    'nigger', 'nigga', 'n*gger', 'n*gga',
    'faggot', 'fag', 'f*ggot', 'f*g',
    'retard', 'retarded', 'r*tard',
    'spic', 'wetback', 'beaner',
    'chink', 'gook', 'jap',
    'kike', 'k*ke',
    'cracker',
    'tranny', 'tr*nny',
    'dyke', 'd*ke',
    'homo', 'h*mo',
    
    // Harassment & threats
    'kill yourself', 'kys', 'go die',
    'rape', 'rapist',
    'pedophile', 'pedo', 'paedo',
    'molest', 'molester',
    'terrorist', 'bomb',
    'murder', 'murderer',
    
    // Abuse terms
    'idiot', 'idiots', 'moron', 'morons',
    'stupid', 'dumb', 'dumbass',
    'loser', 'losers',
    'ugly', 'fat', 'fatty',
    'scum', 'scumbag',
    'trash', 'garbage',
    'worthless', 'pathetic',
    'disgusting', 'gross',
    
    // Spam/scam related
    'spam', 'scam', 'scammer',
    'fraud', 'fraudster',
    'fake', 'phishing',
    
    // Sexual content
    'porn', 'p*rn', 'pornography',
    'sex', 'sexy', 'sexual',
    'nude', 'nudes', 'naked',
    'boobs', 'tits', 'titties',
    'penis', 'vagina', 'genitals',
    'masturbate', 'masturbation', 'jerk off',
    'orgasm', 'cum', 'c*m',
    'horny', 'h*rny',
  ];

  // Patterns for detecting leetspeak and obfuscation
  static final Map<String, String> _leetReplacements = {
    '0': 'o',
    '1': 'i',
    '3': 'e',
    '4': 'a',
    '5': 's',
    '7': 't',
    '8': 'b',
    '@': 'a',
    '\$': 's',
    '!': 'i',
  };

  /// Normalize text by replacing leetspeak characters
  String _normalizeLeetspeak(String text) {
    String normalized = text.toLowerCase();
    _leetReplacements.forEach((leet, normal) {
      normalized = normalized.replaceAll(leet, normal);
    });
    // Remove special characters that might be used to bypass filter
    normalized = normalized.replaceAll(RegExp(r'[._\-*#]+'), '');
    return normalized;
  }

  /// Check if text contains any banned words
  /// Returns a result with detected words and severity
  ContentFilterResult checkContent(String text) {
    final normalizedText = _normalizeLeetspeak(text);
    final detectedWords = <String>[];
    int severity = 0; // 0 = clean, 1 = mild, 2 = moderate, 3 = severe

    for (final word in _bannedWords) {
      final normalizedWord = word.toLowerCase().replaceAll('*', '');
      
      // Check for whole word match
      final pattern = RegExp(
        r'\b' + RegExp.escape(normalizedWord) + r'\b',
        caseSensitive: false,
      );
      
      if (pattern.hasMatch(normalizedText)) {
        detectedWords.add(word);
        
        // Determine severity
        if (_isSevere(word)) {
          severity = 3;
        } else if (_isModerate(word) && severity < 3) {
          severity = 2;
        } else if (severity < 2) {
          severity = 1;
        }
      }
    }

    return ContentFilterResult(
      isClean: detectedWords.isEmpty,
      detectedWords: detectedWords,
      severity: severity,
      originalText: text,
    );
  }

  bool _isSevere(String word) {
    final severeWords = [
      'nigger', 'nigga', 'faggot', 'fag', 'kike', 'chink',
      'kill yourself', 'kys', 'go die', 'rape', 'rapist',
      'pedophile', 'pedo', 'terrorist', 'murder',
    ];
    return severeWords.any((w) => word.toLowerCase().contains(w.toLowerCase()));
  }

  bool _isModerate(String word) {
    final moderateWords = [
      'fuck', 'shit', 'bitch', 'cunt', 'cock', 'dick',
      'retard', 'whore', 'slut', 'porn',
    ];
    return moderateWords.any((w) => word.toLowerCase().contains(w.toLowerCase()));
  }

  /// Filter and sanitize text, replacing bad words with asterisks
  String filterText(String text) {
    String filtered = text;
    
    for (final word in _bannedWords) {
      final normalizedWord = word.toLowerCase().replaceAll('*', '');
      final pattern = RegExp(
        r'\b' + RegExp.escape(normalizedWord) + r'\b',
        caseSensitive: false,
      );
      filtered = filtered.replaceAllMapped(pattern, (match) {
        return '*' * match.group(0)!.length;
      });
    }
    
    return filtered;
  }

  /// Validate content before sending - returns error message or null if valid
  Future<String?> validateContent(String text) async {
    final result = checkContent(text);
    
    if (!result.isClean) {
      if (result.severity >= 2) {
        return 'This message contains inappropriate content that is not allowed on EduVerse.';
      } else {
        return 'Please keep your language respectful. Some words in your message are not appropriate.';
      }
    }
    
    return null;
  }

  /// Report user to admin for using inappropriate content
  Future<void> reportUserForInappropriateContent({
    required String userId,
    required String userRole,
    required String contentType, // 'comment', 'question', 'review', etc.
    required String originalText,
    required List<String> detectedWords,
    required int severity,
    String? contentLocation, // Course ID, etc.
  }) async {
    try {
      await _db.child('user_reports').push().set({
        'userId': userId,
        'userRole': userRole,
        'contentType': contentType,
        'originalText': originalText,
        'detectedWords': detectedWords,
        'severity': severity,
        'severityLabel': _getSeverityLabel(severity),
        'contentLocation': contentLocation,
        'reportedAt': ServerValue.timestamp,
        'reportType': 'auto_filter',
        'status': 'pending',
        'autoDetected': true,
      });

      // If severity is high, also create an alert for admin
      if (severity >= 2) {
        await _db.child('admin_alerts').push().set({
          'type': 'inappropriate_content',
          'userId': userId,
          'userRole': userRole,
          'severity': severity,
          'severityLabel': _getSeverityLabel(severity),
          'message': 'User attempted to post inappropriate content ($contentType)',
          'detectedWords': detectedWords,
          'timestamp': ServerValue.timestamp,
          'read': false,
        });
      }

      // Track violations for user
      await _incrementUserViolations(userId);
    } catch (e) {
      // Silent fail - don't block user experience for logging errors
    }
  }

  String _getSeverityLabel(int severity) {
    switch (severity) {
      case 1:
        return 'mild';
      case 2:
        return 'moderate';
      case 3:
        return 'severe';
      default:
        return 'unknown';
    }
  }

  Future<void> _incrementUserViolations(String userId) async {
    try {
      final ref = _db.child('user_violations/$userId');
      final snapshot = await ref.get();
      
      int currentCount = 0;
      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        currentCount = data['count'] ?? 0;
      }

      await ref.set({
        'count': currentCount + 1,
        'lastViolation': ServerValue.timestamp,
      });

      // If user has too many violations, flag for review
      if (currentCount + 1 >= 3) {
        await _db.child('flagged_users/$userId').set({
          'reason': 'multiple_content_violations',
          'violationCount': currentCount + 1,
          'flaggedAt': ServerValue.timestamp,
          'status': 'pending_review',
        });
      }
    } catch (e) {
      // Silent fail
    }
  }

  /// Get user violation count
  Future<int> getUserViolationCount(String userId) async {
    try {
      final snapshot = await _db.child('user_violations/$userId/count').get();
      if (snapshot.exists && snapshot.value != null) {
        return snapshot.value as int;
      }
    } catch (e) {
      // Silent fail
    }
    return 0;
  }
}

/// Result of content filtering
class ContentFilterResult {
  final bool isClean;
  final List<String> detectedWords;
  final int severity; // 0-3
  final String originalText;

  ContentFilterResult({
    required this.isClean,
    required this.detectedWords,
    required this.severity,
    required this.originalText,
  });

  String get severityLabel {
    switch (severity) {
      case 1:
        return 'Mild';
      case 2:
        return 'Moderate';
      case 3:
        return 'Severe';
      default:
        return 'Clean';
    }
  }
}
