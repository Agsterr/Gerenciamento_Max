import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_gestao/screens/agenda_screen.dart';
import 'package:salao_gestao/screens/catalog_screen.dart';
import 'package:salao_gestao/screens/finance_screen.dart';
import 'package:salao_gestao/screens/settings_screen.dart';
import 'package:salao_gestao/screens/shell.dart';
import 'package:salao_gestao/session.dart';

import '../support/screenshot.dart';

/// Fluxos (folhas, abas, diálogos) do app de gestão contra o backend de verdade. Veja real_shots_test.dart.
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

  Future<void> tapText(WidgetTester t, String text, {int index = 0}) async {
    await t.tap(find.text(text).at(index));
    await t.pump();
  }

  Future<void> openDay(WidgetTester t) => tapText(t, '10');

  for (final (suffix, scale, dark) in [('', 1.0, true), ('_clara', 1.0, false), ('_fonte_grande', 1.4, true)]) {
    testWidgets('agenda com atendimentos$suffix', (tester) async {
      final s = await signedIn(tester);
      await shot(tester, AgendaScreen(session: s), 'f_agenda_dia$suffix', width: 360, height: 1100, textScale: scale, dark: dark,
          before: openDay);
    }, skip: !shotsEnabled);
  }

  testWidgets('agenda: toque no agendamento', (tester) async {
    final s = await signedIn(tester);
    await shot(tester, AgendaScreen(session: s), 'f_agenda_acoes', width: 360, height: 900, before: (t) async {
      await openDay(t);
      await settleNetwork(t, rounds: 6);
      await t.tap(find.text('Jéssica Lima').first);
      await t.pump();
    });
  }, skip: !shotsEnabled);

  testWidgets('agenda: novo agendamento', (tester) async {
    final s = await signedIn(tester);
    await shot(tester, AgendaScreen(session: s), 'f_agenda_novo', width: 360, height: 900, before: (t) async {
      await tapText(t, 'Agendar');
      await settleNetwork(t, rounds: 8);
    });
  }, skip: !shotsEnabled);

  testWidgets('agenda: pendentes', (tester) async {
    final s = await signedIn(tester);
    await shot(tester, AgendaScreen(session: s), 'f_agenda_pendentes', width: 360, height: 800, before: (t) async {
      await t.tap(find.textContaining('aguardando sua confirmação').first);
      await t.pump();
    });
  }, skip: !shotsEnabled);

  testWidgets('cadastros: equipe', (tester) async {
    final s = await signedIn(tester);
    await shot(tester, Scaffold(body: CatalogScreen(session: s)), 'f_cadastros_equipe', width: 360, height: 700, before: (t) async {
      await tapText(t, 'Equipe');
    });
  }, skip: !shotsEnabled);

  for (final (suffix, scale) in [('', 1.0), ('_fonte_grande', 1.4)]) {
    testWidgets('cadastros: produtos$suffix', (tester) async {
      final s = await signedIn(tester);
      await shot(tester, Scaffold(body: CatalogScreen(session: s)), 'f_cadastros_produtos$suffix', width: 360, height: 800, textScale: scale,
          before: (t) async {
        await tapText(t, 'Produtos');
        await settleNetwork(t, rounds: 14);
      });
    }, skip: !shotsEnabled);
  }

  testWidgets('cadastros: novo serviço (folha)', (tester) async {
    final s = await signedIn(tester);
    await shot(tester, Scaffold(body: CatalogScreen(session: s)), 'f_cadastros_novo_servico', width: 360, height: 900, before: (t) async {
      await tapText(t, 'Novo');
      await settleNetwork(t, rounds: 6);
    });
  }, skip: !shotsEnabled);

  testWidgets('cadastros: editar produto (folha)', (tester) async {
    final s = await signedIn(tester);
    await shot(tester, Scaffold(body: CatalogScreen(session: s)), 'f_cadastros_editar_produto', width: 360, height: 900, before: (t) async {
      await tapText(t, 'Produtos');
      await settleNetwork(t, rounds: 6);
      await t.tap(find.text('Shampoo hidratante').first);
      await settleNetwork(t, rounds: 6);
    });
  }, skip: !shotsEnabled);

  testWidgets('painel: financeiro e PDF', (tester) async {
    final s = await signedIn(tester);
    await shot(tester, PanelScreen(session: s), 'f_painel_financeiro', width: 360, height: 900, before: (t) async {
      await tapText(t, 'Financeiro');
      await settleNetwork(t, rounds: 8);
    });
  }, skip: !shotsEnabled);

  testWidgets('financeiro: nova despesa', (tester) async {
    final s = await signedIn(tester);
    await shot(tester, FinanceScreen(session: s), 'f_financeiro_despesa', width: 360, height: 900, before: (t) async {
      await tapText(t, 'Despesa');
      await settleNetwork(t, rounds: 6);
    });
  }, skip: !shotsEnabled);

  testWidgets('ajustes: parte de baixo', (tester) async {
    final s = await signedIn(tester);
    await shot(tester, SettingsScreen(session: s), 'f_ajustes_baixo', width: 360, height: 900, before: (t) async {
      await t.drag(find.byType(ListView).first, const Offset(0, -3000));
      await t.pump();
    });
  }, skip: !shotsEnabled);

  testWidgets('shell: navegação em 5 abas fonte grande', (tester) async {
    final s = await signedIn(tester);
    await shot(tester, Shell(session: s), 'f_shell_fonte_grande', width: 360, height: 800, textScale: 1.4);
  }, skip: !shotsEnabled);
}
