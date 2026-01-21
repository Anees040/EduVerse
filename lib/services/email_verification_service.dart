import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;

class EmailVerificationService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Local email server URL (handles CORS and proxies to Mailjet)
  static const String _emailServerUrl =
      'http://localhost:3001/send-verification';

  // Generate 6-digit verification code
  String _generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Check rate limit for verification code sending (max 2 per week)
  // Returns null if within limit, or error message if exceeded
  Future<String?> checkVerificationCodeRateLimit(String email) async {
    final emailKey = email
        .toLowerCase()
        .trim()
        .replaceAll('.', '_')
        .replaceAll('@', '_at_');

    try {
      final snapshot = await _db
          .child('verification_code_attempts')
          .child(emailKey)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return null; // No previous attempts, within limit
      }

      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final attempts = data['attempts'] as List<dynamic>? ?? [];

      final currentTime = DateTime.now().millisecondsSinceEpoch;
      final oneWeekMs = 7 * 24 * 60 * 60 * 1000; // 7 days in milliseconds

      // Filter to only count attempts within the last week
      final recentAttempts = attempts.where((timestamp) {
        return (currentTime - (timestamp as int)) < oneWeekMs;
      }).toList();

      if (recentAttempts.length >= 2) {
        // Calculate when the oldest attempt will expire
        final oldestAttempt =
            recentAttempts.reduce((a, b) => (a as int) < (b as int) ? a : b)
                as int;
        final daysLeft =
            ((oldestAttempt + oneWeekMs - currentTime) / (24 * 60 * 60 * 1000))
                .ceil();
        return 'You have reached the maximum of 2 password reset attempts per week. Please try again in $daysLeft day(s).';
      }

      return null; // Within limit
    } catch (e) {
      debugPrint('Error checking verification rate limit: $e');
      return null; // If we can't check, allow the attempt
    }
  }

  // Record verification code attempt for rate limiting
  Future<void> _recordVerificationAttempt(String email) async {
    final emailKey = email
        .toLowerCase()
        .trim()
        .replaceAll('.', '_')
        .replaceAll('@', '_at_');
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    final oneWeekMs = 7 * 24 * 60 * 60 * 1000;

    try {
      final snapshot = await _db
          .child('verification_code_attempts')
          .child(emailKey)
          .get();
      List<dynamic> attempts = [];

      if (snapshot.exists && snapshot.value != null) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        attempts = List<dynamic>.from(data['attempts'] ?? []);
        // Only keep attempts from the last week
        attempts = attempts
            .where(
              (timestamp) => (currentTime - (timestamp as int)) < oneWeekMs,
            )
            .toList();
      }

      attempts.add(currentTime);

      await _db.child('verification_code_attempts').child(emailKey).set({
        'email': email.toLowerCase().trim(),
        'attempts': attempts,
        'lastAttempt': currentTime,
      });

      debugPrint(
        'Verification code attempt recorded. Total attempts this week: ${attempts.length}',
      );
    } catch (e) {
      debugPrint('Error recording verification attempt: $e');
    }
  }

  // Send verification code to email
  Future<void> sendVerificationCode(String email) async {
    try {
      final verificationCode = _generateVerificationCode();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Store verification code in database with timestamp (expires in 10 minutes)
      await _db
          .child('verification_codes')
          .child(email.replaceAll('.', '_').replaceAll('@', '_at_'))
          .set({
            'code': verificationCode,
            'timestamp': timestamp,
            'expiresAt': timestamp + (10 * 60 * 1000), // 10 minutes
            'verified': false,
          });

      // Send email via local proxy server
      await _sendEmailViaServer(email, verificationCode);

      // Record this attempt for rate limiting
      await _recordVerificationAttempt(email);
    } catch (e) {
      throw 'Failed to send verification code: ${e.toString()}';
    }
  }

  // Verify the code entered by user
  Future<bool> verifyCode(String email, String code) async {
    try {
      final snapshot = await _db
          .child('verification_codes')
          .child(email.replaceAll('.', '_').replaceAll('@', '_at_'))
          .get();

      if (!snapshot.exists) {
        throw 'Verification code not found. Please request a new code.';
      }

      final data = snapshot.value as Map;
      final storedCode = data['code'] as String;
      final expiresAt = data['expiresAt'] as int;
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      if (currentTime > expiresAt) {
        throw 'Verification code has expired. Please request a new code.';
      }

      if (storedCode != code) {
        throw 'Invalid verification code. Please try again.';
      }

      // Mark as verified
      await _db
          .child('verification_codes')
          .child(email.replaceAll('.', '_').replaceAll('@', '_at_'))
          .update({'verified': true});

      return true;
    } catch (e) {
      throw e.toString();
    }
  }

  // Check if email is already verified
  Future<bool> isEmailVerified(String email) async {
    try {
      final snapshot = await _db
          .child('verification_codes')
          .child(email.replaceAll('.', '_').replaceAll('@', '_at_'))
          .get();

      if (!snapshot.exists) return false;

      final data = snapshot.value as Map;
      return data['verified'] == true;
    } catch (e) {
      return false;
    }
  }

  // Send email via local proxy server (handles CORS)
  Future<void> _sendEmailViaServer(String recipientEmail, String code) async {
    try {
      final response = await http.post(
        Uri.parse(_emailServerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'to': recipientEmail,
          'code': code,
          'name': recipientEmail.split('@').first,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint('Verification email sent successfully to $recipientEmail');
        } else {
          debugPrint('Email server error: ${data['error']}');
          throw 'Failed to send email: ${data['error']}';
        }
      } else {
        debugPrint('Email server returned status ${response.statusCode}');
        throw 'Failed to send email. Status: ${response.statusCode}';
      }
    } catch (e) {
      debugPrint('Email sending error for $recipientEmail: $e');
      rethrow;
    }
  }

  // Resend verification code
  Future<void> resendVerificationCode(String email) async {
    await sendVerificationCode(email);
  }

  // Clean up expired codes (can be called periodically)
  Future<void> cleanupExpiredCodes() async {
    try {
      final snapshot = await _db.child('verification_codes').get();
      if (!snapshot.exists) return;

      final codes = snapshot.value as Map;
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      for (var entry in codes.entries) {
        final data = entry.value as Map;
        final expiresAt = data['expiresAt'] as int;

        if (currentTime > expiresAt) {
          await _db.child('verification_codes').child(entry.key).remove();
        }
      }
    } catch (e) {
      debugPrint('Cleanup error: $e');
    }
  }
}
