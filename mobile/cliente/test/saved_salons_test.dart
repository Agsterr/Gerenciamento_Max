import 'package:flutter_test/flutter_test.dart';
import 'package:salao_cliente/booking_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('salões abertos pelo link ficam salvos, o mais recente primeiro, sem repetir', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await BookingStore.load();
    await store.rememberSalon('bella', 'Studio Bella');
    await store.rememberSalon('max', 'Max Hair');
    await store.rememberSalon('bella', 'Studio Bella');
    expect(store.salons.map((s) => s.slug), ['bella', 'max']);
  });

  test('salão de agendamento salvo também aparece em Meus salões', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await BookingStore.load();
    await store.rememberSalon('bella', 'Studio Bella');
    await store.add(const SavedBooking(slug: 'zen', token: 't1', salonName: 'Zen'));
    expect(store.salons.map((s) => s.slug), ['bella', 'zen']);
  });
}
