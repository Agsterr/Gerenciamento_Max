import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salao_gestao/widgets/contact_picker_button.dart';
import 'package:salao_gestao/widgets/form_sheet.dart';

void main() {
  group('normalizeBrazilianPhone', () {
    test('tira o +55 e a máscara do celular e do fixo', () {
      expect(normalizeBrazilianPhone('+55 (11) 98888-7777'), '(11) 98888-7777');
      expect(normalizeBrazilianPhone('5511988887777'), '(11) 98888-7777');
      expect(normalizeBrazilianPhone('11 98888 7777'), '(11) 98888-7777');
      expect(normalizeBrazilianPhone('(16) 3333-4444'), '(16) 3333-4444');
    });

    test('número que não parece brasileiro fica como veio', () {
      expect(normalizeBrazilianPhone('+1 415 555 0100'), '+1 415 555 0100');
      expect(normalizeBrazilianPhone('98888'), '98888');
    });
  });

  Future<void> openForm(WidgetTester tester, Future<PickedContact?> Function() pick) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showFormSheet(
            context,
            title: 'Novo cliente',
            fields: const [FieldSpec('name', 'Nome', required: true), FieldSpec('phone', 'Telefone (WhatsApp)', kind: FieldKind.phone, required: true)],
            initial: const {},
            aboveFields: (c) => ContactPickerButton(controllers: c, pick: pick),
            onSave: (_) async {},
          ),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester, String label) =>
      tester.widget<TextFormField>(find.widgetWithText(TextFormField, label)).controller!.text;

  testWidgets('importar da agenda preenche nome e telefone do formulário', (tester) async {
    await openForm(tester, () async => (name: 'Camila Teste', phone: '+55 11 99988-7766'));
    await tester.tap(find.text('Importar da agenda do celular'));
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'Nome'), 'Camila Teste');
    expect(fieldText(tester, 'Telefone (WhatsApp)'), '(11) 99988-7766');
  });

  testWidgets('fechar o seletor sem escolher não mexe no que já foi digitado', (tester) async {
    await openForm(tester, () async => null);
    await tester.enterText(find.widgetWithText(TextFormField, 'Nome'), 'Maria');
    await tester.tap(find.text('Importar da agenda do celular'));
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'Nome'), 'Maria');
  });

  testWidgets('contato sem telefone avisa e mantém o nome', (tester) async {
    await openForm(tester, () async => (name: 'Fulano', phone: null));
    await tester.tap(find.text('Importar da agenda do celular'));
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'Nome'), 'Fulano');
    expect(find.textContaining('não tem telefone'), findsOneWidget);
  });

  testWidgets('erro ao abrir a agenda mostra aviso em vez de quebrar', (tester) async {
    await openForm(tester, () async => throw Exception('sem agenda'));
    await tester.tap(find.text('Importar da agenda do celular'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Não foi possível abrir a agenda'), findsOneWidget);
  });
}
