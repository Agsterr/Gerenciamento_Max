import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_cliente/booking_store.dart';
import 'package:salao_cliente/confirm_reminders.dart';
import 'package:salao_cliente/screens/booking_screen.dart';
import 'package:salao_core/salao_core.dart';

Booking _booking({required DateTime startAt, bool confirmable = true, List<int> days = const [1, 2], String status = 'SCHEDULED'}) =>
    Booking.fromJson({
      'token': 'tok123',
      'startAt': startAt.toIso8601String(),
      'endAt': startAt.add(const Duration(hours: 1)).toIso8601String(),
      'status': status,
      'serviceId': 1,
      'serviceName': 'Corte',
      'professionalId': 7,
      'professionalName': 'Ana',
      'price': 80,
      'customerName': 'Maria Souza',
      'cancelable': true,
      'confirmable': confirmable,
      'reminderDays': days,
    });

const _saved = SavedBooking(slug: 'bella', token: 'tok123', salonName: 'Studio Bella');

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('confirmReminders', () {
    final now = DateTime(2026, 10, 20, 9);

    test('avisa 1 dia e 2 dias antes, às 10h', () {
      final list = confirmReminders([(_saved, _booking(startAt: DateTime(2026, 10, 23, 14)))], now: now);
      expect(list.map((r) => r.at), [DateTime(2026, 10, 21, 10), DateTime(2026, 10, 22, 10)]);
      expect(list.first.title, 'Seu horário é amanhã');
      expect(list.first.body, contains('Corte às 14:00 · Studio Bella'));
      expect(list.first.payload, 'bella/tok123');
    });

    test('pula aviso que já passou ou fica em cima do horário', () {
      // amanhã às 11h: o aviso de 1 dia antes (hoje 10h) já passou depois das 10h
      final late = confirmReminders([(_saved, _booking(startAt: DateTime(2026, 10, 21, 11)))], now: DateTime(2026, 10, 20, 12));
      expect(late, isEmpty);
      // amanhã às 11h, agora 9h: só o de 1 dia antes (hoje 10h)
      expect(confirmReminders([(_saved, _booking(startAt: DateTime(2026, 10, 21, 11)))], now: now).single.at,
          DateTime(2026, 10, 20, 10));
    });

    test('nada para quem já confirmou ou com o lembrete desligado', () {
      expect(confirmReminders([(_saved, _booking(startAt: DateTime(2026, 10, 23, 14), confirmable: false))], now: now), isEmpty);
      expect(confirmReminders([(_saved, _booking(startAt: DateTime(2026, 10, 23, 14), days: const []))], now: now), isEmpty);
    });
  });

  testWidgets('cliente confirma presença na tela do agendamento', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final start = DateTime.now().add(const Duration(days: 1));
    var confirmed = false;
    final api = ApiClient(
      baseUrl: 'http://api',
      httpClient: MockClient((req) async {
        if (req.url.path.endsWith('/confirm')) confirmed = true;
        final b = confirmed
            ? {'status': 'CONFIRMED', 'confirmable': false}
            : {'status': 'SCHEDULED', 'confirmable': true};
        return http.Response(
          jsonEncode({
            'token': 'tok123',
            'startAt': start.toIso8601String(),
            'endAt': start.add(const Duration(hours: 1)).toIso8601String(),
            'serviceId': 1,
            'serviceName': 'Corte',
            'professionalId': 7,
            'professionalName': 'Ana',
            'price': 80,
            'customerName': 'Maria Souza',
            'cancelable': true,
            'reminderDays': [1],
            ...b,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await tester.pumpWidget(MaterialApp(home: BookingScreen(slug: 'bella', token: 'tok123', api: api, salonName: 'Studio Bella')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar presença'));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(find.text('Presença confirmada'), findsOneWidget);
    expect(find.text('Confirmar presença'), findsNothing);
  });
}
