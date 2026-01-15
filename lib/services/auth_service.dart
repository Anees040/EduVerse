import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Sign up failed';
    } catch (e) {
      throw e.toString();
    }
  }

  // LOGIN
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

  // PASSWORD RESET
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw e.message ?? 'Failed to send reset email';
    } catch (e) {
      throw e.toString();
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
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
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
      final UserCredential userCredential = await _auth.signInWithProvider(githubProvider);
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
