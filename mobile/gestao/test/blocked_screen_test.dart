import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salao_core/salao_core.dart';
import 'package:salao_gestao/main.dart';
import 'package:salao_gestao/screens/blocked_screen.dart';
import 'package:salao_gestao/session.dart';

http.Response _blocked(String detail) => http.Response.bytes(
    utf8.encode(jsonEncode({'status': 403, 'detail': detail, 'code': 'ACCOUNT_BLOCKED'})), 403,
    headers: {'content-type': 'application/problem+json'});

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('tela de bloqueio mostra o motivo e só sai por "Sair"', (tester) async {
    phoneSize(tester);
    var signedOut = false;
    await tester.pumpWidget(MaterialApp(
      home: BlockedScreen(reason: 'Mensalidade em atraso', onSignOut: () => signedOut = true),
    ));

    expect(find.text('Sua conta foi bloqueada'), findsOneWidget);
    expect(find.text('Mensalidade em atraso'), findsOneWidget);
    expect(find.text(AppConfig.supportEmail), findsOneWidget);

    final popScope = tester.widget<PopScope>(find.byType(PopScope));
    expect(popScope.canPop, isFalse);

    await tester.tap(find.text('Sair'));
    expect(signedOut, isTrue);
  });

  test('ACCOUNT_BLOCKED em qualquer requisição derruba a sessão', () async {
    FlutterSecureStorage.setMockInitialValues({'jwt': 'abc'});
    final session = Session(httpClient: MockClient((_) async => _blocked('Salão suspenso')));
    await session.restore();
    expect(session.state, SessionState.blocked);
    expect(session.blockedReason, 'Salão suspenso');
    expect(await const FlutterSecureStorage().read(key: 'jwt'), isNull);

    await session.signOut();
    expect(session.state, SessionState.signedOut);
    expect(session.blockedReason, isNull);
  });

  testWidgets('login de conta bloqueada abre a tela de bloqueio', (tester) async {
    phoneSize(tester);
    final session = Session(httpClient: MockClient((_) async => _blocked('Usuário bloqueado pelo suporte')));
    await tester.runAsync(session.restore);
    await tester.pumpWidget(GestaoApp(
      session: session,
      updates: AppUpdateService(app: 'gestao', httpClient: MockClient((_) async => http.Response('', 404))),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'dono@salao.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'segredo123');
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.byType(BlockedScreen), findsOneWidget);
    expect(find.text('Usuário bloqueado pelo suporte'), findsOneWidget);

    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    expect(find.text('Entre na sua conta'), findsOneWidget);
  });
}
