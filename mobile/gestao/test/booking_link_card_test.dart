import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salao_gestao/widgets/booking_link_card.dart';

void main() {
  testWidgets('mostra o link e "Copiar" põe o link na área de transferência', (tester) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: BookingLinkCard(link: 'https://salaomax.focodev.com.br/s/bella', compact: true)),
    ));
    expect(find.text('Link de agendamento'), findsOneWidget);
    expect(find.text('…/s/bella'), findsOneWidget);
    expect(find.byTooltip('Enviar pelo WhatsApp'), findsOneWidget);

    await tester.tap(find.byTooltip('Copiar link'));
    await tester.pump();
    expect(copied, 'https://salaomax.focodev.com.br/s/bella');
    expect(find.text('Link copiado!'), findsOneWidget);
  });

  testWidgets('versão completa (Ajustes) tem os botões com texto', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: BookingLinkCard(link: 'https://x.com/s/a')))));
    expect(find.text('Seu link de agendamento'), findsOneWidget);
    expect(find.text('Copiar'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);
  });
}
