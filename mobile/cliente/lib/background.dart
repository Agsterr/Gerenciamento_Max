import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_core/salao_core.dart';
import 'package:workmanager/workmanager.dart';

import 'booking_alerts.dart';
import 'booking_store.dart';
import 'promo_alerts.dart';
import 'push.dart';

const _promoTask = 'verificar-promocoes';

/// Roda em segundo plano (app fechado): confere as promoções dos salões que a pessoa usa e se o salão
/// confirmou, cancelou ou mudou algum horário dela, e avisa.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task != _promoTask) return true;
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await initializeDateFormatting('pt_BR');
      await LocalReminders.instance.init();
      final store = await BookingStore.load();
      final api = ApiClient();
      if (store.salons.isNotEmpty) await checkPromotions(api, store, askPermission: false);
      if (store.bookings.isNotEmpty) await checkBookingChanges(api, store);
    } catch (e) {
      debugPrint('Verificação de promoções falhou: $e');
    }
    return true; // sem nova tentativa: a próxima rodada periódica tenta de novo
  });
}

/// Agenda a verificação periódica (Android; o sistema decide o momento exato para poupar bateria).
Future<void> scheduleBackgroundChecks() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await Workmanager().initialize(backgroundDispatcher);
    await Workmanager().registerPeriodicTask(
      _promoTask,
      _promoTask,
      // com push ligado o servidor avisa na hora; a consulta fica só como reserva
      frequency: Push.configured ? const Duration(hours: 3) : const Duration(minutes: 30),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  } catch (e) {
    debugPrint('Não foi possível agendar a verificação de promoções: $e');
  }
}
