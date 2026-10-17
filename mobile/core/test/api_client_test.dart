import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salao_core/salao_core.dart';

void main() {
  test('envia token e decodifica JSON', () async {
    late http.BaseRequest sent;
    final api = ApiClient(
      baseUrl: 'http://api',
      token: () => 'abc',
      httpClient: MockClient((req) async {
        sent = req;
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    );
    expect(await api.get('/x'), {'ok': true});
    expect(sent.headers['Authorization'], 'Bearer abc');
  });

  test('converte ProblemDetail em ApiException e avisa 401', () async {
    var unauthorized = false;
    final api = ApiClient(
      baseUrl: 'http://api',
      token: () => 'abc',
      onUnauthorized: () => unauthorized = true,
      httpClient: MockClient((_) async => http.Response.bytes(utf8.encode(jsonEncode({'detail': 'Sessão expirada'})), 401)),
    );
    await expectLater(
      api.get('/x'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Sessão expirada')),
    );
    expect(unauthorized, isTrue);
  });

  test('403 ACCOUNT_BLOCKED vira AccountBlockedException com o motivo e avisa o app', () async {
    String? reason;
    var unauthorized = false;
    final api = ApiClient(
      baseUrl: 'http://api',
      token: () => 'abc',
      onUnauthorized: () => unauthorized = true,
      onAccountBlocked: (r) => reason = r,
      httpClient: MockClient((_) async => http.Response.bytes(
          utf8.encode(jsonEncode({
            'type': 'about:blank',
            'title': 'Forbidden',
            'status': 403,
            'detail': 'Mensalidade em atraso',
            'code': 'ACCOUNT_BLOCKED',
          })),
          403,
          headers: {'content-type': 'application/problem+json'})),
    );
    await expectLater(
      api.post('/api/auth/login', {'email': 'a@b.c'}),
      throwsA(isA<AccountBlockedException>()
          .having((e) => e.message, 'message', 'Mensalidade em atraso')
          .having((e) => e.code, 'code', 'ACCOUNT_BLOCKED')
          .having((e) => e.status, 'status', 403)),
    );
    expect(reason, 'Mensalidade em atraso');
    expect(unauthorized, isFalse);
  });

  test('ACCOUNT_BLOCKED sem detail usa mensagem padrão', () async {
    String? reason;
    final api = ApiClient(
      baseUrl: 'http://api',
      onAccountBlocked: (r) => reason = r,
      httpClient: MockClient((_) async => http.Response(jsonEncode({'code': 'ACCOUNT_BLOCKED'}), 403)),
    );
    await expectLater(api.get('/x'), throwsA(isA<AccountBlockedException>()));
    expect(reason, AccountBlockedException.defaultReason);
  });

  test('403 comum não é bloqueio de conta', () async {
    var blocked = false;
    final api = ApiClient(
      baseUrl: 'http://api',
      onAccountBlocked: (_) => blocked = true,
      httpClient: MockClient((_) async => http.Response.bytes(utf8.encode(jsonEncode({'detail': 'Só o dono pode fazer isso'})), 403)),
    );
    await expectLater(
      api.get('/x'),
      throwsA(isA<ApiException>()
          .having((e) => e is AccountBlockedException, 'bloqueio', isFalse)
          .having((e) => e.message, 'message', 'Só o dono pode fazer isso')),
    );
    expect(blocked, isFalse);
  });

  test('modelos aceitam a resposta da API', () {
    final a = Appointment.fromJson({
      'id': 1,
      'startAt': '2026-10-20T10:00:00',
      'endAt': '2026-10-20T11:00:00',
      'status': 'IN_PROGRESS',
      'customer': {'id': 2, 'name': 'Maria'},
      'customerPhone': '11999990000',
      'professional': {'id': 3, 'name': 'Ana'},
      'service': {'id': 4, 'name': 'Corte'},
      'estimatedMinutes': 60,
      'realMinutes': null,
      'price': 120,
      'commissionAmount': 0,
      'notes': null,
      'source': 'ONLINE',
    });
    expect(a.status, AppointmentStatus.inProgress);
    expect(a.online, isTrue);
    expect(a.price, 120.0);
    expect(formatPhone(a.customerPhone), '(11) 99999-0000');
  });
}
