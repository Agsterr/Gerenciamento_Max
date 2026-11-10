import 'package:flutter_test/flutter_test.dart';
import 'package:salao_core/salao_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('guarda e lê JSON; chave ausente ou corrompida devolve null', () async {
    SharedPreferences.setMockInitialValues({'cache.ruim': '{não é json'});
    expect(await LocalCache.read('nada'), isNull);
    expect(await LocalCache.read('ruim'), isNull);
    await LocalCache.write('shop:x:catalog', {'available': true, 'vendors': [1, 2]});
    expect(await LocalCache.read('shop:x:catalog'), {'available': true, 'vendors': [1, 2]});
    await LocalCache.remove('shop:x:catalog');
    expect(await LocalCache.read('shop:x:catalog'), isNull);
  });
}
