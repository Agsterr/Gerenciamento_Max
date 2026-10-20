import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salao_core/salao_core.dart';

void main() {
  group('modelos de lembrete e portfólio', () {
    test('Booking lê confirmable e reminderDays (e aceita API antiga sem eles)', () {
      final base = {
        'token': 't',
        'startAt': '2026-10-21T14:00:00',
        'endAt': '2026-10-21T15:00:00',
        'status': 'SCHEDULED',
        'serviceName': 'Corte',
        'professionalName': 'Ana',
        'price': 80,
        'customerName': 'Maria',
        'cancelable': true,
      };
      final old = Booking.fromJson(base);
      expect(old.confirmable, isFalse);
      expect(old.reminderDays, isEmpty);
      final b = Booking.fromJson({...base, 'confirmable': true, 'reminderDays': [1, 2]});
      expect(b.confirmable, isTrue);
      expect(b.reminderDays, [1, 2]);
    });

    test('Salon manda reminderMode no PUT', () {
      final s = Salon.fromJson({
        'name': 'Bella',
        'slug': 'bella',
        'hours': <Object>[],
        'slotMinutes': 30,
        'reminderMode': 'BOTH',
      });
      expect(s.reminderMode, ReminderMode.both);
      s.reminderMode = ReminderMode.off;
      expect(s.toJson()['reminderMode'], 'OFF');
      expect(ReminderMode.parse(null), ReminderMode.oneDay);
    });

    test('regras de lembrete do profissional', () {
      const day = StaffReminderRule.daysBefore(1, '19:00');
      const rel = StaffReminderRule.minutesBefore(120);
      expect(day.label, '1 dia antes, às 19:00');
      expect(rel.label, '2 h antes');
      expect(const StaffReminderRule.minutesBefore(90).label, '1 h 30 min antes');
      expect(const StaffReminderRule.daysBefore(0, '08:00').label, 'No dia, às 08:00');
      final s = StaffReminderSettings.fromJson({
        'professionalId': 3,
        'rules': [
          {'id': 1, 'daysBefore': 1, 'atTime': '19:00:00', 'minutesBefore': null},
          {'id': 2, 'daysBefore': null, 'atTime': null, 'minutesBefore': 30},
        ],
      });
      expect(s.rules.first.atTime, '19:00');
      expect(s.toJson()['rules'], [
        {'daysBefore': 1, 'atTime': '19:00', 'minutesBefore': null},
        {'daysBefore': null, 'atTime': null, 'minutesBefore': 30},
      ]);
    });

    test('Photo', () {
      final p = Photo.fromJson({
        'id': 5,
        'url': 'https://pub/x.jpg',
        'thumbUrl': 'https://pub/x_t.jpg',
        'caption': 'Luzes',
        'width': 1600,
        'height': 1067,
        'serviceId': 2,
        'serviceName': 'Mechas',
        'professionalId': null,
        'professionalName': null,
      });
      expect(p.serviceName, 'Mechas');
      expect(p.professionalName, isNull);
    });
  });

  group('LocalReminders', () {
    test('id estável e positivo para a mesma chave', () {
      final a = LocalReminders.idFor('staff:1:2:3:2026-10-21T14:00');
      expect(a, LocalReminders.idFor('staff:1:2:3:2026-10-21T14:00'));
      expect(a, isNot(LocalReminders.idFor('staff:1:2:4:2026-10-21T14:00')));
      expect(a, greaterThanOrEqualTo(0));
      expect(a, lessThan(1 << 31));
    });

    test('payload separado por grupo', () {
      expect(LocalReminders.payloadOf('confirmar|bella/tok', 'confirmar'), 'bella/tok');
      expect(LocalReminders.payloadOf('atendimento|12', 'confirmar'), isNull);
      expect(LocalReminders.payloadOf(null, 'confirmar'), isNull);
    });

    test('fora do celular não agenda nada (sem erro)', () async {
      await LocalReminders.instance.replace('x', [
        LocalReminder(key: 'k', at: DateTime.now().add(const Duration(days: 1)), title: 't', body: 'b', payload: 'p'),
      ]);
      expect(LocalReminders.instance.ready, isFalse);
    });
  });

  test('upload envia multipart com o arquivo', () async {
    http.BaseRequest? sent;
    String? body;
    final api = ApiClient(
      baseUrl: 'http://api',
      token: () => 'jwt',
      httpClient: MockClient((req) async {
        sent = req;
        body = utf8.decode(req.bodyBytes, allowMalformed: true);
        return http.Response(jsonEncode({'id': 1}), 201, headers: {'content-type': 'application/json'});
      }),
    );
    final res = await api.upload('/api/portfolio', bytes: [1, 2, 3], filename: 'foto.jpg', fields: {'caption': 'Oi'});
    expect(res, {'id': 1});
    expect(sent!.headers['content-type'], startsWith('multipart/form-data'));
    expect(sent!.headers['Authorization'], 'Bearer jwt');
    expect(body, contains('filename="foto.jpg"'));
    expect(body, contains('name="caption"'));
  });
}
