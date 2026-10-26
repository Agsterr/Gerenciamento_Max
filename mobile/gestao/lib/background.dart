import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_core/salao_core.dart';
import 'package:workmanager/workmanager.dart';

import 'push.dart';
import 'session.dart';

const _task = 'avisos-do-salao';
const _lastKey = 'staff.lastNotifiedId';
const _storage = FlutterSecureStorage();

/// Avisos que viram notificação no celular (os lembretes de atendimento já são agendados à parte).
const _types = {'BOOKED', 'CANCELED', 'RESCHEDULED', 'CONFIRMED'};

/// Marca como já avisada a notificação do sino (o app aberto já mostrou), para o segundo plano não repetir.
Future<void> markNotified(int id) async {
  final last = int.tryParse(await _storage.read(key: _lastKey) ?? '') ?? 0;
  if (id > last) await _storage.write(key: _lastKey, value: '$id');
}

/// Confere o sino do salão e mostra notificação para o que for novo: agendamento online, cancelamento,
/// remarcação e confirmação de presença do cliente. A primeira rodada só guarda a referência.
Future<int> notifyNewStaffAlerts(ApiClient api, {bool viaPush = false}) async {
  final inbox = Inbox.fromJson(await api.get('/api/notifications') as Map<String, dynamic>);
  final newest = inbox.items.fold(0, (m, n) => n.id > m ? n.id : m);
  final raw = await _storage.read(key: _lastKey);
  if (raw == null) {
    await _storage.write(key: _lastKey, value: '$newest');
    return 0;
  }
  final last = int.tryParse(raw) ?? 0;
  final fresh = inbox.items.where((n) => n.id > last && !n.read && _types.contains(n.type)).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  // com o push ligado neste celular o servidor já avisou: aqui só avança a referência (senão chegam 2 avisos)
  for (final n in viaPush ? const <AppNotification>[] : fresh) {
    await LocalReminders.instance.showNow(
      key: 'aviso:${n.id}',
      title: n.title,
      body: n.message,
      channelId: 'avisos',
      channelName: 'Avisos do salão',
      channelDescription: 'Novos agendamentos, cancelamentos e remarcações dos clientes',
    );
  }
  if (newest > last) await _storage.write(key: _lastKey, value: '$newest');
  return fresh.length;
}

/// Roda em segundo plano (app fechado): entra com a sessão guardada e confere os avisos do salão.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task != _task) return true;
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await initializeDateFormatting('pt_BR');
      await LocalReminders.instance.init();
      final session = Session();
      await session.restore();
      if (session.state == SessionState.signedIn) {
        await notifyNewStaffAlerts(session.api, viaPush: Push.configured && await session.pushToken != null);
      }
    } catch (e) {
      debugPrint('Verificação de avisos falhou: $e');
    }
    return true;
  });
}

/// Agenda a verificação periódica (Android; o sistema escolhe o momento exato para poupar bateria).
Future<void> scheduleBackgroundChecks() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await Workmanager().initialize(backgroundDispatcher);
    await Workmanager().registerPeriodicTask(
      _task,
      _task,
      // com push ligado o servidor avisa na hora; a consulta fica só como reserva
      frequency: Push.configured ? const Duration(hours: 1) : const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  } catch (e) {
    debugPrint('Não foi possível agendar a verificação de avisos: $e');
  }
}
