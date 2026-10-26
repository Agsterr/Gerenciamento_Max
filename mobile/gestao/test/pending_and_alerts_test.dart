import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_core/salao_core.dart';
import 'package:salao_gestao/background.dart';
import 'package:salao_gestao/screens/pending_screen.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _appointment(int id, String customer) => {
      'id': id, 'startAt': '2030-01-02T10:00:00', 'endAt': '2030-01-02T10:30:00', 'status': 'SCHEDULED',
      'customer': {'id': 1, 'name': customer}, 'customerPhone': '11988887777',
      'professional': {'id': 7, 'name': 'Ana'}, 'service': {'id': 3, 'name': 'Corte'},
      'estimatedMinutes': 30, 'realMinutes': null, 'price': 50, 'commissionAmount': 0, 'startedAt': null, 'finishedAt': null,
      'notes': null, 'serviceNotes': null, 'source': 'ONLINE', 'reminderSentAt': null, 'customerConfirmedAt': null,
      'rework': false, 'discountAmount': 0, 'promotionName': null, 'pendingAcceptance': true, 'salonConfirmedAt': null,
    };

Map<String, dynamic> _note(int id, String type, {bool read = false}) =>
    {'id': id, 'type': type, 'appointmentId': 1, 'title': 'Título $id', 'message': 'Mensagem $id', 'createdAt': '2030-01-01T09:00:00', 'read': read};

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('pendências: aceitar tira o agendamento da lista e chama /accept', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final calls = <String>[];
    final api = ApiClient(
      baseUrl: 'http://api',
      httpClient: MockClient((req) async {
        calls.add('${req.method} ${req.url.path}');
        return _json(_appointment(1, 'Maria'));
      }),
    );
    final items = [Appointment.fromJson(_appointment(1, 'Maria')), Appointment.fromJson(_appointment(2, 'Joana'))];
    await tester.pumpWidget(MaterialApp(home: PendingAcceptanceScreen(api: api, items: items)));
    expect(find.text('Maria'), findsOneWidget);
    expect(find.text('Joana'), findsOneWidget);

    await tester.tap(find.text('Aceitar').first);
    await tester.pumpAndSettle();
    expect(calls, ['POST /api/appointments/1/accept']);
    expect(find.text('Maria'), findsNothing);
    expect(find.text('Joana'), findsOneWidget);
  });

  test('avisos em segundo plano: primeira rodada só guarda a referência; depois avisa só o novo e não lido', () async {
    var items = [_note(5, 'BOOKED'), _note(4, 'CANCELED', read: true)];
    final api = ApiClient(
      baseUrl: 'http://api',
      httpClient: MockClient((req) async => _json({'unread': 1, 'items': items})),
    );
    expect(await notifyNewStaffAlerts(api), 0); // primeira vez
    expect(await notifyNewStaffAlerts(api), 0); // nada novo

    items = [_note(8, 'CANCELED'), _note(7, 'REMINDERS'), _note(6, 'RESCHEDULED', read: true), ..._previous];
    expect(await notifyNewStaffAlerts(api), 1); // só o cancelamento: lembrete tem notificação própria; o lido já foi visto
    expect(await notifyNewStaffAlerts(api), 0); // não repete

    await markNotified(20);
    items = [_note(15, 'BOOKED'), _note(21, 'CONFIRMED')];
    expect(await notifyNewStaffAlerts(api), 1); // 15 já foi marcado como avisado

    // com push neste celular o servidor já avisou: não mostra de novo e avança a referência
    items = [_note(30, 'BOOKED'), _note(21, 'CONFIRMED')];
    expect(await notifyNewStaffAlerts(api, viaPush: true), 1);
    expect(await notifyNewStaffAlerts(api), 0);
  });
}

final _previous = [_note(5, 'BOOKED'), _note(4, 'CANCELED', read: true)];
