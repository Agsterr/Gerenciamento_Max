import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_gestao/screens/customers_screen.dart';
import 'package:salao_gestao/session.dart';

import '../support/screenshot.dart';

/// Formulário de novo cliente com "Importar da agenda do celular" (backend real).
void main() {
  setUpAll(() async {
    HttpOverrides.global = null;
    await initializeDateFormatting('pt_BR');
  });

  for (final (suffix, scale, dark) in [('', 1.0, true), ('_clara', 1.0, false), ('_fonte_grande', 1.4, true)]) {
    testWidgets('novo cliente$suffix', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final session = Session();
      await tester.runAsync(() => session.login('dona@shots.test', 'senha123'));
      await shot(tester, CustomersScreen(session: session), 'cl_novo$suffix', width: 360, height: 800, textScale: scale, dark: dark,
          before: (t) async {
        await t.tap(find.text('Cliente').last);
        await t.pump();
        await settleNetwork(t, rounds: 4);
      });
    }, skip: !shotsEnabled);
  }
}
