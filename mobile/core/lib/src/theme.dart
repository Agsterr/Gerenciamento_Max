import 'package:flutter/material.dart';

/// Paleta da marca Salão Max.
class Brand {
  Brand._();

  static const rose = Color(0xFFE5267A);
  static const pink = Color(0xFFFF6A9A);
  static const violet = Color(0xFF8E2DE2);
  static const night = Color(0xFF22104D);
  static const nightDeep = Color(0xFF140A2E);
  static const gold = Color(0xFFFFB547);
  static const ink = Color(0xFF1E1530);
  static const muted = Color(0xFF6E6585);
  static const canvas = Color(0xFFFFF7FA);
  static const line = Color(0xFFF1E3EB);
  static const success = Color(0xFF12A150);
  static const whatsapp = Color(0xFF1FA855);

  /// Gradiente principal (app do cliente, botões).
  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [pink, rose, violet],
    stops: [0, 0.5, 1],
  );

  /// Gradiente escuro (app do salão).
  static const nightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF3A1A7A), night, nightDeep],
  );

  static List<BoxShadow> softShadow([Color color = const Color(0xFF8E2DE2)]) => [
        BoxShadow(color: color.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8)),
        BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 1)),
      ];

  /// Cores dos avatares (estáveis por nome).
  static const avatarGradients = [
    [Color(0xFFFF8FB1), Color(0xFFE5267A)],
    [Color(0xFFB794F6), Color(0xFF7C3AED)],
    [Color(0xFFFFC371), Color(0xFFFF5F6D)],
    [Color(0xFF67E8F9), Color(0xFF6366F1)],
    [Color(0xFF86EFAC), Color(0xFF10B981)],
    [Color(0xFFFDA4AF), Color(0xFFBE185D)],
  ];
}

class AppTheme {
  AppTheme._();

  static const fontFamily = 'PlusJakartaSans';
  static const seed = Brand.rose;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: Brand.rose, primary: Brand.rose, secondary: Brand.violet).copyWith(
      surface: Colors.white,
      onSurface: Brand.ink,
      onSurfaceVariant: Brand.muted,
      outlineVariant: Brand.line,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFFFFBFD),
      surfaceContainer: const Color(0xFFFFF1F6),
      surfaceContainerHigh: const Color(0xFFFFE8F0),
      primaryContainer: const Color(0xFFFFE3EE),
      onPrimaryContainer: const Color(0xFF8A0F45),
    );
    return _build(scheme, Brand.canvas);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(seedColor: Brand.rose, brightness: Brightness.dark, primary: Brand.pink)
        .copyWith(surface: const Color(0xFF1B1430), secondary: const Color(0xFFC4A1FF));
    return _build(scheme, const Color(0xFF120C22));
  }

  static ThemeData _build(ColorScheme scheme, Color background) {
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'packages/salao_core/$fontFamily');
    final text = base.textTheme;
    final radius = BorderRadius.circular(16);
    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: text.copyWith(
        displaySmall: text.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
        headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8),
        headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.primary, width: 2)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: BorderSide(color: scheme.outlineVariant, width: 1.5),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outlineVariant),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(color: states.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Brand.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: Brand.rose,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    );
  }
}
