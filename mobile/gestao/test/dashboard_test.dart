import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_gestao/dashboard_period.dart';
import 'package:salao_gestao/screens/dashboard_screen.dart';
import 'package:salao_gestao/session.dart';

const _counts = {
  'total': 12, 'scheduled': 2, 'done': 7, 'canceled': 2, 'noShow': 1, 'rework': 1, 'online': 4,
  'newCustomers': 3, 'returningCustomers': 5, 'uniqueCustomers': 9,
};

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));
  setUp(() => FlutterSecureStorage.setMockInitialValues({'jwt': 'x'}));

  group('Period', () {
    test('semana vai de segunda a domingo e anda de 7 em 7 dias', () {
      final w = Period.of(PeriodKind.week, DateTime(2026, 10, 22)); // quinta
      expect(w.from, DateTime(2026, 10, 19));
      expect(w.to, DateTime(2026, 10, 25));
      expect(w.shift(-1).from, DateTime(2026, 10, 12));
      expect(w.shift(1).to, DateTime(2026, 11, 1));
    });

    test('mês e ano cobrem o período inteiro e viram o gráfico certo', () {
      final m = Period.of(PeriodKind.month, DateTime(2026, 2, 10));
      expect((m.from, m.to), (DateTime(2026, 2, 1), DateTime(2026, 2, 28)));
      expect(m.group, 'DAY');
      expect(m.shift(-1).from, DateTime(2026, 1, 1));
      final y = Period.of(PeriodKind.year, DateTime(2026, 5, 5));
      expect((y.from, y.to), (DateTime(2026, 1, 1), DateTime(2026, 12, 31)));
      expect(y.group, 'MONTH');
      expect(y.shift(1).from, DateTime(2027, 1, 1));
      expect(Period.of(PeriodKind.month, DateTime(2026, 12, 3)).shift(1).from, DateTime(2027, 1, 1));
    });

    test('rótulos', () {
      expect(Period.of(PeriodKind.month, DateTime(2026, 10, 22)).label, 'Outubro de 2026');
      expect(Period.of(PeriodKind.year, DateTime(2026, 10, 22)).label, '2026');
      expect(Period.of(PeriodKind.week, DateTime(2026, 10, 22)).label, '19 out – 25 out');
    });
  });

  testWidgets('painel mostra os totais do período e troca para semana', (tester) async {
    tester.view.physicalSize = const Size(1170, 3200);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final asked = <String>[];
    final session = Session(
      httpClient: MockClient((req) async {
        if (req.url.path == '/api/reports/dashboard') {
          asked.add('${req.url.queryParameters['from']}..${req.url.queryParameters['to']} ${req.url.queryParameters['group']}');
          return http.Response.bytes(
              utf8.encode(jsonEncode({
                'totals': _counts,
                'previous': {..._counts, 'done': 5},
                'byProfessional': [
                  {'name': 'Ana', 'total': 12, 'done': 7, 'canceled': 2, 'noShow': 1, 'rework': 1, 'scheduled': 2},
                ],
                'series': [
                  {'start': '2026-10-01', 'end': '2026-10-01', 'done': 3, 'canceled': 1, 'noShow': 0, 'scheduled': 0},
                ],
              })),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return http.Response(
            jsonEncode({'id': 1, 'name': 'Dono', 'email': 'd@x.com', 'role': 'OWNER', 'salonId': 1, 'salonSlug': 's'}), 200,
            headers: {'content-type': 'application/json'});
      }),
    );
    await tester.runAsync(session.restore);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DashboardScreen(session: session))));
    await tester.pumpAndSettle();

    expect(find.text('7'), findsWidgets); // concluídos
    expect(find.text('de 12 agendamentos · 1 refação(ões)'), findsOneWidget);
    expect(find.text('+40%'), findsWidgets); // 7 contra 5
    await tester.scrollUntilVisible(find.text('Ana'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Voltaram'), findsOneWidget);
    expect(asked.single, endsWith('DAY'));

    await tester.scrollUntilVisible(find.text('Semana'), -300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Semana'));
    await tester.pumpAndSettle();
    expect(asked.length, 2);
    expect(find.text('Anterior'), findsNothing); // só tooltip
  });
}
