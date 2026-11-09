import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_gestao/screens/notifications_screen.dart';
import 'package:salao_gestao/session.dart';

import '../support/screenshot.dart';

/// Tela de notificações (filtros por situação e período, agrupada por dia) contra o backend real.
void main() {
  setUpAll(() async {
    HttpOverrides.global = null;
    await initializeDateFormatting('pt_BR');
  });

  Future<Session> signedIn(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final session = Session();
    await tester.runAsync(() => session.login('dona@shots.test', 'senha123'));
    return session;
  }

  for (final (suffix, scale, dark) in [('', 1.0, true), ('_clara', 1.0, false), ('_fonte_grande', 1.4, true)]) {
    testWidgets('notificações$suffix', (tester) async {
      final s = await signedIn(tester);
      await shot(tester, NotificationsScreen(api: s.api), 'n_todas$suffix', width: 360, height: 1100, textScale: scale, dark: dark);
    }, skip: !shotsEnabled);
  }

  testWidgets('notificações: não lidas', (tester) async {
    final s = await signedIn(tester);
    await shot(tester, NotificationsScreen(api: s.api), 'n_nao_lidas', width: 360, height: 800, before: (t) async {
      await t.tap(find.textContaining('Não lidas').first);
      await t.pump();
      await settleNetwork(t, rounds: 8);
    });
  }, skip: !shotsEnabled);

  testWidgets('notificações: lidas, 7 dias', (tester) async {
    final s = await signedIn(tester);
    await shot(tester, NotificationsScreen(api: s.api), 'n_lidas_7dias', width: 360, height: 800, before: (t) async {
      await t.tap(find.text('Lidas').first);
      await t.pump();
      await settleNetwork(t, rounds: 6);
      await t.tap(find.text('7 dias').first);
      await t.pump();
      await settleNetwork(t, rounds: 8);
    });
  }, skip: !shotsEnabled);

  testWidgets('notificações: menu', (tester) async {
    final s = await signedIn(tester);
    await shot(tester, NotificationsScreen(api: s.api), 'n_menu', width: 360, height: 800, before: (t) async {
      await t.tap(find.byTooltip('Mais opções'));
      await t.pump();
    });
  }, skip: !shotsEnabled);

  testWidgets('notificações: vazio (hoje, lidas)', (tester) async {
    final s = await signedIn(tester);
    await shot(tester, NotificationsScreen(api: s.api), 'n_vazio', width: 360, height: 700, before: (t) async {
      await t.tap(find.text('Lidas').first);
      await t.pump();
      await settleNetwork(t, rounds: 6);
      await t.tap(find.text('Hoje').first);
      await t.pump();
      await settleNetwork(t, rounds: 8);
    });
  }, skip: !shotsEnabled);
}
