import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Um aviso que o app mostrou ao cliente (mudança no horário, promoção...). Fica só neste aparelho.
class AlertItem {
  const AlertItem({
    required this.id,
    required this.title,
    required this.body,
    required this.at,
    required this.kind,
    this.payload = '',
    this.read = false,
  });

  factory AlertItem.fromJson(Map<String, dynamic> j) => AlertItem(
        id: j['id'] as String,
        title: j['title'] as String,
        body: j['body'] as String? ?? '',
        at: DateTime.parse(j['at'] as String),
        kind: j['kind'] as String? ?? 'other',
        payload: j['payload'] as String? ?? '',
        read: j['read'] as bool? ?? false,
      );

  final String id;
  final String title;
  final String body;
  final DateTime at;

  /// booking (horário) ou promo (promoção).
  final String kind;

  /// Para onde o toque leva (mesmo formato dos avisos do sistema).
  final String payload;
  final bool read;

  AlertItem asRead() => AlertItem(id: id, title: title, body: body, at: at, kind: kind, payload: payload, read: true);

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'body': body, 'at': at.toIso8601String(), 'kind': kind, 'payload': payload, 'read': read};
}

/// Histórico dos avisos mostrados ao cliente. As notificações do sistema somem da bandeja; aqui o cliente reencontra,
/// filtra por situação e dia e apaga. Os lidos saem sozinhos depois de 30 dias e qualquer um depois de 90.
///
/// Lê e grava direto nas preferências (com `reload`), porque os avisos também chegam com o app fechado, em outro isolate.
class AlertLog {
  AlertLog._();

  static const _key = 'alerts.log';
  static const keepReadDays = 30;
  static const keepDays = 90;
  static const maxItems = 200;

  static Future<SharedPreferences> _prefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs;
  }

  /// Mais recentes primeiro.
  static Future<List<AlertItem>> all() async {
    final raw = (await _prefs()).getStringList(_key) ?? const <String>[];
    final items = <AlertItem>[];
    for (final s in raw) {
      try {
        items.add(AlertItem.fromJson(jsonDecode(s) as Map<String, dynamic>));
      } catch (_) {
        // registro estragado: ignora
      }
    }
    items.sort((a, b) => b.at.compareTo(a.at));
    return items;
  }

  static Future<void> _save(List<AlertItem> items) async {
    final prefs = await _prefs();
    await prefs.setStringList(_key, [for (final i in items.take(maxItems)) jsonEncode(i.toJson())]);
  }

  /// Registra um aviso. A mesma [key] não entra duas vezes (o servidor e a verificação local podem avisar a mesma coisa).
  static Future<void> add({
    required String key,
    required String title,
    required String body,
    required String kind,
    String payload = '',
    DateTime? now,
  }) async {
    final items = await all();
    if (items.any((i) => i.id == key)) return;
    items.insert(0, AlertItem(id: key, title: title, body: body, at: now ?? DateTime.now(), kind: kind, payload: payload));
    await _save(items);
  }

  static Future<int> unread() async => (await all()).where((i) => !i.read).length;

  static Future<void> markAllRead() async {
    final items = await all();
    if (items.every((i) => i.read)) return;
    await _save([for (final i in items) i.read ? i : i.asRead()]);
  }

  /// Só apaga o que já foi lido. Retorna se apagou.
  static Future<bool> delete(String id) async {
    final items = await all();
    final target = items.where((i) => i.id == id).firstOrNull;
    if (target == null || !target.read) return false;
    await _save(items.where((i) => i.id != id).toList());
    return true;
  }

  /// Apaga todos os lidos. Retorna quantos.
  static Future<int> clearRead() async {
    final items = await all();
    final keep = items.where((i) => !i.read).toList();
    if (keep.length == items.length) return 0;
    await _save(keep);
    return items.length - keep.length;
  }

  /// Limpeza automática: lidos há mais de [keepReadDays] dias e qualquer um com mais de [keepDays]. Retorna quantos saíram.
  static Future<int> prune({DateTime? now}) async {
    final t = now ?? DateTime.now();
    final items = await all();
    final keep = items.where((i) {
      final age = t.difference(i.at).inDays;
      return !(age > keepDays || (i.read && age > keepReadDays));
    }).toList();
    if (keep.length == items.length) return 0;
    await _save(keep);
    return items.length - keep.length;
  }
}
