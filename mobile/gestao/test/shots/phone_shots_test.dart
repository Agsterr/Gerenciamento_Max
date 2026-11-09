import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_gestao/screens/settings_screen.dart';
import 'package:salao_gestao/screens/shell.dart';
import 'package:salao_gestao/session.dart';

import '../support/screenshot.dart';

/// O celular real do dono: tela estreita (~355 dp) e fonte do sistema grande. Onde o texto costuma cortar.
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

  for (final scale in [1.3, 1.6]) {
    final tag = 'x${(scale * 10).round()}';
    testWidgets('ajustes $tag', (tester) async {
      final s = await signedIn(tester);
      await shot(tester, SettingsScreen(session: s), 'p_ajustes_$tag', width: 355, height: 1000, textScale: scale);
    }, skip: !shotsEnabled);
    testWidgets('painel financeiro $tag', (tester) async {
      final s = await signedIn(tester);
      await shot(tester, PanelScreen(session: s), 'p_painel_fin_$tag', width: 355, height: 1700, textScale: scale, before: (t) async {
        await t.tap(find.text('Financeiro').first);
        await t.pump();
        await settleNetwork(t, rounds: 8);
      });
    }, skip: !shotsEnabled);
    testWidgets('painel atendimentos $tag', (tester) async {
      final s = await signedIn(tester);
      await shot(tester, PanelScreen(session: s), 'p_painel_atend_$tag', width: 355, height: 1500, textScale: scale);
    }, skip: !shotsEnabled);
  }
}
