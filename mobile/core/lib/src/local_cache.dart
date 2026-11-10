import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Cache simples no aparelho (JSON): a tela abre na hora com o que já foi baixado e atualiza quando a rede responde.
/// As chaves devem levar o salão (ex.: `shop:<slug>:catalog`) para um login não ver dados de outro.
class LocalCache {
  LocalCache._();

  static const _prefix = 'cache.';

  static Future<dynamic> read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      return raw == null ? null : jsonDecode(raw);
    } catch (_) {
      return null; // cache corrompido ou indisponível: segue sem ele
    }
  }

  static Future<void> write(String key, Object? value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$key', jsonEncode(value));
    } catch (_) {}
  }

  static Future<void> remove(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_prefix$key');
    } catch (_) {}
  }
}
