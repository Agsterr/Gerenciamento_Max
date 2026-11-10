import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salao_core/salao_core.dart';

/// Servidor falso controlável: online/offline e atraso.
class _Server {
  bool online = true;
  Duration delay = Duration.zero;
  int counter = 0;
  final List<String> received = [];

  late final MockClient client = MockClient((req) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (!online) throw const SocketException('sem rede');
    received.add('${req.method} ${req.url.path}');
    if (req.method == 'GET') return http.Response(jsonEncode({'n': ++counter}), 200);
    if (req.url.path.endsWith('/recusa')) return http.Response.bytes(utf8.encode(jsonEncode({'detail': 'Horário já cancelado'})), 409);
    return http.Response('', 204);
  });
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('api_cache'));
  tearDown(() => tmp.deleteSync(recursive: true));

  ApiClient client(_Server s, {String? scope = 'u1', Duration fresh = Duration.zero}) => ApiClient(
        baseUrl: 'http://api',
        httpClient: s.client,
        cache: ApiCache(scope: () => scope, freshFor: fresh, fallbackAfter: const Duration(milliseconds: 100), baseDir: () async => tmp),
      );

  test('sem internet, devolve o que estava guardado (inclusive depois de reabrir o app)', () async {
    final s = _Server();
    final api = client(s);
    expect(await api.get('/api/x'), {'n': 1});
    s.online = false;
    expect(await api.get('/api/x'), {'n': 1});
    expect(api.status.value.online, isFalse);
    // app reaberto: memória vazia, lê do disco
    final reopened = client(s);
    expect(await reopened.get('/api/x'), {'n': 1});
    // nunca baixado: sem internet dá o erro de sempre
    await expectLater(api.get('/api/nunca'), throwsA(isA<ApiException>()));
  });

  test('servidor lento: mostra o guardado na hora e avisa quando chegar o novo', () async {
    final s = _Server();
    final api = client(s);
    await api.get('/api/x');
    s.delay = const Duration(milliseconds: 400);
    final updates = <String>[];
    final sub = api.refreshed.listen(updates.add);
    final sw = Stopwatch()..start();
    expect(await api.get('/api/x'), {'n': 1});
    expect(sw.elapsedMilliseconds, lessThan(350));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(updates, ['/api/x']);
    s.delay = Duration.zero;
    expect(await api.get('/api/x'), {'n': 3}); // já veio o 2 em segundo plano; agora busca de novo
    await sub.cancel();
  });

  test('resposta recente não vai ao servidor de novo', () async {
    final s = _Server();
    final api = client(s, fresh: const Duration(minutes: 1));
    await api.get('/api/x');
    await api.get('/api/x');
    expect(s.received.where((r) => r == 'GET /api/x'), hasLength(1));
  });

  test('alteração sem internet vai para a fila e é enviada quando conectar; recusada vira aviso', () async {
    final s = _Server();
    final api = client(s);
    var queued = 0;
    api.onQueued = () => queued++;
    await api.get('/api/agenda');
    s.online = false;
    expect(await api.post('/api/appointments/1/confirm', null, true), isNull);
    expect(await api.post('/api/appointments/2/recusa', null, true), isNull);
    expect(queued, 2);
    expect(api.status.value.pending, 2);
    // sem a opção de fila, o erro aparece como sempre
    await expectLater(api.post('/api/customers', {'name': 'x'}), throwsA(isA<ApiException>()));
    // a fila sobrevive a fechar o app
    final reopened = client(s);
    s.online = true;
    final updates = <String>[];
    final sub = reopened.refreshed.listen(updates.add);
    await reopened.resume();
    expect(s.received, containsAllInOrder(['POST /api/appointments/1/confirm', 'POST /api/appointments/2/recusa']));
    expect(reopened.status.value.pending, 0);
    expect(reopened.status.value.failures, ['Horário já cancelado']);
    await Future<void>.delayed(Duration.zero);
    expect(updates, contains('*'));
    await sub.cancel();
  });

  test('sem cache (app do cliente) nada muda', () async {
    final s = _Server();
    final api = ApiClient(baseUrl: 'http://api', httpClient: s.client);
    await api.get('/api/x');
    s.online = false;
    await expectLater(api.get('/api/x'), throwsA(isA<ApiException>()));
    await expectLater(api.post('/api/y', null, true), throwsA(isA<ApiException>()));
  });

  test('sair da conta apaga o que estava guardado', () async {
    final s = _Server();
    final api = client(s);
    await api.get('/api/x');
    await api.cache!.clear();
    s.online = false;
    await expectLater(api.get('/api/x'), throwsA(isA<ApiException>()));
  });
}
