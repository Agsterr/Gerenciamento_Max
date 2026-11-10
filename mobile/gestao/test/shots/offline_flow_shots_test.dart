import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_gestao/screens/shell.dart';
import 'package:salao_gestao/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/screenshot.dart';

/// App aberto com o servidor no ar; o servidor cai (OFFLINE_KILL=comando) e a Agenda continua com o que estava guardado.
void main() {
  setUpAll(() async {
    HttpOverrides.global = null;
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('agenda sem internet', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    final s = Session();
    await tester.runAsync(() => s.login('rita@shots.test', 'senha123'));
    await shot(tester, Shell(session: s), 'offline_agenda', width: 360, height: 800, before: (t) async {
      await t.runAsync(() async {
        await Process.run('bash', ['-c', Platform.environment['OFFLINE_KILL'] ?? 'true']);
        await Future<void>.delayed(const Duration(seconds: 1));
        try {
          await s.api.post('/api/appointments/999/confirm', null, true);
        } catch (_) {}
      });
      await settleNetwork(t, rounds: 4);
    });
  }, skip: !shotsEnabled);
}
