import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_gestao/screens/pricing_screen.dart';
import 'package:salao_gestao/screens/shell.dart';
import 'package:salao_gestao/session.dart';
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
}
