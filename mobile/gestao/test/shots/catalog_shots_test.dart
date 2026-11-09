import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_core/salao_core.dart';
import 'package:salao_gestao/screens/catalog_screen.dart';
import 'package:salao_gestao/session.dart';

import '../support/screenshot.dart';

http.Response _json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});

Future<Session> _session() async {
  FlutterSecureStorage.setMockInitialValues({'jwt': 'x'});
  final client = MockClient((req) async {
    switch (req.url.path) {
      case '/api/me':
        return _json({'id': 1, 'name': 'Ana', 'email': 'ana@x.com', 'role': 'OWNER', 'salonId': 1, 'salonSlug': 'bella'});
      case '/api/services':
        return _json({
          'items': [
            {'id': 1, 'name': 'Corte feminino', 'durationMinutes': 60, 'price': 120, 'cost': 20, 'active': true, 'category': 'Cabelo'},
            {'id': 2, 'name': 'Plástica de fios', 'durationMinutes': 120, 'price': 250, 'cost': 60, 'active': true, 'category': 'Cabelo'},
            {'id': 3, 'name': 'Sobrancelha', 'durationMinutes': 30, 'price': 40, 'cost': 5, 'active': false},
          ],
          'page': 0, 'size': 20, 'total': 3, 'hasMore': false,
        });
      default:
        return _json(<Object>[]);
    }
  });
  final session = Session(httpClient: client);
  await session.restore();
  return session;
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  testWidgets('cadastros: lista de serviços com ⋮', (tester) async {
    final session = await _session();
    await shot(tester, Scaffold(body: CatalogScreen(session: session)), 'cadastros_360', width: 360, height: 700);
  }, skip: !shotsEnabled);

  testWidgets('cadastros: menu ⋮ aberto', (tester) async {
    final session = await _session();
    await shot(tester, Scaffold(body: CatalogScreen(session: session)), 'cadastros_menu_360', width: 360, height: 700,
        before: (t) async {
      await t.tap(find.byTooltip('Editar ou excluir').first);
      await t.pumpAndSettle();
    });
  }, skip: !shotsEnabled);

  testWidgets('cadastros: fonte grande', (tester) async {
    final session = await _session();
    await shot(tester, Scaffold(body: CatalogScreen(session: session)), 'cadastros_360_fonte_grande', width: 360, height: 700, textScale: 1.4);
  }, skip: !shotsEnabled);

  testWidgets('aviso (snackbar) no tema escuro e no claro', (tester) async {
    for (final dark in [true, false]) {
      await shot(
        tester,
        const Scaffold(body: Center(child: Text('tela'))),
        'aviso_${dark ? 'escuro' : 'claro'}',
        width: 360,
        height: 300,
        dark: dark,
        before: (t) async {
          showMessage(t.element(find.byType(Scaffold).first), 'Cliente confirmou presença: Jéssica · plástica de Fios · ter. 27/10 às 09:00');
          await t.pump();
          await t.pump(const Duration(milliseconds: 800));
          expect(find.byType(SnackBar), findsOneWidget);
        },
      );
    }
  }, skip: !shotsEnabled);
}
