import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:salao_core/salao_core.dart';

import 'session.dart';

/// Push pelo Firebase para a equipe: o servidor avisa na hora (novo agendamento, cancelamento, remarcação,
/// confirmação do cliente), mesmo com o app fechado. A configuração vem do build (`--dart-define=FIREBASE_*`);
/// sem ela o app segue só com a consulta periódica em segundo plano.
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

  static bool _started = false;

  /// Depois do login: cadastra este celular no servidor e passa a tratar as mensagens.
  static Future<void> start(Session session) async {
    if (!configured || _started) return;
    _started = true;
    try {
      await Firebase.initializeApp(options: options);
      final messaging = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(_onBackground);
      // app aberto: o Android não mostra sozinho, então mostra como aviso local
      FirebaseMessaging.onMessage.listen((m) => _showForeground(m, session));
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _ack(m, session));
      final initial = await messaging.getInitialMessage();
      if (initial != null) _ack(initial, session);

      // Código clássico do FCM (campo "token" da API v1 que o servidor usa).
      // ignore: deprecated_member_use
      final token = await messaging.getToken();
      if (token != null) await _register(session, token);
      // ignore: deprecated_member_use
      messaging.onTokenRefresh.listen((t) => _register(session, t));
    } catch (e) {
      _started = false;
      debugPrint('Push indisponível: $e');
    }
  }

  static Future<void> _register(Session session, String token) async {
    await session.rememberPushToken(token);
    if (session.state != SessionState.signedIn) return;
    try {
      await session.api.post('/api/me/push-token', {'token': token});
    } catch (_) {
      // sem rede agora: tenta de novo na próxima abertura
      _started = false;
    }
  }

  static Future<void> _ack(RemoteMessage m, Session session) async => ackPush(m.data['messageId'], await session.pushToken);

  static Future<void> _showForeground(RemoteMessage m, Session session) async {
    await _ack(m, session);
    final n = m.notification;
    if (n == null) return;
    await LocalReminders.instance.showNow(
      key: 'push:${m.messageId}',
      title: n.title ?? 'Aviso do salão',
      body: n.body ?? '',
      channelId: 'avisos',
      channelName: 'Avisos do salão',
      channelDescription: 'Novos agendamentos, cancelamentos e remarcações dos clientes',
    );
  }
}

/// Mensagem com o app fechado: o Android já mostrou a notificação; só confirma o recebimento.
@pragma('vm:entry-point')
Future<void> _onBackground(RemoteMessage m) async {
  await ackPush(m.data['messageId'], await const FlutterSecureStorage().read(key: 'push_token'));
}
