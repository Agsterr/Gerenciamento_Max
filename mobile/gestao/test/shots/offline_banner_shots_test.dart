import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salao_core/salao_core.dart';
import 'package:salao_gestao/widgets/offline_banner.dart';

import '../support/screenshot.dart';

/// Faixa do topo: sem internet, enviando a fila e alteração recusada.
void main() {
  for (final (suffix, scale) in [('', 1.0), ('_fonte_grande', 1.4)]) {
    testWidgets('faixa offline$suffix', (tester) async {
      final states = [
        const ApiStatus(online: false),
        const ApiStatus(online: false, pending: 3),
        const ApiStatus(pending: 1),
        const ApiStatus(failures: ['Este horário já foi cancelado.']),
      ];
      await shot(
        tester,
        Scaffold(
          body: Column(children: [
            for (final s in states) ...[
              OfflineBanner(api: ApiClient()..status.value = s),
              const SizedBox(height: 12),
            ],
          ]),
        ),
        'faixa_offline$suffix',
        width: 360,
        height: 420,
        textScale: scale,
      );
    }, skip: !shotsEnabled);
  }
}
