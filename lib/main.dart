import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'firebase_options.dart';
import 'services/web_reload.dart';
import 'screens/auth_gate_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const TennisClubApp());
}

class TennisClubApp extends StatelessWidget {
  const TennisClubApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.green,
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'Tennis Club',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      ),
      builder: (context, child) {
        if (child == null) {
          return const SizedBox.shrink();
        }
        final mediaQuery = MediaQuery.of(context);
        final shortestSide = mediaQuery.size.shortestSide;

        final textScale = shortestSide < 600 ? 1.5 : 1.3;
        final iconSize = shortestSide < 600 ? 36.0 : 30.0;
        final toolbarHeight = shortestSide < 600 ? 84.0 : 72.0;
        final theme = Theme.of(context);

        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: Theme(
            data: theme.copyWith(
              iconTheme: IconThemeData(size: iconSize),
              primaryIconTheme: IconThemeData(size: iconSize),
              appBarTheme: theme.appBarTheme.copyWith(
                iconTheme: IconThemeData(size: iconSize),
                actionsIconTheme: IconThemeData(size: iconSize),
                toolbarHeight: toolbarHeight,
              ),
            ),
            child: AppVersionWatcher(child: child),
          ),
        );
      },
      home: const AuthGatePage(),
    );
  }
}

class AppVersionWatcher extends StatefulWidget {
  const AppVersionWatcher({required this.child, super.key});

  final Widget child;

  @override
  State<AppVersionWatcher> createState() => _AppVersionWatcherState();
}

class _AppVersionWatcherState extends State<AppVersionWatcher> {
  Timer? _timer;
  String? _initialVersion;
  bool _updateAvailable = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initVersionWatcher();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initVersionWatcher() async {
    _initialVersion = await _fetchVersion();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkForUpdate(),
    );
  }

  Future<void> _checkForUpdate() async {
    if (_updateAvailable) {
      return;
    }

    final latestVersion = await _fetchVersion();
    if (!mounted || latestVersion == null || _initialVersion == null) {
      return;
    }

    if (latestVersion != _initialVersion) {
      setState(() {
        _updateAvailable = true;
      });
      _timer?.cancel();
    }
  }

  Future<String?> _fetchVersion() async {
    try {
      final uri = Uri.base.resolve(
        'version.json?v=${DateTime.now().millisecondsSinceEpoch}',
      );
      final response = await http.get(
        uri,
        headers: const {
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      );

      if (response.statusCode != 200) {
        return null;
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final version = decoded['version']?.toString() ?? '';
      final build = decoded['build_number']?.toString() ?? '';
      return '$version+$build';
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || !_updateAvailable) {
      return widget.child;
    }

    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(12),
            color: scheme.inverseSurface,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Nova verzija je dostupna.',
                      style: TextStyle(color: scheme.onInverseSurface),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await reloadPage();
                    },
                    child: const Text('Osvježi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}