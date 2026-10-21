import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Um aviso a agendar no aparelho. [at] é a hora local do salão (como vem da API).
class LocalReminder {
  const LocalReminder({required this.key, required this.at, required this.title, required this.body, required this.payload});

  /// Identifica o aviso (o mesmo aviso reagendado não duplica).
  final String key;
  final DateTime at;
  final String title;
  final String body;

  /// Volta em [LocalReminders.tapped] quando a pessoa toca na notificação.
  final String payload;
}

/// Notificações locais agendadas (sem servidor de push): lembrete de confirmar o horário no app do
/// cliente e lembretes de atendimento no app de gestão. Fora do Android/iOS (web, testes) não faz nada.
class LocalReminders {
  LocalReminders._();

  static final instance = LocalReminders._();

  /// iOS guarda no máximo 64 avisos pendentes por app.
  static const _maxPending = 40;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  tz.Location? _zone;

  /// Payload da notificação tocada (inclusive a que abriu o app).
  final tapped = ValueNotifier<String?>(null);

  bool get ready => _ready;

  /// [zone]: fuso dos horários da API (o do salão).
  Future<void> init({String zone = 'America/Sao_Paulo'}) async {
    if (_ready || kIsWeb || !(defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
      return;
    }
    try {
      tzdata.initializeTimeZones();
      _zone = tz.getLocation(zone);
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) => tapped.value = response.payload,
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) tapped.value = launch!.notificationResponse?.payload;
      _ready = true;
    } catch (e) {
      debugPrint('Notificações locais indisponíveis: $e');
    }
  }

  /// Pede permissão (Android 13+ e iOS). Retorna false se a pessoa negou.
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return await android.requestNotificationsPermission() ?? false;
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Troca todos os avisos agendados do [group] por [items] (só os futuros).
  Future<void> replace(String group, List<LocalReminder> items) async {
    final zone = _zone;
    if (!_ready || zone == null) return;
    try {
      for (final p in await _plugin.pendingNotificationRequests()) {
        if (p.payload?.startsWith('$group|') ?? false) await _plugin.cancel(id: p.id);
      }
      final now = DateTime.now();
      final future = items.where((r) => r.at.isAfter(now)).toList()..sort((a, b) => a.at.compareTo(b.at));
      for (final r in future.take(_maxPending)) {
        await _plugin.zonedSchedule(
          id: idFor(r.key),
          title: r.title,
          body: r.body,
          scheduledDate: tz.TZDateTime(zone, r.at.year, r.at.month, r.at.day, r.at.hour, r.at.minute),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'lembretes',
              'Lembretes',
              channelDescription: 'Lembretes de horários marcados',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: '$group|${r.payload}',
        );
      }
    } catch (e) {
      debugPrint('Falha ao agendar lembretes: $e');
    }
  }

  /// Aviso imediato (ex.: promoção nova num salão que o cliente usa).
  Future<void> showNow({required String key, required String title, required String body, String payload = ''}) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: idFor(key),
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'promocoes',
            'Promoções',
            channelDescription: 'Promoções dos salões que você usa',
            importance: Importance.defaultImportance,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('Falha ao mostrar aviso: $e');
    }
  }

  /// Payload sem o grupo ("grupo|payload" -> "payload"), ou nulo se for de outro grupo.
  static String? payloadOf(String? tapped, String group) =>
      tapped != null && tapped.startsWith('$group|') ? tapped.substring(group.length + 1) : null;

  /// Id estável (FNV-1a de 31 bits) para a mesma chave sempre gerar o mesmo aviso.
  static int idFor(String key) {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }
}
