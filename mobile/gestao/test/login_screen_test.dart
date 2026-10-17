import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salao_gestao/screens/login_screen.dart';
import 'package:salao_gestao/session.dart';

void main() {
  testWidgets('alterna entre login e cadastro e valida campos', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: LoginScreen(session: Session())));

    expect(find.text('Entre na sua conta'), findsOneWidget);
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    expect(find.text('Obrigatório'), findsOneWidget);

    await tester.ensureVisible(find.text('Novo por aqui? Cadastre seu salão'));
    await tester.tap(find.text('Novo por aqui? Cadastre seu salão'));
    await tester.pumpAndSettle();
    expect(find.text('Cadastre seu salão'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Nome do salão'), 'Espaço Beleza Ágata');
    await tester.pump();
    expect(find.text('espaco-beleza-agata'), findsOneWidget);
  });

  testWidgets('senha com olhinho e confirmação no cadastro', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: LoginScreen(session: Session())));

    final senha = find.widgetWithText(TextFormField, 'Senha');
    await tester.enterText(senha, 'segredo123');
    EditableText field() => tester.widget<EditableText>(find.descendant(of: senha, matching: find.byType(EditableText)));
    expect(field().obscureText, isTrue);
    await tester.tap(find.byTooltip('Mostrar senha'));
    await tester.pump();
    expect(field().obscureText, isFalse);

    await tester.ensureVisible(find.text('Novo por aqui? Cadastre seu salão'));
    await tester.tap(find.text('Novo por aqui? Cadastre seu salão'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Confirme a senha'), 'outra-senha');
    await tester.ensureVisible(find.text('Criar salão'));
    await tester.tap(find.text('Criar salão'));
    await tester.pump();
    expect(find.text('As senhas não conferem'), findsOneWidget);
  });
}
