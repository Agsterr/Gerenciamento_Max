import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Um tema de cor do app (a pessoa escolhe em Ajustes). Troca a cor de tudo, inclusive o ícone no Android.
class BrandPalette {
  const BrandPalette({
    required this.id,
    required this.name,
    required this.pink,
    required this.rose,
    required this.violet,
    required this.night,
    required this.nightDeep,
    required this.nightTop,
    required this.canvas,
    required this.line,
    required this.tint,
    required this.tintHigh,
    required this.container,
    required this.onContainer,
  });

  final String id;
  final String name;

  /// Cor clara de destaque (início do gradiente; cor principal no tema escuro).
  final Color pink;

  /// Cor principal (botões, abas, links).
  final Color rose;

  /// Cor secundária (fim do gradiente).
  final Color violet;

  /// Fundos escuros do app do salão.
  final Color night;
  final Color nightDeep;
  final Color nightTop;

  /// Fundo e contornos do tema claro.
  final Color canvas;
  final Color line;
  final Color tint;
  final Color tintHigh;
  final Color container;
  final Color onContainer;

  static const all = [rosa, azul, verde, grafite, laranja, roxo];

  static const rosa = BrandPalette(
    id: 'rosa', name: 'Rosa',
    pink: Color(0xFFFF6A9A), rose: Color(0xFFE5267A), violet: Color(0xFF8E2DE2),
    night: Color(0xFF22104D), nightDeep: Color(0xFF140A2E), nightTop: Color(0xFF3A1A7A),
    canvas: Color(0xFFFFF7FA), line: Color(0xFFF1E3EB), tint: Color(0xFFFFF1F6), tintHigh: Color(0xFFFFE8F0),
    container: Color(0xFFFFE3EE), onContainer: Color(0xFF8A0F45),
  );
  static const azul = BrandPalette(
    id: 'azul', name: 'Azul',
    pink: Color(0xFF5BB8FF), rose: Color(0xFF1E6FE8), violet: Color(0xFF5B3FD6),
    night: Color(0xFF0F2A5C), nightDeep: Color(0xFF081A3D), nightTop: Color(0xFF1A4A9A),
    canvas: Color(0xFFF5F9FF), line: Color(0xFFDDE8F5), tint: Color(0xFFEEF4FF), tintHigh: Color(0xFFE1ECFF),
    container: Color(0xFFDCE9FF), onContainer: Color(0xFF0B3A86),
  );
  static const verde = BrandPalette(
    id: 'verde', name: 'Verde',
    pink: Color(0xFF4ADE9C), rose: Color(0xFF0E9F6E), violet: Color(0xFF0B7A8F),
    night: Color(0xFF0B3B2E), nightDeep: Color(0xFF062319), nightTop: Color(0xFF14614A),
    canvas: Color(0xFFF4FBF7), line: Color(0xFFDCEEE4), tint: Color(0xFFEAF7F0), tintHigh: Color(0xFFDDF1E7),
    container: Color(0xFFD3F2E3), onContainer: Color(0xFF065F46),
  );
  static const grafite = BrandPalette(
    id: 'grafite', name: 'Grafite',
    pink: Color(0xFFA7B1C2), rose: Color(0xFF374151), violet: Color(0xFF1F2937),
    night: Color(0xFF1F2937), nightDeep: Color(0xFF111827), nightTop: Color(0xFF374151),
    canvas: Color(0xFFF7F7F8), line: Color(0xFFE5E7EB), tint: Color(0xFFF1F2F4), tintHigh: Color(0xFFE6E8EB),
    container: Color(0xFFE2E5EA), onContainer: Color(0xFF1F2937),
  );
  static const laranja = BrandPalette(
    id: 'laranja', name: 'Laranja',
    pink: Color(0xFFFFB067), rose: Color(0xFFEA580C), violet: Color(0xFFB91C1C),
    night: Color(0xFF4A1D0A), nightDeep: Color(0xFF2A0F04), nightTop: Color(0xFF7A3511),
    canvas: Color(0xFFFFF9F4), line: Color(0xFFF3E4D8), tint: Color(0xFFFFF1E6), tintHigh: Color(0xFFFFE6D3),
    container: Color(0xFFFFE3CC), onContainer: Color(0xFF8A2E05),
  );
  static const roxo = BrandPalette(
    id: 'roxo', name: 'Roxo',
    pink: Color(0xFFB794F6), rose: Color(0xFF7C3AED), violet: Color(0xFF4F46E5),
    night: Color(0xFF2A1066), nightDeep: Color(0xFF170A3D), nightTop: Color(0xFF4C1D95),
    canvas: Color(0xFFFAF7FF), line: Color(0xFFE9E0F7), tint: Color(0xFFF3EEFF), tintHigh: Color(0xFFEBE2FF),
    container: Color(0xFFE9DDFF), onContainer: Color(0xFF4C1D95),
  );

  static BrandPalette byId(String? id) => all.firstWhere((p) => p.id == id, orElse: () => rosa);
}

/// Tema de cor escolhido: guarda no aparelho e avisa o app para repintar tudo.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final instance = ThemeController._();

  static const _key = 'brand_palette';

  BrandPalette get palette => Brand.palette;

  /// Lê a escolha salva (chamar antes de `runApp`).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Brand.palette = BrandPalette.byId(prefs.getString(_key));
      _syncIcon(Brand.palette);
    } catch (_) {
      // sem armazenamento: fica o tema padrão
    }
  }

  static const _icon = MethodChannel('salaomax/app_icon');

  /// Troca o ícone do app no Android (cada tema tem o seu). Em outros sistemas, não faz nada.
  Future<void> _syncIcon(BrandPalette p) async {
    try {
      await _icon.invokeMethod('set', p.id);
    } catch (_) {
      // sem suporte (iOS, testes, Android antigo): só o app muda de cor
    }
  }

  Future<void> select(BrandPalette p) async {
    if (p.id == Brand.palette.id) return;
    Brand.palette = p;
    notifyListeners();
    _syncIcon(p);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, p.id);
    } catch (_) {}
  }
}

/// Paleta da marca Salão Max (acompanha o tema de cor escolhido).
class Brand {
  Brand._();

  static BrandPalette palette = BrandPalette.rosa;

  static Color get rose => palette.rose;
  static Color get pink => palette.pink;
  static Color get violet => palette.violet;
  static Color get night => palette.night;
  static Color get nightDeep => palette.nightDeep;
  static Color get canvas => palette.canvas;
  static Color get line => palette.line;

  static const gold = Color(0xFFFFB547);
  static const ink = Color(0xFF1E1530);
  static const muted = Color(0xFF6E6585);
  static const success = Color(0xFF12A150);
  static const whatsapp = Color(0xFF1FA855);

  /// Gradiente principal (app do cliente, botões).
  static LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [pink, rose, violet],
        stops: const [0, 0.5, 1],
      );

  /// Gradiente escuro (app do salão).
  static LinearGradient get nightGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [palette.nightTop, night, nightDeep],
      );

  static List<BoxShadow> softShadow([Color? color]) => [
        BoxShadow(color: (color ?? violet).withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8)),
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
  static Color get seed => Brand.rose;

  static ThemeData light() {
    final p = Brand.palette;
    final scheme = ColorScheme.fromSeed(seedColor: p.rose, primary: p.rose, secondary: p.violet).copyWith(
      surface: Colors.white,
      onSurface: Brand.ink,
      onSurfaceVariant: Brand.muted,
      outlineVariant: Brand.line,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color.alphaBlend(Colors.white.withValues(alpha: 0.6), p.tint),
      surfaceContainer: p.tint,
      surfaceContainerHigh: p.tintHigh,
      primaryContainer: p.container,
      onPrimaryContainer: p.onContainer,
    );
    return _build(scheme, p.canvas);
  }

  static ThemeData dark() {
    final p = Brand.palette;
    final scheme = ColorScheme.fromSeed(seedColor: p.rose, brightness: Brightness.dark, primary: p.pink)
        .copyWith(surface: _darkTone(p, 0.10), secondary: Color.lerp(p.violet, Colors.white, 0.55));
    return _build(scheme, _darkTone(p, 0.06));
  }

  /// Fundo escuro com um toque da cor do tema (`level` = quanto da cor entra).
  static Color _darkTone(BrandPalette p, double level) =>
      Color.alphaBlend(p.rose.withValues(alpha: level), const Color(0xFF0E0B16));

  /// Estilo de texto dos componentes (botões, chips, abas) com a fonte da marca. Sem isso, onde o Material troca o estilo
  /// em vez de mesclar (botões, chips, barra de navegação), o texto cai na fonte padrão do sistema.
  static TextStyle _brand(TextTheme text, {double? fontSize, FontWeight? fontWeight, Color? color}) =>
      (text.labelLarge ?? const TextStyle()).copyWith(fontSize: fontSize, fontWeight: fontWeight, color: color);

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
          textStyle: _brand(text, fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: BorderSide(color: scheme.outlineVariant, width: 1.5),
          textStyle: _brand(text, fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: _brand(text, fontWeight: FontWeight.w700)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outlineVariant),
        // cor explícita: sem ela o texto das etiquetas (ex.: categorias) ficava invisível em alguns celulares
        labelStyle: _brand(text, fontWeight: FontWeight.w600, color: scheme.onSurface),
        backgroundColor: scheme.surface,
        selectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.primary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => _brand(
            text,
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
        // cor explícita: no tema escuro o padrão era texto escuro sobre fundo escuro (avisos "apagados")
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
        actionTextColor: Brand.pink,
        closeIconColor: Colors.white,
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

/// Envolve o app: quando a pessoa troca o tema de cor, reconstrói o `MaterialApp` e todas as telas abertas
/// (inclusive as que usam `Brand.rose` direto), sem sair da tela em que ela está.
class ThemedApp extends StatefulWidget {
  const ThemedApp({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  State<ThemedApp> createState() => _ThemedAppState();
}

class _ThemedAppState extends State<ThemedApp> {
  @override
  void initState() {
    super.initState();
    ThemeController.instance.addListener(_changed);
  }

  @override
  void dispose() {
    ThemeController.instance.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      void rebuild(Element e) {
        e.markNeedsBuild();
        e.visitChildren(rebuild);
      }

      (context as Element).visitChildren(rebuild);
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
