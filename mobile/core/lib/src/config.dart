import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;

/// Configuração por ambiente, via `--dart-define`.
///
/// Ex.: `flutter run --dart-define=API_URL=http://10.0.2.2:8080` (emulador Android)
/// e `flutter build appbundle --flavor play --dart-define=API_URL=https://api.seudominio.com.br`.
class AppConfig {
  AppConfig._();

  /// URL da API Spring Boot. Em produção deve ser HTTPS (exigência do iOS/ATS e do Android).
  static const apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://localhost:8080');

  /// Site Next.js (política de privacidade, termos e exclusão de conta).
  static const siteUrl = String.fromEnvironment('SITE_URL', defaultValue: 'http://localhost:3000');

  static const supportEmail = String.fromEnvironment('SUPPORT_EMAIL', defaultValue: 'privacidade@exemplo.com.br');

  static const _distributionDefine = String.fromEnvironment('DISTRIBUTION');

  /// Canal de distribuição: `play` (Google Play / App Store) ou `direct` (APK baixado do site).
  /// Vem de `--dart-define=DISTRIBUTION`; sem ele, usa o `--flavor` do build; padrão `play`.
  static String get distribution =>
      _distributionDefine.isNotEmpty ? _distributionDefine : (appFlavor ?? 'play');

  /// Atualização pelo próprio app (download do APK) — só Android no canal `direct`.
  static bool get selfUpdateEnabled =>
      distribution == 'direct' && !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Uri get privacyUrl => Uri.parse('$siteUrl/privacidade');
  static Uri get termsUrl => Uri.parse('$siteUrl/termos');
  static Uri get deleteAccountUrl => Uri.parse('$siteUrl/excluir-conta');
}
