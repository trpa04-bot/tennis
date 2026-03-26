import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();
  static const String _fallbackAdminEmail = 'trpa04@gmail.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cached from Firestore config/admins → emails[]
  List<String> _adminEmails = [];

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  bool get isLoggedIn => _auth.currentUser != null;

  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;

  bool get isAdmin {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return false;
    final email = (user.email ?? '').toLowerCase();
    return _adminEmails.contains(email) || email == _fallbackAdminEmail;
  }

  String get fallbackAdminEmail => _fallbackAdminEmail;

  /// Fetches the admin email list from Firestore (config/admins → emails[]).
  /// Must be called on startup and after sign-in for isAdmin to reflect correctly.
  /// SETUP: create a document at config/admins with field emails: [<your email>].
  Future<void> loadAdminConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('config')
          .doc('admins')
          .get();
      if (doc.exists) {
        final emails = doc.data()?['emails'];
        if (emails is List) {
          _adminEmails = {
            ...emails.map((e) => e.toString().toLowerCase()),
            _fallbackAdminEmail,
          }.toList();
        } else {
          _adminEmails = [_fallbackAdminEmail];
        }
      } else {
        _adminEmails = [_fallbackAdminEmail];
      }
    } catch (e) {
      _adminEmails = [_fallbackAdminEmail];
      debugPrint('AuthService: failed to load admin config: $e');
    }
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

    final creds = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await loadAdminConfig();
    return creds;
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
