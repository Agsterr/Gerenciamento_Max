import 'package:salao_core/salao_core.dart';

import 'booking_store.dart';

/// Grupo das notificações "confirme seu horário" no aparelho.
const confirmGroup = 'confirmar';

/// Hora do dia em que o lembrete aparece (no horário do salão).
const confirmReminderHour = 10;

/// Lembretes locais para o cliente confirmar presença, 1 e/ou 2 dias antes, conforme o ajuste do
/// salão ([Booking.reminderDays]). Só para horários ainda sem confirmação e com o aviso no futuro.
List<LocalReminder> confirmReminders(List<(SavedBooking, Booking)> items, {DateTime? now}) {
  final current = now ?? DateTime.now();
  return [
    for (final (saved, b) in items)
      if (b.confirmable)
        for (final days in b.reminderDays)
          if (DateTime(b.startAt.year, b.startAt.month, b.startAt.day - days, confirmReminderHour) case final at
              when at.isAfter(current) && at.isBefore(b.startAt.subtract(const Duration(hours: 2))))
            LocalReminder(
              key: 'confirmar:${b.token}:$days',
              at: at,
              title: days == 1 ? 'Seu horário é amanhã' : 'Seu horário é depois de amanhã',
              body: '${b.serviceName} às ${formatTime(b.startAt)} · ${saved.salonName}. Toque para confirmar presença.',
              payload: '${saved.slug}/${b.token}',
            ),
  ];
}
