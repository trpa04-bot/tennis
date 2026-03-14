import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // OVDJE upiši svoj admin email
  static const String adminEmail = 'trpa04@gmail.com';

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  bool get isLoggedIn => _auth.currentUser != null;

  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  bool get isAdmin {
    final user = _auth.currentUser;
    if (user == null) return false;
    if (user.isAnonymous) return false;
    return (user.email ?? '').toLowerCase() == adminEmail.toLowerCase();
  }

  Future<void> ensureAnonymousViewer() async {
    if (_auth.currentUser == null) {
      await _auth.signInAnonymously();
    }
  }

  Future<UserCredential> signInAdmin({
    required String email,
    required String password,
  }) async {
    if (_auth.currentUser?.isAnonymous ?? false) {
      try {
        await _auth.currentUser!.delete();
      } catch (_) {
        await _auth.signOut();
      }
    }

    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> createAdminAccount({
    required String email,
    required String password,
  }) async {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOutToViewer() async {
    await _auth.signOut();
    await ensureAnonymousViewer();
  }
}