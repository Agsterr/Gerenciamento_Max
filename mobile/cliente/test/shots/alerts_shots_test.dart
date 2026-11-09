import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_cliente/booking_store.dart';
import 'package:salao_cliente/screens/alerts_screen.dart';
import 'package:salao_cliente/screens/home_screen.dart';
import 'package:salao_core/salao_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/screenshot.dart';

/// Tela de Avisos do app do cliente com dados de exemplo (histórico guardado no aparelho). Não precisa de backend.
void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  Future<BookingStore> seeded({bool withUnread = true}) async {
    final now = DateTime.now();
    String item(String id, String title, String body, String kind, DateTime at, bool read) => jsonEncode({
          'id': id, 'title': title, 'body': body, 'kind': kind, 'at': at.toIso8601String(), 'read': read,
          'payload': kind == 'promo' ? 'promo|studio-bella/5' : 'confirm|studio-bella/abc123',
        });
    SharedPreferences.setMockInitialValues({
      'alerts.log': [
        item('1', 'O salão confirmou o seu horário - Studio Bella', 'Corte feminino · ter., 17/11 às 12:00 com Ana Souza', 'booking', now.subtract(const Duration(hours: 2)), !withUnread),
        item('2', 'Promoção no Studio Bella', 'Manicure de R\$ 45,00 por R\$ 36,00 e mais 1 · até 19/11/2026', 'promo', now.subtract(const Duration(hours: 5)), !withUnread),
        item('3', 'O salão alterou o seu horário - Studio Bella', 'Coloração · qua., 18/11 às 16:00 com Ana Souza', 'booking', now.subtract(const Duration(days: 1, hours: 3)), true),
        item('4', 'O salão cancelou o seu horário - Barbearia do Zé', 'Corte masculino · sex., 06/11 às 10:00 com Zé', 'booking', now.subtract(const Duration(days: 3)), true),
        item('5', 'Promoção no Espaço Lia', 'Hidratação de R\$ 90,00 por R\$ 72,00 · até 30/10/2026', 'promo', now.subtract(const Duration(days: 12)), true),
        item('6', 'O salão confirmou o seu horário - Studio Bella', 'Manicure · qui., 29/10 às 13:00 com Bia Martins', 'booking', now.subtract(const Duration(days: 20)), true),
      ],
    });
    return BookingStore.load();
  }

  for (final (suffix, scale, dark) in [('', 1.0, true), ('_clara', 1.0, false), ('_fonte_grande', 1.4, true)]) {
    testWidgets('avisos$suffix', (tester) async {
      final store = await seeded();
      await shot(tester, AlertsScreen(store: store, api: ApiClient()), 'a_avisos$suffix', width: 360, height: 1000, textScale: scale, dark: dark);
    }, skip: !shotsEnabled);
  }

  testWidgets('avisos: não lidos', (tester) async {
    final store = await seeded();
    await shot(tester, AlertsScreen(store: store, api: ApiClient()), 'a_nao_lidos', width: 360, height: 700, before: (t) async {
      await t.tap(find.textContaining('Não lidos').first);
      await t.pump();
    });
  }, skip: !shotsEnabled);

  testWidgets('avisos: lidos, 7 dias', (tester) async {
    final store = await seeded();
    await shot(tester, AlertsScreen(store: store, api: ApiClient()), 'a_lidos_7dias', width: 360, height: 700, before: (t) async {
      await t.tap(find.text('Lidos').first);
      await t.pump();
      await t.tap(find.text('7 dias').first);
      await t.pump();
    });
  }, skip: !shotsEnabled);

  testWidgets('avisos: vazio', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = await BookingStore.load();
    await shot(tester, AlertsScreen(store: store, api: ApiClient()), 'a_vazio', width: 360, height: 600);
  }, skip: !shotsEnabled);

  testWidgets('início com sino e bolinha de avisos novos', (tester) async {
    final store = await seeded();
    await shot(tester, HomeScreen(store: store, api: ApiClient()), 'a_home_sino', width: 360, height: 500);
  }, skip: !shotsEnabled);
}
