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
    expect(find.text('Seu link de agendamento'), findsOneWidget);
    expect(find.text('https://salaomax.focodev.com.br/s/bella'), findsOneWidget);
    expect(find.text('WhatsApp'), findsOneWidget);

    await tester.tap(find.text('Copiar'));
    await tester.pump();
    expect(copied, 'https://salaomax.focodev.com.br/s/bella');
    expect(find.text('Link copiado!'), findsOneWidget);
  });
}
