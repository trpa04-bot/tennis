import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/app_themes.dart';

class ThemeService {
  ThemeService._();

  static final ThemeService instance = ThemeService._();

  static const String _boxName = 'app_preferences';
  static const String _themeKey = 'selected_theme';
  static const String _configCollection = 'config';
  static const String _themeDoc = 'app_theme';
  static const String _themeField = 'selected';
  static const String _themeModeKey = 'theme_mode'; // 'light', 'dark', 'system'

  late Box _box;
  late ValueNotifier<AppTheme> _themeNotifier;
  late ValueNotifier<ThemeMode> _themeModeNotifier;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _themeSub;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) {
      return;
    }

    _box = await Hive.openBox<String>(_boxName);
    _themeNotifier = ValueNotifier<AppTheme>(_getCachedTheme());
    _themeModeNotifier = ValueNotifier<ThemeMode>(_getCachedThemeMode());

    _initialized = true;
  }

  ThemeMode _getCachedThemeMode() {
    final modeString = _box.get(_themeModeKey, defaultValue: 'light');

    switch (modeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _box.put(_themeModeKey, mode.name);
    _themeModeNotifier.value = mode;
  }

  ThemeMode getThemeMode() {
    return _themeModeNotifier.value;
  }

  ValueNotifier<ThemeMode> getThemeModeNotifier() {
    return _themeModeNotifier;
  }

  void startSync() {
    if (!_initialized || _themeSub != null) {
      return;
    }

    _themeSub = FirebaseFirestore.instance
        .collection(_configCollection)
        .doc(_themeDoc)
        .snapshots()
        .listen(
          (snapshot) async {
            if (!snapshot.exists) {
              return;
            }

            final data = snapshot.data();
            final remoteTheme = appThemeFromStoredValue(
              data?[_themeField]?.toString(),
            );

            await _saveToLocal(remoteTheme);

            if (_themeNotifier.value != remoteTheme) {
              _themeNotifier.value = remoteTheme;
            }
          },
          onError: (_) {
            _themeSub = null;
          },
        );
  }

  AppTheme _getCachedTheme() {
    final themeString = _box.get(
      _themeKey,
      defaultValue: AppTheme.svijetloplava.name,
    );
    return appThemeFromStoredValue(themeString?.toString());
  }

  Future<void> _saveToLocal(AppTheme theme) async {
    await _box.put(_themeKey, theme.name);
  }

  Future<void> setTheme(AppTheme theme) async {
    await _saveToLocal(theme);
    _themeNotifier.value = theme;
  }

  Future<void> setGlobalTheme(AppTheme theme) async {
    await FirebaseFirestore.instance
        .collection(_configCollection)
        .doc(_themeDoc)
        .set({
          _themeField: theme.name,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    await setTheme(theme);
  }

  AppTheme getTheme() {
    return _themeNotifier.value;
  }

  ValueNotifier<AppTheme> getThemeNotifier() {
    return _themeNotifier;
  }

  Future<void> resetToDefault() async {
    await setGlobalTheme(AppTheme.svijetloplava);
    await setThemeMode(ThemeMode.light);
  }

  Future<void> dispose() async {
    await _themeSub?.cancel();
    _themeSub = null;
  }
}
