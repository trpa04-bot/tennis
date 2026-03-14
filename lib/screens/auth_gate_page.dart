import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_page.dart';

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  bool initialized = false;
  Object? initError;

  @override
  void initState() {
    super.initState();
    _initAnonymous();
  }

  Future<void> _initAnonymous() async {
    try {
      await AuthService.instance.ensureAnonymousViewer();
    } catch (e) {
      initError = e;
    } finally {
      if (mounted) {
        setState(() {
          initialized = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!initialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (initError != null) {
      return Scaffold(
        body: Center(
          child: Text('Auth init greška: $initError'),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return const HomePage();
      },
    );
  }
}