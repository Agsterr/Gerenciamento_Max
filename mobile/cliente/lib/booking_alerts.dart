import 'package:salao_core/salao_core.dart';

import 'booking_store.dart';
import 'confirm_reminders.dart';

/// Em segundo plano: avisa quando o salão confirma, cancela ou muda um horário que o cliente marcou.
/// Compara com a última situação já avisada; a primeira leitura só guarda a referência (sem avisar).
Future<void> checkBookingChanges(ApiClient api, BookingStore store) async {
  final notified = {...store.notifiedSignatures};
  var changed = false;
  for (final saved in store.bookings) {
    final Booking b;
    try {
      b = Booking.fromJson(await api.get('/api/public/salons/${saved.slug}/bookings/${saved.token}') as Map<String, dynamic>);
    } catch (_) {
      continue; // sem rede ou salão fora do ar: tenta na próxima rodada
    }
    final before = notified[saved.token];
    if (before == b.signature) continue;
    notified[saved.token] = b.signature;
    changed = true;
    if (before == null) continue; // primeira vez que vemos este horário
    final what = b.status == AppointmentStatus.canceled
        ? 'O salão cancelou o seu horário'
        : b.status.isOpen && b.salonConfirmed && !before.endsWith('|true')
            ? 'O salão confirmou o seu horário'
            : 'O salão alterou o seu horário';
    await LocalReminders.instance.showNow(
      key: 'booking:${saved.token}:${b.signature}',
      title: '$what - ${saved.salonName}',
      body: '${b.serviceName} · ${formatShortDateTime(b.startAt)} com ${b.professionalName}',
      payload: '$confirmGroup|${saved.slug}/${saved.token}',
      channelId: 'horarios',
      channelName: 'Meus horários',
      channelDescription: 'Quando o salão confirma, cancela ou muda um horário seu',
    );
  }
  if (changed) await store.setNotifiedSignatures(notified);
}
