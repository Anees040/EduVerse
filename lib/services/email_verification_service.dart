import 'dart:math';
import 'package:firebase_database/firebase_database.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailVerificationService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  
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
      await _db.child('verification_codes').child(email.replaceAll('.', '_')).set({
        'code': verificationCode,
        'timestamp': timestamp,
        'expiresAt': timestamp + (10 * 60 * 1000), // 10 minutes
        'verified': false,
      });

      // Send email with verification code
      await _sendEmail(email, verificationCode);
    } catch (e) {
      throw 'Failed to send verification code: ${e.toString()}';
    }
  }

  // Verify the code entered by user
  Future<bool> verifyCode(String email, String code) async {
    try {
      final snapshot = await _db
          .child('verification_codes')
          .child(email.replaceAll('.', '_'))
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
      await _db.child('verification_codes').child(email.replaceAll('.', '_')).update({
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
          .child(email.replaceAll('.', '_'))
          .get();

      if (!snapshot.exists) return false;

      final data = snapshot.value as Map;
      return data['verified'] == true;
    } catch (e) {
      return false;
    }
  }

  // Send email using SMTP
  Future<void> _sendEmail(String recipientEmail, String code) async {
    try {
      // Get SMTP credentials from .env file (with null safety)
      final smtpEmail = dotenv.maybeGet('SMTP_EMAIL');
      final smtpPassword = dotenv.maybeGet('SMTP_PASSWORD');
      final smtpHost = dotenv.maybeGet('SMTP_HOST') ?? 'smtp.gmail.com';
      final smtpPortStr = dotenv.maybeGet('SMTP_PORT') ?? '587';
      final smtpPort = int.tryParse(smtpPortStr) ?? 587;

      if (smtpEmail == null || smtpPassword == null || 
          smtpEmail.isEmpty || smtpPassword.isEmpty ||
          smtpEmail == 'your-email@gmail.com') {
        // Fallback: Just store the code without sending email
        // This allows development without SMTP setup
        print('══════════════════════════════════════');
        print('⚠️  SMTP NOT CONFIGURED');
        print('📧 Email: $recipientEmail');
        print('🔐 Verification Code: $code');
        print('⏰ Valid for 10 minutes');
        print('══════════════════════════════════════');
        return;
      }

      final smtpServer = SmtpServer(
        smtpHost,
        port: smtpPort,
        username: smtpEmail,
        password: smtpPassword,
        ignoreBadCertificate: false,
        ssl: false,
        allowInsecure: true,
      );

      final message = Message()
        ..from = Address(smtpEmail, 'eduVerse')
        ..recipients.add(recipientEmail)
        ..subject = 'eduVerse - Email Verification Code'
        ..html = '''
          <!DOCTYPE html>
          <html>
          <head>
            <style>
              body {
                font-family: Arial, sans-serif;
                line-height: 1.6;
                color: #333;
              }
              .container {
                max-width: 600px;
                margin: 0 auto;
                padding: 20px;
                background-color: #f9f9f9;
              }
              .header {
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                color: white;
                padding: 30px;
                text-align: center;
                border-radius: 10px 10px 0 0;
              }
              .content {
                background: white;
                padding: 30px;
                border-radius: 0 0 10px 10px;
              }
              .code-box {
                background: #f0f0f0;
                border: 2px dashed #667eea;
                border-radius: 8px;
                padding: 20px;
                text-align: center;
                margin: 20px 0;
              }
              .code {
                font-size: 32px;
                font-weight: bold;
                color: #667eea;
                letter-spacing: 5px;
              }
              .footer {
                text-align: center;
                margin-top: 20px;
                color: #999;
                font-size: 12px;
              }
              .warning {
                background: #fff3cd;
                border-left: 4px solid #ffc107;
                padding: 10px;
                margin: 15px 0;
              }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h1>📚 eduVerse</h1>
                <p>Email Verification</p>
              </div>
              <div class="content">
                <h2>Hello!</h2>
                <p>Thank you for registering with eduVerse. To complete your registration, please verify your email address using the code below:</p>
                
                <div class="code-box">
                  <p style="margin: 0; color: #666;">Your Verification Code</p>
                  <div class="code">$code</div>
                </div>
                
                <div class="warning">
                  <strong>⏰ Important:</strong> This code will expire in 10 minutes.
                </div>
                
                <p>If you didn't request this verification code, please ignore this email.</p>
                
                <p style="margin-top: 30px;">
                  Best regards,<br>
                  <strong>The eduVerse Team</strong>
                </p>
              </div>
              <div class="footer">
                <p>This is an automated email. Please do not reply to this message.</p>
              </div>
            </div>
          </body>
          </html>
        ''';

      await send(message, smtpServer);
    } catch (e) {
      // If email sending fails, still allow development to continue
      print('Failed to send email: ${e.toString()}');
      print('Verification code for $recipientEmail: $code');
      // Don't throw error - allow the code to be stored
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
      // Silent fail
      print('Cleanup error: $e');
    }
  }
}
