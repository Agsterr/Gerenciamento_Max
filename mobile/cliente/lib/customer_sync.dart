import 'package:salao_core/salao_core.dart';

import 'booking_store.dart';

/// "Entrar" sem senha: busca os horários em todos os salões com o mesmo nome e WhatsApp
/// usados ao agendar (pelo app, pelo site ou em outro celular) e guarda no aparelho.
Future<int> syncCustomerBookings(ApiClient api, BookingStore store, {required String name, required String phone}) async {
  final json = await api.post('/api/public/my-bookings', {'name': name, 'phone': phone}) as List;
  final found = [
    for (final e in json.cast<Map<String, dynamic>>())
      (e['salonSlug'] as String, e['salonName'] as String, Booking.fromJson(e['booking'] as Map<String, dynamic>)),
  ];
  final known = {for (final b in store.bookings) b.token: b};
  await store.addAll([
    for (final (slug, salonName, b) in found)
      // mantém o "visto" de quem já estava salvo, para o aviso de alteração continuar funcionando
      SavedBooking(slug: slug, token: b.token, salonName: salonName, seen: known[b.token]?.seen ?? b.signature),
  ]);
  return found.length;
}
