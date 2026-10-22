import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:salao_core/salao_core.dart';

import 'booking_store.dart';
import 'confirm_reminders.dart';
import 'promo_alerts.dart';

/// Push pelo Firebase (chega na hora, com o app fechado). A configuração vem do build
/// (`--dart-define=FIREBASE_*`); sem ela o app segue só com a verificação em segundo plano.
class Push {
  Push._();

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  static bool get configured =>
      _apiKey.isNotEmpty && _appId.isNotEmpty && _senderId.isNotEmpty && _projectId.isNotEmpty && !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;

  static const options = FirebaseOptions(apiKey: _apiKey, appId: _appId, messagingSenderId: _senderId, projectId: _projectId);

  /// Liga o push: pega o código do celular, manda para os salões salvos e trata toques e mensagens.
  static Future<void> start(ApiClient api, BookingStore store) async {
    if (!configured) return;
    try {
      await Firebase.initializeApp(options: options);
      final messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(_onBackground);
      // app aberto: o Android não mostra sozinho, então mostra como aviso local
      FirebaseMessaging.onMessage.listen((m) => _showForeground(m, store));
      FirebaseMessaging.onMessageOpenedApp.listen(_open);
      final initial = await messaging.getInitialMessage();
      if (initial != null) _open(initial);

      // Código clássico do FCM (campo "token" da API v1 que o servidor usa).
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null) await _register(api, store, token);
      // ignore: deprecated_member_use
      messaging.onTokenRefresh.listen((t) => _register(api, store, t));
    } catch (e) {
      debugPrint('Push indisponível: $e');
    }
  }

  /// Celular novo (ou código renovado): avisa todos os salões salvos, sem contar como visita.
  static Future<void> _register(ApiClient api, BookingStore store, String token) async {
    final changed = store.pushToken != token;
    await store.setPushToken(token);
    if (!changed && !store.pushRegistrationDue) return;
    for (final s in store.salons) {
      await sendPresence(api, store, s.slug, visit: false);
    }
    await store.markPushRegistered();
  }

  static Future<void> _showForeground(RemoteMessage m, BookingStore store) async {
    ackPush(m.data['messageId'], store.pushToken);
    final key = _key(m);
    if (key != null) {
      if (store.seenPromotions.contains(key)) return;
      await store.markPromotionsSeen([key]);
    }
    final n = m.notification;
    if (n == null) return;
    await LocalReminders.instance.showNow(
      key: 'push:${m.messageId}',
      title: n.title ?? 'Promoção',
      body: n.body ?? '',
      payload: _payload(m) ?? '',
    );
  }

  /// Toque na notificação: abre o salão com o serviço da promoção (mesmo caminho do aviso local).
  static void _open(RemoteMessage m) {
    // tocou na notificação: confirma o recebimento (o Android já a mostrou sozinho com o app fechado)
    BookingStore.load().then((store) => ackPush(m.data['messageId'], store.pushToken));
    final payload = _payload(m);
    if (payload != null) LocalReminders.instance.tapped.value = payload;
  }

  static String? _payload(RemoteMessage m) {
    final slug = m.data['slug'];
    if (slug == null) return null;
    // horário que o salão aceitou, cancelou ou mudou: abre o agendamento
    if (m.data['type'] == 'booking' && m.data['token'] != null) return '$confirmGroup|$slug/${m.data['token']}';
    if (m.data['type'] != 'promo') return null;
    return '$promoGroup|$slug/${m.data['serviceId'] ?? ''}';
  }

  static String? _key(RemoteMessage m) {
    final slug = m.data['slug'], id = m.data['promotionId'];
    return slug == null || id == null ? null : '$slug:$id';
  }
}

/// Mensagem com o app fechado: o Android já mostrou a notificação; só marca como avisada
/// para a verificação em segundo plano não repetir.
@pragma('vm:entry-point')
Future<void> _onBackground(RemoteMessage m) async {
  final store = await BookingStore.load();
  await ackPush(m.data['messageId'], store.pushToken);
  final key = Push._key(m);
  if (key != null) await store.markPromotionsSeen([key]);
}
