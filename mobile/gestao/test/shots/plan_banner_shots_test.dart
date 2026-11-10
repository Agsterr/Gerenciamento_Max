import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salao_core/salao_core.dart';
import 'package:salao_gestao/screens/agenda_screen.dart';

import '../support/screenshot.dart';

PlanInfo _plan(String status, {bool paid = true, int? days, bool play = false}) => PlanInfo(
      status: status,
      paid: paid,
      daysLeft: days,
      professionals: (1, 2),
      services: (3, 5),
      customers: (4, 10),
      contactWhatsapp: '',
      contactEmail: '',
      managedByPlay: play,
    );

/// Faixa do plano: teste, plano pago perto de vencer (Play e não-Play) e plano vencido.
void main() {
  final cases = {
    'plano_vence_hoje_play': _plan('ACTIVE', days: 0, play: true),
    'plano_vence_em_3': _plan('ACTIVE', days: 3),
    'plano_venceu': _plan('EXPIRED', days: 0),
    'teste_terminou': _plan('EXPIRED', paid: false, days: 0),
  };
  for (final (suffix, scale) in [('', 1.0), ('_fonte_grande', 1.4)]) {
    testWidgets('faixa do plano$suffix', (tester) async {
      final column = Column(mainAxisSize: MainAxisSize.min, children: [
        for (final p in cases.values) PlanBanner(p, onSubscribe: () {}),
      ]);
      await shot(tester, Scaffold(body: SafeArea(child: SingleChildScrollView(child: column))), 'plano_faixas$suffix',
          width: 360, height: 800, textScale: scale);
    }, skip: !shotsEnabled);
  }
}
