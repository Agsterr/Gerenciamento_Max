import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_core/salao_core.dart';
import 'package:workmanager/workmanager.dart';

import 'booking_store.dart';
import 'promo_alerts.dart';

const _promoTask = 'verificar-promocoes';

/// Roda em segundo plano (app fechado): confere as promoções dos salões que a pessoa usa e avisa as novas.
@pragma('vm:entry-point')
void backgroundDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task != _promoTask) return true;
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await initializeDateFormatting('pt_BR');
      await LocalReminders.instance.init();
      final store = await BookingStore.load();
      if (store.salons.isNotEmpty) await checkPromotions(ApiClient(), store, askPermission: false);
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
      frequency: const Duration(hours: 2),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  } catch (e) {
    debugPrint('Não foi possível agendar a verificação de promoções: $e');
  }
}
