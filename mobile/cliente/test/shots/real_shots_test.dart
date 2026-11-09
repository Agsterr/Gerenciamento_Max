import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_cliente/booking_store.dart';
import 'package:salao_cliente/screens/about_screen.dart';
import 'package:salao_cliente/screens/booking_screen.dart';
import 'package:salao_cliente/screens/home_screen.dart';
import 'package:salao_cliente/screens/salon_screen.dart';
import 'package:salao_core/salao_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/screenshot.dart';

/// Capturas de TODAS as telas do app do cliente contra o backend real (porta 8085, dados do seed).
/// SHOTS=1 TOKENS=/caminho/tokens.json flutter test test/shots --dart-define=API_URL=http://localhost:8085
void main() {
  final tokens = shotsEnabled ? jsonDecode(File(Platform.environment['TOKENS']!).readAsStringSync()) as Map<String, dynamic> : <String, dynamic>{};

  setUpAll(() async {
    HttpOverrides.global = null;
    await initializeDateFormatting('pt_BR');
  });

  Future<BookingStore> store({bool saved = true}) async {
    final bookings = saved
        ? [
            for (final k in ['pendente', 'aceito', 'confirmado', 'cancelado'])
              jsonEncode({'slug': 'studio-bella', 'token': tokens[k], 'salonName': 'Studio Bella'})
          ]
        : <String>[];
    SharedPreferences.setMockInitialValues({
      'bookings': bookings,
      if (saved) 'salons': [jsonEncode({'slug': 'studio-bella', 'name': 'Studio Bella'})],
      'customer.name': 'Camila Teste',
      'customer.phone': '11999887766',
      'notifications.asked': true,
    });
    return BookingStore.load();
  }

  final variants = <(String, double, bool)>[('', 1.0, true), ('_clara', 1.0, false), ('_fonte_grande', 1.4, true)];

  void screen(String name, Future<Widget> Function(WidgetTester t) build,
      {double height = 800, Future<void> Function(WidgetTester t)? before, bool bigFont = true, bool light = true}) {
    for (final (suffix, scale, dark) in variants) {
      if (suffix == '_fonte_grande' && !bigFont) continue;
      if (suffix == '_clara' && !light) continue;
      testWidgets('$name$suffix', (tester) async {
        final w = await build(tester);
        await shot(tester, w, '$name$suffix', width: 360, height: height, textScale: scale, dark: dark, before: before);
      }, skip: !shotsEnabled);
    }
  }

  final api = ApiClient();

  screen('c_home', (t) async => HomeScreen(store: await store(), api: api), height: 900);
  screen('c_home_sem_dados', (t) async => HomeScreen(store: await store(saved: false), api: api), height: 900, bigFont: false);
  screen('c_busca_resultado', (t) async => HomeScreen(store: await store(saved: false), api: api), height: 900, bigFont: false,
      before: (t) async {
    await t.enterText(find.byType(TextField).first, 'bella');
    await t.pump(const Duration(milliseconds: 600));
    await settleNetwork(t, rounds: 8);
  });
  screen('c_meus_horarios', (t) async => HomeScreen(store: await store(), api: api), height: 1100, before: (t) async {
    await t.tap(find.text('Meus horários').last);
    await t.pump();
    await settleNetwork(t, rounds: 14);
  });
  screen('c_salao', (t) async => SalonScreen(slug: 'studio-bella', store: await store(), api: api), height: 1300);
  screen('c_salao_servico', (t) async => SalonScreen(slug: 'studio-bella', store: await store(saved: false), api: api), height: 1300,
      bigFont: false, before: (t) async {
    await t.tap(find.text('Corte feminino').last);
    await t.pump();
    await settleNetwork(t, rounds: 10);
  });
  for (final k in ['pendente', 'aceito', 'confirmado', 'cancelado']) {
    screen('c_agendamento_$k', (t) async => BookingScreen(slug: 'studio-bella', token: tokens[k] as String, api: api, salonName: 'Studio Bella'),
        height: 900, bigFont: k == 'confirmado', light: k == 'confirmado');
  }
  screen('c_sobre', (t) async => AboutScreen(store: await store(), api: api), height: 900, bigFont: false);
  screen('c_buscar_horarios', (t) async => HomeScreen(store: await store(saved: false), api: api), height: 900, bigFont: false,
      before: (t) async {
    await t.tap(find.text('Meus horários').last);
    await t.pump();
    await settleNetwork(t, rounds: 6);
    final find1 = find.textContaining('Buscar');
    if (find1.evaluate().isNotEmpty) {
      await t.tap(find1.first);
      await settleNetwork(t, rounds: 6);
    }
  });
}
