import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_core/salao_core.dart';
import 'package:salao_gestao/screens/settings_screen.dart';
import 'package:salao_gestao/session.dart';
import 'package:salao_gestao/shop/purchases_screen.dart';
import 'package:salao_gestao/shop/shop_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/screenshot.dart';

/// Loja dos vendedores no app (backend real com dois vendedores para a Rita e nenhum para a Lumi).
void main() {
  setUpAll(() async {
    HttpOverrides.global = null;
    await initializeDateFormatting('pt_BR');
  });

  Future<Session> login(WidgetTester tester, String email) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final session = Session();
    await tester.runAsync(() => session.login(email, 'senha123'));
    return session;
  }

  // um produto do primeiro vendedor e um do segundo (a lista só monta o que está na tela: rola até o outro)
  Future<void> addFromTwoVendors(WidgetTester t) async {
    await t.tap(find.byTooltip('Mais').first);
    await t.pump();
    await t.scrollUntilVisible(find.text('Esmalte Gel'), 300, scrollable: find.byType(Scrollable).first);
    await t.pump();
    final card = find.ancestor(of: find.text('Esmalte Gel'), matching: find.byType(SoftCard)).first;
    await t.ensureVisible(find.descendant(of: card, matching: find.byTooltip('Mais')));
    await t.tap(find.descendant(of: card, matching: find.byTooltip('Mais')));
    await t.pump();
    await t.drag(find.byType(Scrollable).first, const Offset(0, 4000));
    await t.pump();
  }

  for (final (suffix, scale, dark) in [('', 1.0, true), ('_clara', 1.0, false), ('_fonte_grande', 1.4, true)]) {
    testWidgets('loja$suffix', (tester) async {
      final s = await login(tester, 'rita@shots.test');
      await shot(tester, ShopScreen(session: s), 'loja$suffix', width: 360, height: 1300, textScale: scale, dark: dark,
          before: (t) async {
        await addFromTwoVendors(t);
      });
    }, skip: !shotsEnabled);
  }

  testWidgets('loja pedido', (tester) async {
    final s = await login(tester, 'rita@shots.test');
    await shot(tester, ShopScreen(session: s), 'loja_pedido', width: 360, height: 900, before: (t) async {
      await addFromTwoVendors(t);
      await t.tap(find.text('Pedir'));
      await t.pump();
      await settleNetwork(t, rounds: 4);
    });
  }, skip: !shotsEnabled);

  for (final (suffix, scale) in [('', 1.0), ('_fonte_grande', 1.4)]) {
    testWidgets('compras$suffix', (tester) async {
      final s = await login(tester, 'rita@shots.test');
      await shot(tester, PurchasesScreen(session: s), 'compras$suffix', width: 360, height: 1300, textScale: scale);
    }, skip: !shotsEnabled);
  }

  for (final (who, email) in [('com_vendedor', 'rita@shots.test'), ('sem_vendedor', 'lumi@shots.test')]) {
    testWidgets('ajustes $who', (tester) async {
      final s = await login(tester, email);
      await shot(tester, SettingsScreen(session: s), 'ajustes_$who', width: 360, height: 1500);
    }, skip: !shotsEnabled);
  }
}
