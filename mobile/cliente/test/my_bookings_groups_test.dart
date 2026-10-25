import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_cliente/booking_store.dart';
import 'package:salao_cliente/screens/my_bookings_screen.dart';
import 'package:salao_core/salao_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('Meus horários separa próximos, anteriores e cancelados, e mostra o histórico aos poucos', (tester) async {
    tester.view.physicalSize = const Size(1170, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    // t0: próximo; t1..t12: anteriores; c1, c2: cancelados
    final data = <String, (DateTime, String)>{
      't0': (now.add(const Duration(days: 3)), 'SCHEDULED'),
      for (var i = 1; i <= 12; i++) 't$i': (now.subtract(Duration(days: i * 5)), 'DONE'),
      'c1': (now.subtract(const Duration(days: 2)), 'CANCELED'),
      'c2': (now.add(const Duration(days: 9)), 'CANCELED'),
    };
    SharedPreferences.setMockInitialValues({
      'bookings': [
        for (final t in data.keys) jsonEncode({'slug': 'bella', 'token': t, 'salonName': 'Studio Bella', 'seen': null}),
      ],
    });
    final store = await BookingStore.load();
    final api = ApiClient(
      baseUrl: 'http://api',
      httpClient: MockClient((req) async {
        final token = req.url.pathSegments.last;
        final (start, status) = data[token]!;
        return http.Response(
          jsonEncode({
            'token': token,
            'startAt': start.toIso8601String(),
            'endAt': start.add(const Duration(hours: 1)).toIso8601String(),
            'status': status,
            'serviceId': 1,
            'serviceName': 'Corte',
            'professionalId': 7,
            'professionalName': 'Ana',
            'price': 80,
            'customerName': 'Maria',
            'cancelable': false,
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: MyBookingsScreen(store: store, api: api, onBookNow: () {}))));
    await tester.pumpAndSettle();

    expect(find.text('Próximos (1)'), findsOneWidget);
    expect(find.text('Anteriores (12)'), findsOneWidget);
    expect(find.text('Cancelados (2)'), findsOneWidget);
    // só 10 anteriores à vista; o resto vem sob demanda
    expect(find.text('Mostrar mais (2)'), findsOneWidget);
    expect(find.text('Buscar por serviço, salão ou profissional'), findsOneWidget);

    await tester.ensureVisible(find.text('Mostrar mais (2)'));
    await tester.tap(find.text('Mostrar mais (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Mostrar mais (2)'), findsNothing);

    // busca: nada com esse texto
    await tester.enterText(find.byType(TextField), 'tintura');
    await tester.pumpAndSettle();
    expect(find.text('Nada encontrado para essa busca.'), findsOneWidget);
    expect(find.text('Próximos (1)'), findsNothing);
  });
}
