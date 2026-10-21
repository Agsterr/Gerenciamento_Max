import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salao_gestao/screens/catalog_screen.dart';

void main() {
  Map<String, TextEditingController> form(String cost, String markup, String price) => {
        'costPrice': TextEditingController(text: cost),
        'markupPercent': TextEditingController(text: markup),
        'salePrice': TextEditingController(text: price),
      };

  test('custo + % que quero ganhar calcula o preço de venda', () {
    final f = form('20', '50', '0');
    productPricing('markupPercent', f);
    expect(f['salePrice']!.text, '30');
    f['costPrice']!.text = '10';
    productPricing('costPrice', f);
    expect(f['salePrice']!.text, '15');
  });

  test('preço digitado mostra quanto % dá em cima do custo', () {
    final f = form('20', '', '25');
    productPricing('salePrice', f);
    expect(f['markupPercent']!.text, '25');
  });

  test('sem % preenchida, mudar o custo não mexe no preço', () {
    final f = form('20', '', '33');
    productPricing('costPrice', f);
    expect(f['salePrice']!.text, '33');
  });
}
