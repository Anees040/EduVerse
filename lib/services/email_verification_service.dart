import 'dart:math';
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;

class EmailVerificationService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  
  // Local email server URL (handles CORS and proxies to Mailjet)
  static const String _emailServerUrl = 'http://localhost:3001/send-verification';
  
  // Generate 6-digit verification code
  String _generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  // Send verification code to email
  Future<void> sendVerificationCode(String email) async {
    try {
      final verificationCode = _generateVerificationCode();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Store verification code in database with timestamp (expires in 10 minutes)
      await _db.child('verification_codes').child(email.replaceAll('.', '_').replaceAll('@', '_at_')).set({
        'code': verificationCode,
        'timestamp': timestamp,
        'expiresAt': timestamp + (10 * 60 * 1000), // 10 minutes
        'verified': false,
      });

      // Send email via local proxy server
      await _sendEmailViaServer(email, verificationCode);
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
      await _db.child('verification_codes').child(email.replaceAll('.', '_').replaceAll('@', '_at_')).update({
        'verified': true,
      });

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
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'to': recipientEmail,
          'code': code,
          'name': recipientEmail.split('@').first,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('✅ Verification email sent successfully to $recipientEmail');
        } else {
          print('⚠️ Email server error: ${data['error']}');
          throw 'Failed to send email: ${data['error']}';
        }
      } else {
        print('❌ Email server returned status ${response.statusCode}');
        throw 'Failed to send email. Status: ${response.statusCode}';
      }
    } catch (e) {
      print('══════════════════════════════════════');
      print('⚠️ Email sending error');
      print('📧 Email: $recipientEmail');
      print('🔐 Verification Code: $code');
      print('Error: $e');
      print('══════════════════════════════════════');
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
      print('Cleanup error: $e');
    }
  }
}
