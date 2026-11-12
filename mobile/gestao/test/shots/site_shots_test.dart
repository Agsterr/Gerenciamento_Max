import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_core/salao_core.dart';
import 'package:salao_gestao/screens/pricing_screen.dart';
import 'package:salao_gestao/screens/shell.dart';
import 'package:salao_gestao/session.dart';
import 'package:salao_gestao/shop/shop_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/screenshot.dart';

/// Fotos do app para o site (frontend/public/screens): tema claro, 390 × 795 dp, o dobro de resolução.
/// SHOTS=1 SHOT_DIR=build/site flutter test test/shots/site_shots_test.dart --dart-define=API_URL=http://localhost:8085
void main() {
  setUpAll(() async {
    HttpOverrides.global = null;
    await initializeDateFormatting('pt_BR');
  });

  Future<Session> signedIn(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final session = Session();
    await tester.runAsync(() => session.login('dona@shots.test', 'senha123'));
    return session;
  }

  void site(String name, Widget Function(Session s) build, {Future<void> Function(WidgetTester t)? before}) {
    testWidgets(name, (tester) async {
      final s = await signedIn(tester);
      await shot(tester, build(s), name, width: 390, height: 795, dark: false, pixelRatio: 2, before: before);
    }, skip: !shotsEnabled);
  }

  Future<void> tab(WidgetTester t, String label) async {
    await t.tap(find.text(label).last);
    await t.pump();
    await settleNetwork(t, rounds: 8);
  }

  site('gestao-agenda', (s) => Shell(session: s));
  site('gestao-novo', (s) => Shell(session: s), before: (t) async {
    await t.tap(find.text('Agendar').last);
    await t.pump();
    await settleNetwork(t, rounds: 8);
  });
  site('gestao-cadastros', (s) => Shell(session: s), before: (t) => tab(t, 'Cadastros'));
  site('gestao-financeiro', (s) => Shell(session: s), before: (t) async {
    await tab(t, 'Painel');
    await tab(t, 'Financeiro');
  });
  site('gestao-precificacao', (s) => PricingScreen(api: s.api));

  // novidades
  testWidgets('gestao-offline', (tester) async {
    final s = await signedIn(tester);
    await shot(tester, Shell(session: s), 'gestao-offline', width: 390, height: 795, dark: false, pixelRatio: 2, before: (t) async {
      // agenda já carregada; a conexão cai e duas ações ficam guardadas para enviar depois
      s.api.status.value = const ApiStatus(online: false, pending: 2);
      await t.pump();
    });
  }, skip: !shotsEnabled);
  testWidgets('gestao-temas', (tester) async {
    final s = await signedIn(tester);
    Brand.palette = BrandPalette.azul;
    addTearDown(() => Brand.palette = BrandPalette.rosa);
    await shot(tester, Shell(session: s), 'gestao-temas', width: 390, height: 795, dark: false, pixelRatio: 2, before: (t) async {
      await tab(t, 'Ajustes');
      await t.scrollUntilVisible(find.text('Cor do aplicativo'), 200, scrollable: find.byType(Scrollable).first);
      await t.pump();
      await t.ensureVisible(find.text('Cor do aplicativo')); // seletor de cores no topo
      await t.pump();
      await t.drag(find.byType(Scrollable).first, const Offset(0, 40));
      await t.pump();
    });
  }, skip: !shotsEnabled);
  site('gestao-loja', (s) => ShopScreen(session: s));
}
