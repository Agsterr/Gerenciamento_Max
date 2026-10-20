import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_core/salao_core.dart';
import 'package:salao_gestao/screens/my_reminders_screen.dart';
import 'package:salao_gestao/screens/reminders_screen.dart';

http.Response _json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('lista clientes para lembrar, com quem já confirmou', (tester) async {
    final api = ApiClient(
      baseUrl: 'http://api',
      httpClient: MockClient((req) async => _json({
            'mode': 'BOTH',
            'days': [1, 2],
            'items': [
              {
                'appointmentId': 1,
                'daysBefore': 1,
                'startAt': '2026-10-21T10:00:00',
                'status': 'SCHEDULED',
                'customerName': 'Maria Souza',
                'customerPhone': '11988880001',
                'serviceName': 'Corte',
                'professionalName': 'Ana',
                'customerConfirmed': false,
                'reminderSentAt': null,
                'confirmUrl': 'https://salao/s/x/agendamento/t',
                'message': 'Olá',
                'whatsappUrl': 'https://wa.me/5511988880001?text=Ol%C3%A1',
              },
              {
                'appointmentId': 2,
                'daysBefore': 2,
                'startAt': '2026-10-22T11:00:00',
                'status': 'CONFIRMED',
                'customerName': 'João',
                'customerPhone': '11988880002',
                'serviceName': 'Barba',
                'professionalName': 'Ana',
                'customerConfirmed': true,
                'reminderSentAt': '2026-10-20T09:00:00',
                'confirmUrl': 'https://salao/s/x/agendamento/u',
                'message': 'Olá',
                'whatsappUrl': 'https://wa.me/5511988880002',
              },
            ],
          })),
    );

    await tester.pumpWidget(MaterialApp(home: RemindersScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Amanhã'), findsOneWidget);
    expect(find.text('Depois de amanhã'), findsOneWidget);
    expect(find.text('Maria Souza'), findsOneWidget);
    expect(find.text('Enviar'), findsOneWidget); // só quem ainda não confirmou
    expect(find.text('Cliente confirmou'), findsOneWidget);
  });

  testWidgets('profissional escolhe "1 dia antes às 19h" e salva', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    Map<String, dynamic>? saved;
    final api = ApiClient(
      baseUrl: 'http://api',
      httpClient: MockClient((req) async {
        if (req.url.path == '/api/professionals') {
          return _json([
            {'id': 3, 'name': 'Ana', 'phone': null, 'commissionPercent': 40, 'active': true},
          ]);
        }
        if (req.method == 'PUT') {
          saved = jsonDecode(req.body) as Map<String, dynamic>;
          return _json({
            'professionalId': saved!['professionalId'],
            'rules': [
              for (final r in saved!['rules'] as List) {'id': 1, ...(r as Map<String, dynamic>)},
            ],
          });
        }
        return _json({'professionalId': null, 'rules': <Object>[]});
      }),
    );

    await tester.pumpWidget(MaterialApp(home: MyRemindersScreen(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum lembrete ainda. Escolha abaixo.'), findsOneWidget);

    await tester.tap(find.text('1 dia antes, às 19:00'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(saved?['rules'], [
      {'daysBefore': 1, 'atTime': '19:00', 'minutesBefore': null},
    ]);
    expect(find.textContaining('Salvo!'), findsOneWidget);
  });
}
