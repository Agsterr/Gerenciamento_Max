import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_core/salao_core.dart';
import 'package:salao_gestao/screens/appointment_search_screen.dart';
import 'package:salao_gestao/screens/customers_screen.dart';
import 'package:salao_gestao/session.dart';

http.Response _json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _appointment(int id, String customer, String status) => {
      'id': id,
      'startAt': '2026-09-1${id % 9}T10:00:00',
      'endAt': '2026-09-1${id % 9}T11:00:00',
      'status': status,
      'customer': {'id': id, 'name': customer},
      'customerPhone': '1198888000$id',
      'professional': {'id': 1, 'name': 'Ana'},
      'service': {'id': 1, 'name': 'Corte'},
      'estimatedMinutes': 60,
      'price': 80,
      'source': 'ADMIN',
    };

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('busca de agendamentos: texto, situação e "mais antigos" vão para a API; toque devolve o dia', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final seen = <Uri>[];
    final api = ApiClient(
      baseUrl: 'http://api',
      httpClient: MockClient((req) async {
        seen.add(req.url);
        final done = req.url.queryParameters['status'] == 'DONE';
        final items = done
            ? [_appointment(2, 'Joana Lima', 'DONE')]
            : [_appointment(1, 'Maria Souza', 'SCHEDULED'), _appointment(2, 'Joana Lima', 'DONE')];
        return _json({'items': items, 'page': 0, 'size': 20, 'total': items.length, 'hasMore': false});
      }),
    );

    DateTime? opened;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => opened = await Navigator.push<DateTime>(
                context, MaterialPageRoute(builder: (_) => AppointmentSearchScreen(api: api))),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Maria Souza'), findsOneWidget);
    expect(find.text('Joana Lima'), findsOneWidget);
    expect(find.text('2 agendamento(s)'), findsOneWidget);
    expect(seen.last.queryParameters['order'], 'desc');

    await tester.ensureVisible(find.text('Finalizados')); // a fileira de situações rola para o lado
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalizados'));
    await tester.pumpAndSettle();
    expect(seen.last.queryParameters['status'], 'DONE');
    expect(find.text('Maria Souza'), findsNothing);

    await tester.enterText(find.byType(TextField), 'joana');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(seen.last.queryParameters['q'], 'joana');

    await tester.tap(find.text('Mais recentes'));
    await tester.pumpAndSettle();
    expect(seen.last.queryParameters['order'], 'asc');

    await tester.tap(find.text('Joana Lima'));
    await tester.pumpAndSettle();
    expect(opened, DateTime(2026, 9, 12, 10));
  });

  testWidgets('clientes: carrega por página e busca no servidor', (tester) async {
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final seen = <Uri>[];
    final session = Session(
      httpClient: MockClient((req) async {
        seen.add(req.url);
        final page = int.parse(req.url.queryParameters['page'] ?? '0');
        final q = req.url.queryParameters['q'];
        final names = q == null ? [for (var i = 0; i < 25; i++) 'Cliente $i'] : ['Zélia'];
        final slice = names.skip(page * 20).take(20).toList();
        return _json({
          'items': [
            for (final n in slice) {'id': names.indexOf(n) + 1, 'name': n, 'phone': '11999990000'},
          ],
          'page': page,
          'size': 20,
          'total': names.length,
          'hasMore': (page + 1) * 20 < names.length,
        });
      }),
    );

    await tester.pumpWidget(MaterialApp(home: CustomersScreen(session: session)));
    await tester.pumpAndSettle();
    expect(find.text('25 cliente(s)'), findsOneWidget);
    expect(seen.first.queryParameters['page'], '0');
    expect(find.text('Cliente 0'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zél');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(seen.last.queryParameters['q'], 'zél');
    expect(find.text('1 cliente(s) encontrados'), findsOneWidget);
    expect(find.text('Zélia'), findsOneWidget);
    expect(find.text('Cliente 0'), findsNothing);
  });
}
