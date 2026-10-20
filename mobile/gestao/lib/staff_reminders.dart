import 'package:salao_core/salao_core.dart';

/// Grupo das notificações de atendimento no aparelho.
const staffGroup = 'atendimento';

/// Agenda no celular os lembretes de atendimento dos próximos 7 dias (regras do usuário em
/// "Meus lembretes"). O mesmo aviso também chega no sino, pelo servidor, se a notificação falhar.
Future<void> syncStaffReminders(ApiClient api) async {
  final notifications = LocalReminders.instance;
  if (!notifications.ready) return;
  try {
    final json = await api.get('/api/me/reminders/upcoming?days=7') as List;
    final upcoming = json.map((e) => UpcomingReminder.fromJson(e as Map<String, dynamic>));
    await notifications.replace(staffGroup, [
      for (final u in upcoming)
        LocalReminder(key: u.key, at: u.remindAt, title: u.title, body: u.message, payload: '${u.appointmentId}'),
    ]);
  } catch (_) {
    // sem rede: mantém o que já estava agendado
  }
}
