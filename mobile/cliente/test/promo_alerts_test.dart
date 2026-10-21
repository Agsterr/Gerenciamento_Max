import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_cliente/booking_store.dart';
import 'package:salao_cliente/promo_alerts.dart';
import 'package:salao_core/salao_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  test('promoções dos salões salvos aparecem e só avisam uma vez', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await BookingStore.load();
    await store.rememberSalon('bella', 'Studio Bella');
    final api = ApiClient(
      baseUrl: 'http://api',
      httpClient: MockClient((req) async => http.Response(
          jsonEncode({
            'name': 'Studio Bella',
            'slug': 'bella',
            'workDays': '1,2,3',
            'services': [
              {
                'id': 1, 'name': 'Corte', 'durationMinutes': 60, 'price': 100, 'promoPrice': 80, 'promoName': 'Semana',
                'promoPercent': 20, 'promoStartsOn': '2026-01-01', 'promoEndsOn': '2026-01-31',
              },
            ],
            'professionals': [],
            'promotions': [
              {'id': 9, 'name': 'Semana', 'discountPercent': 20, 'startsOn': '2026-01-01', 'endsOn': '2026-01-31', 'serviceIds': [1]},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'})),
    );

    final found = await checkPromotions(api, store);
    expect(found.single.promotion.headline, 'Semana: 20% de desconto');
    expect(store.seenPromotions, {'bella:9'});
    expect((await checkPromotions(api, store)).length, 1); // continua aparecendo, sem novo aviso

    final s = PublicService.fromJson({
      'id': 1, 'name': 'Corte', 'durationMinutes': 60, 'price': 100, 'promoPrice': 80,
      'promoStartsOn': '2026-01-01', 'promoEndsOn': '2026-01-31',
    });
    expect(s.promoPriceOn(DateTime(2026, 1, 15)), 80);
    expect(s.promoPriceOn(DateTime(2026, 2, 1)), isNull);
  });
}
