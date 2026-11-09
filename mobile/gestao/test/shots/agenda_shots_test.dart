import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_gestao/screens/agenda_screen.dart';
import 'package:salao_gestao/session.dart';

import '../support/screenshot.dart';

http.Response _json(Object body) =>
    http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _appt(int id, String customer, String start, String status, {bool online = false, bool confirmed = false}) => {
      'id': id,
      'startAt': start,
      'endAt': start.replaceFirst('T09', 'T10').replaceFirst('T14', 'T15'),
      'status': status,
      'customer': {'id': id, 'name': customer},
      'customerPhone': '11988880000',
      'professional': {'id': 1, 'name': 'Ana'},
      'service': {'id': 1, 'name': 'Corte feminino'},
      'estimatedMinutes': 60,
      'price': 120,
      'source': online ? 'ONLINE' : 'ADMIN',
      'customerConfirmed': confirmed,
    };

Future<Session> _session() async {
  FlutterSecureStorage.setMockInitialValues({'jwt': 'x'});
  final today = DateTime.now();
  String at(String t) => '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}T$t';
  final client = MockClient((req) async {
    switch (req.url.path) {
      case '/api/me':
        return _json({'id': 1, 'name': 'Ana Souza', 'email': 'ana@x.com', 'role': 'OWNER', 'salonId': 1, 'salonSlug': 'studio-bella'});
      case '/api/notifications':
        return _json({'unread': 3, 'items': <Object>[]});
      case '/api/appointments':
        return _json([
          _appt(1, 'Jéssica Lima', at('09:00:00'), 'SCHEDULED', online: true, confirmed: true),
          _appt(2, 'Maria Souza', at('14:00:00'), 'SCHEDULED'),
        ]);
      case '/api/professionals':
        return _json([
          {'id': 1, 'name': 'Ana', 'commissionPercent': 10, 'active': true},
          {'id': 2, 'name': 'Bia', 'commissionPercent': 10, 'active': true},
        ]);
      case '/api/salon/plan':
        return _json({
          'status': 'TRIAL', 'daysLeft': 11,
          'professionals': {'used': 1, 'max': 2}, 'services': {'used': 1, 'max': 10}, 'customers': {'used': 1, 'max': 50},
        });
      default:
        return _json(<Object>[]);
    }
  });
  final session = Session(httpClient: client);
  await session.restore();
  return session;
}

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  for (final (name, width, scale) in [('agenda_360', 360.0, 1.0), ('agenda_360_fonte_grande', 360.0, 1.4), ('agenda_411', 411.0, 1.0)]) {
    testWidgets('captura $name', (tester) async {
      final session = await _session();
      await shot(tester, AgendaScreen(session: session), name, width: width, height: 900, textScale: scale);
    }, skip: !shotsEnabled);
  }
}
