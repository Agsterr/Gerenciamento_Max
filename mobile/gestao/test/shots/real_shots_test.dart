import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_gestao/screens/agenda_screen.dart';
import 'package:salao_gestao/screens/blocked_screen.dart';
import 'package:salao_gestao/screens/catalog_screen.dart';
import 'package:salao_gestao/screens/customers_screen.dart';
import 'package:salao_gestao/screens/finance_screen.dart';
import 'package:salao_gestao/screens/login_screen.dart';
import 'package:salao_gestao/screens/my_reminders_screen.dart';
import 'package:salao_gestao/screens/notifications_screen.dart';
import 'package:salao_gestao/screens/portfolio_screen.dart';
import 'package:salao_gestao/screens/pricing_screen.dart';
import 'package:salao_gestao/screens/promotions_screen.dart';
import 'package:salao_gestao/screens/reminders_screen.dart';
import 'package:salao_gestao/screens/settings_screen.dart';
import 'package:salao_gestao/screens/shell.dart';
import 'package:salao_gestao/session.dart';

import '../support/screenshot.dart';

/// Capturas de TODAS as telas do app de gestão contra o backend de verdade (porta 8085, dados do seed).
/// Rode: SHOTS=1 flutter test test/shots/real_shots_test.dart --dart-define=API_URL=http://localhost:8085
void main() {
  setUpAll(() async {
    HttpOverrides.global = null; // rede de verdade
    await initializeDateFormatting('pt_BR');
  });

  Future<Session> signedIn(WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final session = Session();
    await tester.runAsync(() => session.login('dona@shots.test', 'senha123'));
    return session;
  }

  final variants = <(String, double, double, bool)>[
    ('', 360, 1.0, true),
    ('_clara', 360, 1.0, false),
    ('_fonte_grande', 360, 1.4, true),
  ];

  void screenTests(String name, Widget Function(Session s) build, {double height = 780, bool onlyDark = false, bool bigFont = true}) {
    for (final (suffix, w, scale, dark) in variants) {
      if (suffix == '_fonte_grande' && !bigFont) continue;
      if (suffix == '_clara' && onlyDark) continue;
      testWidgets('$name$suffix', (tester) async {
        final s = await signedIn(tester);
        await shot(tester, build(s), '$name$suffix', width: w, height: height, textScale: scale, dark: dark);
      }, skip: !shotsEnabled);
    }
  }

  testWidgets('login', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await shot(tester, LoginScreen(session: Session()), 'g_login', width: 360, height: 780);
  }, skip: !shotsEnabled);
  testWidgets('login fonte grande', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    await shot(tester, LoginScreen(session: Session()), 'g_login_fonte_grande', width: 360, height: 780, textScale: 1.4);
  }, skip: !shotsEnabled);
  testWidgets('bloqueio', (tester) async {
    await shot(tester, BlockedScreen(reason: 'Mensalidade em atraso', onSignOut: () {}), 'g_bloqueio', width: 360, height: 780);
  }, skip: !shotsEnabled);

  screenTests('g_agenda', (s) => AgendaScreen(session: s), height: 900);
  screenTests('g_clientes', (s) => CustomersScreen(session: s));
  screenTests('g_cadastros', (s) => Scaffold(body: CatalogScreen(session: s)));
  screenTests('g_painel', (s) => PanelScreen(session: s), height: 900);
  screenTests('g_financeiro', (s) => FinanceScreen(session: s), height: 1100);
  screenTests('g_ajustes', (s) => SettingsScreen(session: s), height: 1500);
  screenTests('g_shell', (s) => Shell(session: s), height: 900, bigFont: false);
  screenTests('g_promocoes', (s) => PromotionsScreen(session: s));
  screenTests('g_portfolio', (s) => PortfolioScreen(api: s.api));
  screenTests('g_precificacao', (s) => PricingScreen(api: s.api), height: 1000);
  screenTests('g_lembretes', (s) => RemindersScreen(api: s.api), bigFont: false);
  screenTests('g_meus_lembretes', (s) => MyRemindersScreen(api: s.api), bigFont: false);
  screenTests('g_avisos', (s) => NotificationsScreen(api: s.api), bigFont: false);
}
