import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_cliente/booking_store.dart';
import 'package:salao_cliente/screens/salon_screen.dart';
import 'package:salao_core/salao_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('cliente escolhe serviço, horário e agenda', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final store = await BookingStore.load();
    Map<String, dynamic>? bookingBody;

    final api = ApiClient(
      baseUrl: 'http://api',
      httpClient: MockClient((req) async {
        final path = req.url.path;
        Object body;
        if (path == '/api/public/salons/bella') {
          body = {
            'name': 'Studio Bella',
            'slug': 'bella',
            'phone': null,
            'address': 'Rua A, 1',
            'openTime': '09:00:00',
            'closeTime': '19:00:00',
            'workDays': '1,2,3,4,5,6,7',
            'services': [
              {'id': 1, 'name': 'Corte', 'description': null, 'durationMinutes': 60, 'price': 80},
            ],
            'professionals': [
              {'id': 7, 'name': 'Ana'},
            ],
          };
        } else if (path.endsWith('/availability')) {
          body = [
            {'time': '10:00:00', 'professionalIds': [7]},
          ];
        } else if (path.endsWith('/bookings') && req.method == 'POST') {
          bookingBody = jsonDecode(req.body) as Map<String, dynamic>;
          body = _booking;
        } else {
          body = _booking;
        }
        return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    );

    await tester.pumpWidget(MaterialApp(home: SalonScreen(slug: 'bella', store: store, api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Studio Bella'), findsWidgets);

    await tester.tap(find.text('Corte'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10:00'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(TextFormField, 'Nome'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nome'), 'Maria Souza');
    await tester.enterText(find.widgetWithText(TextFormField, 'WhatsApp'), '11988887777');
    await tester.tap(find.text('Agendar'));
    await tester.pumpAndSettle();

    expect(bookingBody?['name'], 'Maria Souza');
    expect((bookingBody?['startAt'] as String).endsWith('T10:00:00'), isTrue);
    expect(find.text('Tudo certo, Maria!'), findsOneWidget);
    expect(store.bookings.single.token, 'tok123');
    expect(store.phone, '11988887777');
  });
}

const _booking = {
  'token': 'tok123',
  'startAt': '2030-01-01T10:00:00',
  'endAt': '2030-01-01T11:00:00',
  'status': 'SCHEDULED',
  'serviceName': 'Corte',
  'professionalName': 'Ana',
  'price': 80,
  'customerName': 'Maria Souza',
  'cancelable': true,
};
