import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salao_core/salao_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => Brand.palette = BrandPalette.rosa);

  test('escolher um tema muda as cores da marca e guarda a escolha', () async {
    SharedPreferences.setMockInitialValues({});
    expect(Brand.rose, BrandPalette.rosa.rose);
    var avisos = 0;
    ThemeController.instance.addListener(() => avisos++);
    await ThemeController.instance.select(BrandPalette.azul);
    expect(Brand.rose, BrandPalette.azul.rose);
    expect(Brand.gradient.colors, [BrandPalette.azul.pink, BrandPalette.azul.rose, BrandPalette.azul.violet]);
    expect(AppTheme.light().colorScheme.primary, BrandPalette.azul.rose);
    expect(avisos, 1);

    Brand.palette = BrandPalette.rosa;
    await ThemeController.instance.load();
    expect(Brand.palette.id, 'azul');
  });

  test('tema desconhecido volta para o rosa', () {
    expect(BrandPalette.byId('xyz').id, 'rosa');
  });

  testWidgets('trocar o tema repinta telas que usam Brand direto', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ThemedApp(
      builder: (_) => MaterialApp(home: Builder(builder: (_) => ColoredBox(key: const Key('c'), color: Brand.rose))),
    ));
    expect(tester.widget<ColoredBox>(find.byKey(const Key('c'))).color, BrandPalette.rosa.rose);
    await ThemeController.instance.select(BrandPalette.verde);
    await tester.pumpAndSettle();
    expect(tester.widget<ColoredBox>(find.byKey(const Key('c'))).color, BrandPalette.verde.rose);
  });
}
