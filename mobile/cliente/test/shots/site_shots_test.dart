import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_cliente/booking_store.dart';
import 'package:salao_cliente/screens/booking_screen.dart';
import 'package:salao_cliente/screens/home_screen.dart';
import 'package:salao_cliente/screens/salon_screen.dart';
import 'package:salao_core/salao_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/screenshot.dart';

/// Fotos do app do cliente para o site (frontend/public/screens): tema claro, 390 × 795 dp, o dobro de resolução.
/// SHOTS=1 SHOT_DIR=build/site TOKENS=/caminho/tokens.json flutter test test/shots/site_shots_test.dart --dart-define=API_URL=http://localhost:8085
void main() {
  final tokens = shotsEnabled ? jsonDecode(File(Platform.environment['TOKENS']!).readAsStringSync()) as Map<String, dynamic> : <String, dynamic>{};

  setUpAll(() async {
    HttpOverrides.global = null;
    await initializeDateFormatting('pt_BR');
  });

  Future<BookingStore> store({bool saved = true}) async {
    SharedPreferences.setMockInitialValues({
      'bookings': saved
          ? [
              for (final k in ['aceito', 'confirmado']) jsonEncode({'slug': 'studio-bella', 'token': tokens[k], 'salonName': 'Studio Bella'})
            ]
          : <String>[],
      if (saved) 'salons': [jsonEncode({'slug': 'studio-bella', 'name': 'Studio Bella'})],
      'customer.name': 'Mariana Alves',
      'customer.phone': '11999887766',
      'notifications.asked': true,
    });
    return BookingStore.load();
  }

  final api = ApiClient();

  void site(String name, Future<Widget> Function() build, {Future<void> Function(WidgetTester t)? before}) {
    testWidgets(name, (tester) async {
      final w = await build();
      await shot(tester, w, name, width: 390, height: 795, dark: false, pixelRatio: 2, before: before);
    }, skip: !shotsEnabled);
  }

  site('cliente-home', () async => HomeScreen(store: await store(), api: api));
  // a lista só monta o que está na tela: rola até o texto
  Future<void> scrollTo(WidgetTester t, String text, {double extra = 0}) async {
    await t.scrollUntilVisible(find.text(text), 200, scrollable: find.byType(Scrollable).first);
    await t.pump();
    await t.ensureVisible(find.text(text)); // título no topo da tela
    await t.pump();
    if (extra != 0) {
      await t.drag(find.byType(Scrollable).first, Offset(0, -extra));
      await t.pump();
    }
  }

  site('cliente-salao', () async => SalonScreen(slug: 'studio-bella', store: await store(), api: api), before: (t) async {
    await scrollTo(t, '1. Escolha o serviço', extra: -60);
  });
  site('cliente-horarios', () async => SalonScreen(slug: 'studio-bella', store: await store(), api: api), before: (t) async {
    await scrollTo(t, 'Coloração');
    await t.tap(find.text('Coloração').last);
    await t.pump();
    await settleNetwork(t, rounds: 10);
    await scrollTo(t, '3. Quando?', extra: -60);
    // dia seguinte: hoje à tarde sobram poucos horários
    final tomorrow = DateTime.now().add(const Duration(days: 1)).day.toString();
    await t.tap(find.text(tomorrow).first);
    await t.pump();
    await settleNetwork(t, rounds: 8);
  });
  site('cliente-confirmado',
      () async => BookingScreen(slug: 'studio-bella', token: tokens['confirmado'] as String, api: api, salonName: 'Studio Bella'));
  site('cliente-meus-horarios', () async => HomeScreen(store: await store(), api: api), before: (t) async {
    await t.tap(find.text('Meus horários').last);
    await t.pump();
    await settleNetwork(t, rounds: 14);
  });
}
