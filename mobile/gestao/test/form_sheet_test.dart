import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salao_gestao/widgets/form_sheet.dart';

void main() {
  testWidgets('botão Salvar fica acima da barra de navegação do Android', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 3;
    // barra de navegação de 144 px (48 dp) desenhada sobre o app (edge-to-edge)
    tester.view.padding = const FakeViewPadding(bottom: 144, top: 100);
    tester.view.viewPadding = const FakeViewPadding(bottom: 144, top: 100);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showFormSheet(
            context,
            title: 'Novo serviço',
            fields: const [FieldSpec('name', 'Nome', required: true), FieldSpec('price', 'Preço (R\$)', kind: FieldKind.decimal)],
            initial: const {},
            onSave: (_) async {},
          ),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    final screenBottom = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final buttonBottom = tester.getBottomLeft(find.text('Salvar')).dy;
    expect(buttonBottom, lessThanOrEqualTo(screenBottom - 48), reason: 'Salvar não pode ficar sob a barra de navegação');
  });
}
