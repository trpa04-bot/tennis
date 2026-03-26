import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import 'firebase_options.dart';
import 'services/theme_service.dart';
import 'services/web_reload.dart';
import 'screens/auth_gate_page.dart';
import 'utils/app_themes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await ThemeService.instance.init();

  runApp(const TennisClubApp());
}

class TennisClubApp extends StatefulWidget {
  const TennisClubApp({super.key});

  @override
  State<TennisClubApp> createState() => _TennisClubAppState();
}

class _TennisClubAppState extends State<TennisClubApp> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTheme>(
      valueListenable: ThemeService.instance.getThemeNotifier(),
      builder: (context, selectedTheme, _) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeService.instance.getThemeModeNotifier(),
          builder: (context, themeMode, _) {
            return MaterialApp(
              title: 'Teniska akademija',
              debugShowCheckedModeBanner: false,
              theme: selectedTheme.buildTheme(),
              darkTheme: selectedTheme.buildDarkTheme(),
              themeMode: themeMode,
              builder: (context, child) {
                if (child == null) {
                  return const SizedBox.shrink();
                }
                final mediaQuery = MediaQuery.of(context);
                final shortestSide = mediaQuery.size.shortestSide;

                final textScale = shortestSide < 600 ? 1.5 : 1.3;
                final iconSize = shortestSide < 600 ? 36.0 : 30.0;
                final toolbarHeight = shortestSide < 600 ? 84.0 : 72.0;
                final appTheme = Theme.of(context);

                return MediaQuery(
                  data: mediaQuery.copyWith(
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: Theme(
                    data: appTheme.copyWith(
                      iconTheme: IconThemeData(size: iconSize),
                      primaryIconTheme: IconThemeData(size: iconSize),
                      appBarTheme: appTheme.appBarTheme.copyWith(
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
          },
        );
      },
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
  bool _checking = false;

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
    if (_updateAvailable || _checking) {
      return;
    }

    _checking = true;

    try {
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
    } finally {
      _checking = false;
    }
  }

  Future<String?> _fetchVersion() async {
    try {
      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      final versionUri = Uri.base.resolve('version.json?v=$cacheBuster');
      final serviceWorkerUri = Uri.base.resolve(
        'flutter_service_worker.js?v=$cacheBuster',
      );

      final versionResponse = await http.get(
        versionUri,
        headers: const {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
      );
      final serviceWorkerResponse = await http.get(
        serviceWorkerUri,
        headers: const {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
      );

      if (versionResponse.statusCode != 200 ||
          serviceWorkerResponse.statusCode != 200) {
        return null;
      }

      final dynamic decoded = jsonDecode(versionResponse.body);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final version = decoded['version']?.toString() ?? '';
      final build = decoded['build_number']?.toString() ?? '';
      final workerSignature = serviceWorkerResponse.body.hashCode;
      return '$version+$build:$workerSignature';
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
