import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const seed = Color(0xFFE11D48);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
    );
  }
}
