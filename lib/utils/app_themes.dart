import 'package:flutter/material.dart';

enum AppTheme {
  zelena,
  tamnoplava,
  svijetloplava,
  azurna,
  elektricna,
  zuta,
  smeda,
  crvena,
  narancasta,
  ljubicaste,
  teal,
  tamnosiva,
  pink,
  indigo,
  limeta,
  matchdark,
}

AppTheme appThemeFromStoredValue(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return AppTheme.zelena;
  }

  final normalized = raw.trim().toLowerCase();

  for (final theme in AppTheme.values) {
    if (theme.name.toLowerCase() == normalized) {
      return theme;
    }
    if (theme.toString().toLowerCase() == normalized) {
      return theme;
    }
  }

  return AppTheme.zelena;
}

extension AppThemeExtension on AppTheme {
  String get displayName {
    switch (this) {
      case AppTheme.zelena:
        return 'Zelena';
      case AppTheme.tamnoplava:
        return 'Tamno Plava';
      case AppTheme.svijetloplava:
        return 'Svjetlo Plava';
      case AppTheme.azurna:
        return 'Azurna Plava';
      case AppTheme.elektricna:
        return 'Električna Plava';
      case AppTheme.zuta:
        return 'Žuta';
      case AppTheme.smeda:
        return 'Smeđa';
      case AppTheme.crvena:
        return 'Crvena';
      case AppTheme.narancasta:
        return 'Narandžasta';
      case AppTheme.ljubicaste:
        return 'Ljubičasta';
      case AppTheme.teal:
        return 'Teal';
      case AppTheme.tamnosiva:
        return 'Tamno Siva';
      case AppTheme.pink:
        return 'Pink';
      case AppTheme.indigo:
        return 'Indigo';
      case AppTheme.limeta:
        return 'Limeta';
      case AppTheme.matchdark:
        return 'Match Dark';
    }
  }

  Color get seedColor {
    switch (this) {
      case AppTheme.zelena:
        return Colors.green;
      case AppTheme.tamnoplava:
        return const Color(0xFF1E3A5F);
      case AppTheme.svijetloplava:
        return const Color(0xFF5DADE2);
      case AppTheme.azurna:
        return const Color(0xFF2196F3);
      case AppTheme.elektricna:
        return const Color(0xFF0066FF);
      case AppTheme.zuta:
        return const Color(0xFFFBC02D);
      case AppTheme.smeda:
        return const Color(0xFFA1887F);
      case AppTheme.crvena:
        return const Color(0xFFF44336);
      case AppTheme.narancasta:
        return const Color(0xFFFF9800);
      case AppTheme.ljubicaste:
        return const Color(0xFF8E24AA);
      case AppTheme.teal:
        return const Color(0xFF009688);
      case AppTheme.tamnosiva:
        return const Color(0xFF23272F);
      case AppTheme.pink:
        return const Color(0xFFE91E63);
      case AppTheme.indigo:
        return const Color(0xFF3F51B5);
      case AppTheme.limeta:
        return const Color(0xFFCDDC39);
      case AppTheme.matchdark:
        return const Color(0xFF28D98A);
    }
  }

  ThemeData buildTheme() {
    if (this == AppTheme.matchdark) {
      return _buildMatchDarkTheme();
    }

    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF7F8FA),
      cardColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.black),
        bodyMedium: TextStyle(color: Colors.black87),
        titleLarge: TextStyle(color: Colors.black),
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: seedColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  ThemeData buildDarkTheme() {
    if (this == AppTheme.matchdark) {
      return _buildMatchDarkTheme();
    }

    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF101924),
      cardColor: const Color(0xFF172233),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF101924),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white70),
        titleLarge: TextStyle(color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: const Color(0xFF172233),
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: seedColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        color: const Color(0xFF172233),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  ThemeData _buildMatchDarkTheme() {
    const bg = Color(0xFF031A35);
    const surface = Color(0xFF18345F);
    const surfaceAlt = Color(0xFF0D274A);
    const border = Color(0xFF27466F);
    const accent = Color(0xFF28D98A);
    const textPrimary = Colors.white;
    const textSecondary = Color(0xFFB7C7DD);

    const colorScheme = ColorScheme.dark(
      primary: accent,
      secondary: accent,
      surface: surface,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: textPrimary,
      error: Color(0xFFFF6B6B),
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      cardColor: surface,
      dividerColor: border,
      splashColor: accent.withValues(alpha: 0.14),
      highlightColor: Colors.white.withValues(alpha: 0.04),
      appBarTheme: const AppBarTheme(
        backgroundColor: bg,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
        bodySmall: TextStyle(color: textSecondary),
      ),
      iconTheme: const IconThemeData(color: textPrimary),
      primaryIconTheme: const IconThemeData(color: textPrimary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        hintStyle: const TextStyle(color: textSecondary),
        labelStyle: const TextStyle(color: textSecondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          disabledBackgroundColor: const Color(0xFF38506E),
          disabledForegroundColor: Colors.white70,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: const BorderSide(color: Colors.white38),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceAlt,
        selectedColor: accent.withValues(alpha: 0.18),
        disabledColor: Colors.white10,
        side: const BorderSide(color: border),
        labelStyle: const TextStyle(color: textPrimary),
        secondaryLabelStyle: const TextStyle(color: Colors.black),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: textPrimary,
        iconColor: textPrimary,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: Colors.black,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return Colors.white70;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.35);
          }
          return Colors.white24;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: border),
      ),
    );
  }
}
