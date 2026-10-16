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
