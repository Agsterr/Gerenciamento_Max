import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedBooking {
  const SavedBooking({required this.slug, required this.token, required this.salonName, this.seen});

  factory SavedBooking.fromJson(Map<String, dynamic> j) => SavedBooking(
        slug: j['slug'] as String,
        token: j['token'] as String,
        salonName: j['salonName'] as String,
        seen: j['seen'] as String?,
      );

  final String slug;
  final String token;
  final String salonName;

  /// Última versão do agendamento que o cliente viu ([Booking.signature]); diferente = o salão mudou algo.
  final String? seen;

  SavedBooking withSeen(String? value) => SavedBooking(slug: slug, token: token, salonName: salonName, seen: value);

  Map<String, dynamic> toJson() => {'slug': slug, 'token': token, 'salonName': salonName, 'seen': seen};
}

/// Salão que a cliente já abriu pelo link (ou onde já agendou), para voltar com um toque.
class SavedSalon {
  const SavedSalon({required this.slug, required this.name});

  final String slug;
  final String name;
}

/// Dados guardados só no aparelho: agendamentos feitos e (opcionalmente) nome/telefone.
/// Não há conta: o código do agendamento é a "chave" para consultar e cancelar.
class BookingStore extends ChangeNotifier {
  BookingStore._(this._prefs);

  static const _bookingsKey = 'bookings';
  static const _salonsKey = 'salons';
  static const _nameKey = 'customer.name';
  static const _phoneKey = 'customer.phone';
  static const _askedNotificationsKey = 'notifications.asked';

  final SharedPreferences _prefs;

  static Future<BookingStore> load() async => BookingStore._(await SharedPreferences.getInstance());

  List<SavedBooking> get bookings => (_prefs.getStringList(_bookingsKey) ?? [])
      .map((s) => SavedBooking.fromJson(jsonDecode(s) as Map<String, dynamic>))
      .toList();

  /// Salões usados neste aparelho, o mais recente primeiro: abertos pelo link + os dos agendamentos salvos.
  List<SavedSalon> get salons {
    final out = <String, SavedSalon>{};
    for (final s in _prefs.getStringList(_salonsKey) ?? const <String>[]) {
      final j = jsonDecode(s) as Map<String, dynamic>;
      out[j['slug'] as String] = SavedSalon(slug: j['slug'] as String, name: j['name'] as String);
    }
    for (final b in bookings) {
      out.putIfAbsent(b.slug, () => SavedSalon(slug: b.slug, name: b.salonName));
    }
    return out.values.toList();
  }

  /// Guarda o salão como usado (move para o topo). Chamado quando a página do salão abre.
  Future<void> rememberSalon(String slug, String name) async {
    final current = (_prefs.getStringList(_salonsKey) ?? const <String>[])
        .where((s) => (jsonDecode(s) as Map<String, dynamic>)['slug'] != slug);
    await _prefs.setStringList(_salonsKey, [jsonEncode({'slug': slug, 'name': name}), ...current].take(30).toList());
    notifyListeners();
  }

  String? get name => _prefs.getString(_nameKey);
  String? get phone => _prefs.getString(_phoneKey);

  Future<void> add(SavedBooking booking) => addAll([booking]);

  /// Guarda agendamentos (ex.: encontrados pela busca por nome e WhatsApp), sem duplicar.
  Future<void> addAll(List<SavedBooking> items) async {
    if (items.isEmpty) return;
    final tokens = items.map((b) => b.token).toSet();
    await _save([...items, ...bookings.where((b) => !tokens.contains(b.token))]);
    notifyListeners();
  }

  /// Cliente "entrou" com nome e WhatsApp: o app busca os horários dele em todos os salões.
  bool get signedIn => (name ?? '').isNotEmpty && (phone ?? '').isNotEmpty;

  /// Registra que o cliente viu esta versão do agendamento (não recarrega a lista).
  Future<void> markSeen(String token, String signature) =>
      _save([for (final b in bookings) b.token == token ? b.withSeen(signature) : b]);

  Future<void> _save(List<SavedBooking> list) =>
      _prefs.setStringList(_bookingsKey, list.map((b) => jsonEncode(b.toJson())).toList());

  Future<void> remove(String token) async {
    final list = bookings.where((b) => b.token != token);
    await _prefs.setStringList(_bookingsKey, list.map((b) => jsonEncode(b.toJson())).toList());
    notifyListeners();
  }

  /// Já pedimos permissão de notificação (para não insistir).
  bool get askedNotifications => _prefs.getBool(_askedNotificationsKey) ?? false;

  Future<void> markAskedNotifications() => _prefs.setBool(_askedNotificationsKey, true);

  Future<void> rememberCustomer(String name, String phone) async {
    await _prefs.setString(_nameKey, name);
    await _prefs.setString(_phoneKey, phone);
    notifyListeners();
  }

  Future<void> forgetCustomer() async {
    await _prefs.remove(_nameKey);
    await _prefs.remove(_phoneKey);
    notifyListeners();
  }

  /// "Apagar dados do aparelho".
  Future<void> clear() async {
    await _prefs.clear();
    notifyListeners();
  }
}
