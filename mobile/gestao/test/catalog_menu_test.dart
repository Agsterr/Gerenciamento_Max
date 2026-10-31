import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_gestao/screens/catalog_screen.dart';
import 'package:salao_gestao/session.dart';

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _service(int id, String name) => {
      'id': id,
      'name': name,
      'durationMinutes': 30,
      'price': 80,
      'cost': 10,
      'active': true,
    };

Future<Session> _session(String role, MockClient client) async {
  FlutterSecureStorage.setMockInitialValues({'jwt': 'x'});
  final session = Session(httpClient: client);
  await session.restore();
  return session;
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('serviço tem menu com Editar e Excluir; excluir pede confirmação e chama a API', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final calls = <String>[];
    var deleted = false;
    final client = MockClient((req) async {
      calls.add('${req.method} ${req.url.path}');
      if (req.url.path == '/api/me') {
        return _json({'id': 1, 'name': 'Ana', 'email': 'ana@x.com', 'role': 'OWNER', 'salonId': 1, 'salonSlug': 'ana'});
      }
      if (req.method == 'DELETE') {
        deleted = true;
        return http.Response('', 204);
      }
      if (req.url.path == '/api/services') {
        final items = deleted ? <Map<String, dynamic>>[] : [_service(7, 'Corte')];
        return _json({'items': items, 'page': 0, 'size': 20, 'total': items.length, 'hasMore': false});
      }
      return _json(<Object>[]);
    });
    final session = await _session('OWNER', client);

    await tester.pumpWidget(MaterialApp(home: CatalogScreen(session: session)));
    await tester.pumpAndSettle();
    expect(find.text('Corte'), findsOneWidget);

    await tester.tap(find.byTooltip('Editar ou excluir').first);
    await tester.pumpAndSettle();
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Excluir'), findsOneWidget);

    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Excluir serviço "Corte"'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(calls, contains('DELETE /api/services/7'));
    expect(find.text('Corte'), findsNothing);
  });

  testWidgets('quando o servidor recusa (tem histórico), a mensagem dele aparece e o serviço fica', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final client = MockClient((req) async {
      if (req.url.path == '/api/me') {
        return _json({'id': 1, 'name': 'Ana', 'email': 'ana@x.com', 'role': 'OWNER', 'salonId': 1, 'salonSlug': 'ana'});
      }
      if (req.method == 'DELETE') {
        return _json({'status': 422, 'detail': 'Este serviço já tem atendimentos no histórico'}, 422);
      }
      if (req.url.path == '/api/services') {
        return _json({'items': [_service(7, 'Corte')], 'page': 0, 'size': 20, 'total': 1, 'hasMore': false});
      }
      return _json(<Object>[]);
    });
    final session = await _session('OWNER', client);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CatalogScreen(session: session))));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar ou excluir').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(find.textContaining('atendimentos no histórico'), findsOneWidget);
    expect(find.text('Corte'), findsOneWidget);
  });

  testWidgets('equipe não tem Excluir (só Editar)', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final client = MockClient((req) async {
      if (req.url.path == '/api/me') {
        return _json({'id': 1, 'name': 'Ana', 'email': 'ana@x.com', 'role': 'OWNER', 'salonId': 1, 'salonSlug': 'ana'});
      }
      if (req.url.path == '/api/professionals') {
        return _json([
          {'id': 3, 'name': 'Bia', 'commissionPercent': 10, 'active': true}
        ]);
      }
      if (req.url.path == '/api/services') {
        return _json({'items': <Object>[], 'page': 0, 'size': 20, 'total': 0, 'hasMore': false});
      }
      return _json(<Object>[]);
    });
    final session = await _session('OWNER', client);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CatalogScreen(session: session))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Equipe'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Editar ou excluir').first);
    await tester.pumpAndSettle();
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Excluir'), findsNothing);
  });
}
