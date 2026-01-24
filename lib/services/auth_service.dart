import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // Lazy-loaded GoogleSignIn instance - only created when needed
  GoogleSignIn? _googleSignIn;
  GoogleSignIn get googleSignIn => _googleSignIn ??= GoogleSignIn();

  // SIGN UP
  Future<User?> signUp({
    required String name,
    required String role,
    required String email,
    required String password,
    // Teacher-specific optional parameters
    String? yearsOfExperience,
    String? subjectExpertise,
  }) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = cred.user;

      if (user != null) {
        final userData = <String, dynamic>{
          "name": name,
          "role": role,
          "email": email,
          "createdAt": ServerValue.timestamp,
        };

        // Add teacher-specific fields if role is teacher
        if (role == "teacher" && yearsOfExperience != null) {
          userData["yearsOfExperience"] = yearsOfExperience;
        }
        if (role == "teacher" && subjectExpertise != null) {
          userData["subjectExpertise"] = subjectExpertise;
        }

        await _db.child(role).child(user.uid).set(userData);

        // Register email in public lookup table for password reset feature
        final emailKey = email
            .toLowerCase()
            .trim()
            .replaceAll('.', '_')
            .replaceAll('@', '_at_');
        await _db.child('registered_emails').child(emailKey).set({
          'email': email.toLowerCase().trim(),
          'role': role,
          'registeredAt': ServerValue.timestamp,
        });
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Sign up failed';
    } catch (e) {
      throw e.toString();
    }
  }

  // LOGIN
  // Modified to support admin login - admin can login without selecting role
  Future<User?> signIn({
    required String email,
    required String password,
    required String selectedRole,
  }) async {
    try {
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) {
        throw 'Login failed';
      }

      // First check if user is an admin (admins can login with any role selected)
      final adminSnapshot = await _db
          .child('admin')
          .child(user.uid)
          .child('role')
          .get();

      if (adminSnapshot.exists && adminSnapshot.value == 'admin') {
        // Admin user - allow login regardless of selected role
        return user;
      }

      // For non-admin users, verify they have the selected role
      final snapshot = await _db
          .child(selectedRole)
          .child(user.uid)
          .child("role")
          .get();

      if (!snapshot.exists) {
        await _auth.signOut();
        throw 'No user exists with this role';
      }

      final dbRole = snapshot.value as String;

      if (dbRole != selectedRole) {
        await _auth.signOut();
        throw 'Invalid role selected';
      }

      // Check if teacher is pending verification (only for teachers)
      if (selectedRole == 'teacher') {
        final statusSnapshot = await _db
            .child('teacher')
            .child(user.uid)
            .child('status')
            .get();

        if (statusSnapshot.exists) {
          final status = statusSnapshot.value?.toString();
          if (status == 'pending') {
            await _auth.signOut();
            throw 'Your teacher application is still pending admin approval. Please wait for verification.';
          } else if (status == 'rejected') {
            // Get rejection reason if available
            final rejectionReasonSnapshot = await _db
                .child('teacher')
                .child(user.uid)
                .child('rejectionReason')
                .get();
            final rejectionReason =
                rejectionReasonSnapshot.exists &&
                    rejectionReasonSnapshot.value != null
                ? rejectionReasonSnapshot.value.toString()
                : 'Contact support for more information';
            await _auth.signOut();
            throw 'Your teacher application was rejected. Reason: $rejectionReason';
          }
        }
      }

      // Check if user is suspended
      final suspendedSnapshot = await _db
          .child(selectedRole)
          .child(user.uid)
          .child('isSuspended')
          .get();

      if (suspendedSnapshot.exists && suspendedSnapshot.value == true) {
        // Get suspension reason if available
        final reasonSnapshot = await _db
            .child(selectedRole)
            .child(user.uid)
            .child('suspensionReason')
            .get();
        final reason = reasonSnapshot.exists && reasonSnapshot.value != null
            ? reasonSnapshot.value.toString()
            : 'Contact support for more information';
        await _auth.signOut();
        throw 'Your account has been suspended. Reason: $reason';
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Login failed';
    } catch (e) {
      throw e.toString();
    }
  }

  // LOGOUT
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // PASSWORD RESET - Send Firebase reset link (for reference, but not used in custom flow)
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Failed to send reset email';
    } catch (e) {
      throw e.toString();
    }
  }

  // Cloud Function URL for password reset
  // Using local email server since Firebase Cloud Functions require Blaze plan
  // For production, deploy to Cloud Functions and update this URL
  static const String _resetPasswordUrl =
      'http://localhost:3001/reset-password';

  // CHECK PASSWORD RESET RATE LIMIT
  // Returns null if within limit, or error message if exceeded
  Future<String?> checkPasswordResetRateLimit(String email) async {
    final normalizedEmail = email.toLowerCase().trim();
    final emailKey = normalizedEmail
        .replaceAll('.', '_')
        .replaceAll('@', '_at_');

    try {
      final snapshot = await _db
          .child('password_reset_attempts')
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
        return 'You have reached the maximum of 2 password resets per week. Please try again in $daysLeft day(s).';
      }

      return null; // Within limit
    } catch (e) {
      debugPrint('Error checking rate limit: $e');
      return null; // If we can't check, allow the attempt
    }
  }

  // RESET PASSWORD VIA CLOUD FUNCTION - Actually updates password in Firebase
  // This method calls a Cloud Function that uses Firebase Admin SDK to update the password
  Future<void> resetPasswordViaCloudFunction({
    required String email,
    required String newPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(_resetPasswordUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email.toLowerCase().trim(),
              'newPassword': newPassword,
            }),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw 'Request timed out. Please try again.',
          );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Password updated successfully
        return;
      } else {
        // Extract error message from response
        final errorMessage = data['error'] ?? 'Failed to reset password';
        throw errorMessage;
      }
    } catch (e) {
      if (e is String) rethrow;
      throw 'Failed to reset password. Please try again.';
    }
  }

  // CHECK IF EMAIL EXISTS IN DATABASE
  // Uses public registered_emails lookup table (doesn't require authentication)
  Future<bool> checkEmailExists(String email) async {
    try {
      final normalizedEmail = email.toLowerCase().trim();
      final emailKey = normalizedEmail
          .replaceAll('.', '_')
          .replaceAll('@', '_at_');

      // Check in registered_emails collection (public read access)
      final snapshot = await _db
          .child('registered_emails')
          .child(emailKey)
          .get();

      if (snapshot.exists && snapshot.value != null) {
        return true;
      }

      return false; // Email not found
    } catch (e) {
      debugPrint('Error checking email exists: $e');
      throw 'Unable to verify email. Please try again.';
    }
  }

  // CURRENT USER
  User? get currentUser => _auth.currentUser;

  // AUTH STATE LISTENER
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // GOOGLE SIGN IN
  Future<User?> signInWithGoogle({required String role}) async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final user = userCredential.user;

      if (user == null) {
        throw 'Sign in failed';
      }

      // Check if user already exists in database
      final snapshot = await _db.child(role).child(user.uid).get();

      if (!snapshot.exists) {
        // New user - create profile
        await _db.child(role).child(user.uid).set({
          "name": user.displayName ?? "User",
          "role": role,
          "email": user.email,
          "emailVerified": user.emailVerified,
          "photoUrl": user.photoURL,
          "provider": "google",
          "createdAt": ServerValue.timestamp,
        });
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Google sign in failed';
    } catch (e) {
      throw e.toString();
    }
  }

  // GITHUB SIGN IN
  Future<User?> signInWithGitHub({required String role}) async {
    try {
      // Create a GitHub OAuth provider
      final githubProvider = GithubAuthProvider();

      // Sign in with GitHub
      final UserCredential userCredential = await _auth.signInWithProvider(
        githubProvider,
      );
      final user = userCredential.user;

      if (user == null) {
        throw 'Sign in failed';
      }

      // Check if user already exists in database
      final snapshot = await _db.child(role).child(user.uid).get();

      if (!snapshot.exists) {
        // New user - create profile
        await _db.child(role).child(user.uid).set({
          "name": user.displayName ?? user.email?.split('@')[0] ?? "User",
          "role": role,
          "email": user.email,
          "emailVerified": user.emailVerified,
          "photoUrl": user.photoURL,
          "provider": "github",
          "createdAt": ServerValue.timestamp,
        });
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'GitHub sign in failed';
    } catch (e) {
      throw e.toString();
    }
  }
}
