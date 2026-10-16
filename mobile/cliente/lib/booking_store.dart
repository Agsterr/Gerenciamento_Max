import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedBooking {
  const SavedBooking({required this.slug, required this.token, required this.salonName});

  factory SavedBooking.fromJson(Map<String, dynamic> j) =>
      SavedBooking(slug: j['slug'] as String, token: j['token'] as String, salonName: j['salonName'] as String);

  final String slug;
  final String token;
  final String salonName;

  Map<String, dynamic> toJson() => {'slug': slug, 'token': token, 'salonName': salonName};
}

/// Dados guardados só no aparelho: agendamentos feitos e (opcionalmente) nome/telefone.
/// Não há conta: o código do agendamento é a "chave" para consultar e cancelar.
class BookingStore extends ChangeNotifier {
  BookingStore._(this._prefs);

  static const _bookingsKey = 'bookings';
  static const _nameKey = 'customer.name';
  static const _phoneKey = 'customer.phone';

  final SharedPreferences _prefs;

  static Future<BookingStore> load() async => BookingStore._(await SharedPreferences.getInstance());

  List<SavedBooking> get bookings => (_prefs.getStringList(_bookingsKey) ?? [])
      .map((s) => SavedBooking.fromJson(jsonDecode(s) as Map<String, dynamic>))
      .toList();

  String? get name => _prefs.getString(_nameKey);
  String? get phone => _prefs.getString(_phoneKey);

  Future<void> add(SavedBooking booking) async {
    final list = [booking, ...bookings.where((b) => b.token != booking.token)];
    await _prefs.setStringList(_bookingsKey, list.map((b) => jsonEncode(b.toJson())).toList());
    notifyListeners();
  }

  Future<void> remove(String token) async {
    final list = bookings.where((b) => b.token != token);
    await _prefs.setStringList(_bookingsKey, list.map((b) => jsonEncode(b.toJson())).toList());
    notifyListeners();
  }

  Future<void> rememberCustomer(String name, String phone) async {
    await _prefs.setString(_nameKey, name);
    await _prefs.setString(_phoneKey, phone);
  }

  Future<void> forgetCustomer() async {
    await _prefs.remove(_nameKey);
    await _prefs.remove(_phoneKey);
  }

  /// "Apagar dados do aparelho".
  Future<void> clear() async {
    await _prefs.clear();
    notifyListeners();
  }
}
