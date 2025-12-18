import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  
  // SIGN UP
  Future<User?> signUp({
    required String name,
    required String role,
    required String email,
    required String password,
  }) async {
    try {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = cred.user;

      if (user != null) {
        await _db.child(role).child(user.uid).set({
          "name": name,
          "role": role,
          "email": email,
          "createdAt": ServerValue.timestamp,
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

      final snapshot = await _db.child(selectedRole).child(user.uid).child("role").get();

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

  // CURRENT USER
  User? get currentUser => _auth.currentUser;

  // AUTH STATE LISTENER
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
