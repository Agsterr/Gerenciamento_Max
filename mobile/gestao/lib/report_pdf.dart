import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:salao_core/salao_core.dart';

/// Texto sem espaço não separável nem traços longos: a fonte padrão do PDF não tem esses caracteres.
String _t(String s) => s.replaceAll(' ', ' ').replaceAll('–', '-').replaceAll('−', '-');

String _money(double v) => _t(formatMoney(v));

/// Relatório do período em PDF (A4): resumo, lucros, atendimentos, equipe, serviços, produtos,
/// despesas fixas e variáveis, refações e promoções.
Future<Uint8List> buildReportPdf({
  required String salonName,
  required DateTime from,
  required DateTime to,
  required Summary summary,
  required AttendanceDashboard attendance,
  DateTime? generatedAt,
}) async {
  final s = summary;
  final a = attendance.totals;
  final doc = pw.Document(title: 'Relatorio $salonName', author: 'Salao Max');
  const ink = PdfColor.fromInt(0xFF22104D);
  const muted = PdfColor.fromInt(0xFF6B6477);

  pw.Widget title(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(_t(text), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: ink)),
      );

  pw.Widget line(String label, String value, {bool bold = false, PdfColor? color}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(_t(label), style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(_t(value), style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
        ]),
      );

  pw.Widget table(List<String> headers, List<List<String>> rows, {Map<int, pw.TableColumnWidth>? widths}) => pw.TableHelper.fromTextArray(
        headers: [for (final h in headers) _t(h)],
        data: [for (final r in rows) [for (final c in r) _t(c)]],
        headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: ink),
        cellStyle: const pw.TextStyle(fontSize: 9),
        cellAlignments: {for (var i = 1; i < headers.length; i++) i: pw.Alignment.centerRight},
        headerAlignments: {for (var i = 1; i < headers.length; i++) i: pw.Alignment.centerRight},
        rowDecoration: null,
        oddRowDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF6EEF3)),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        border: null,
        columnWidths: widths,
      );

  Map<String, double> cat(String key) => summary.byCategory(key);
  final rework = summary.rework;
  final promo = (summary.json['promotions'] as Map<String, dynamic>?) ?? const {};
  final products = summary.products;
  double n(Map<String, dynamic> m, String k) => (m[k] as num? ?? 0).toDouble();

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
    footer: (ctx) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('Pagina ${ctx.pageNumber} de ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: muted)),
    ),
    build: (ctx) => [
      pw.Container(
        padding: const pw.EdgeInsets.all(14),
        decoration: const pw.BoxDecoration(color: ink, borderRadius: pw.BorderRadius.all(pw.Radius.circular(10))),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(_t(salonName), style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          pw.SizedBox(height: 3),
          pw.Text('Relatorio de ${formatDate(from)} a ${formatDate(to)}', style: const pw.TextStyle(fontSize: 11, color: PdfColors.white)),
          pw.Text('Gerado em ${formatDate(generatedAt ?? DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey300)),
        ]),
      ),
      title('Resumo'),
      line('Receita total', _money(s.money('totalRevenue')), bold: true),
      line('   Servicos', _money(s.money('servicesRevenue'))),
      line('   Venda de produtos', _money(s.money('productSalesRevenue'))),
      line('Custos e despesas', '- ${_money(s.money('totalCosts'))}'),
      line('Lucro liquido', _money(s.money('profit')), bold: true, color: s.money('profit') < 0 ? PdfColors.red800 : PdfColors.green800),
      title('Lucros separados'),
      line('Lucro dos servicos (receita - comissoes - material - produtos usados)', _money(s.money('servicesProfit'))),
      line('Lucro dos produtos (vendas - preco pago - perdas)', _money(s.money('productsProfit'))),
      line('Lucro antes das despesas', _money(s.money('operatingProfit')), bold: true),
      line('Despesas (fixas + variaveis)', '- ${_money(s.money('expenses'))}'),
      title('Custos dos atendimentos'),
      line('Comissoes', _money(s.money('commissions'))),
      line('Material dos servicos', _money(s.money('serviceMaterialCost'))),
      line('Produtos usados e perdas', _money(s.money('productsUsedCost'))),
      line('Custo dos produtos vendidos', _money(s.money('productsSoldCost'))),
      title('Atendimentos'),
      table(['Concluidos', 'Cancelados', 'Faltas', 'Por fazer', 'Refacoes', 'Total'],
          [['${a.done}', '${a.canceled}', '${a.noShow}', '${a.scheduled}', '${a.rework}', '${a.total}']]),
      pw.SizedBox(height: 4),
      line('Taxa de cancelamento', '${a.cancelRate.toStringAsFixed(1).replaceAll('.', ',')}%'),
      line('Clientes atendidos / que voltaram / novos', '${a.uniqueCustomers} / ${a.returningCustomers} / ${a.newCustomers}'),
      line('Agendados pelo app', '${a.online}'),
      line('Ticket medio', _money(s.money('averageTicket'))),
      if (attendance.byProfessional.isNotEmpty) ...[
        title('Atendimentos por profissional'),
        table(['Profissional', 'Concl.', 'Canc.', 'Faltas', 'Refac.', 'Por fazer'], [
          for (final p in attendance.byProfessional)
            [p.name, '${p.done}', '${p.canceled}', '${p.noShow}', '${p.rework}', '${p.scheduled}'],
        ], widths: {0: const pw.FlexColumnWidth(3)}),
      ],
      if (s.byProfessional.isNotEmpty) ...[
        title('Receita e comissao por profissional'),
        table(['Profissional', 'Atend.', 'Receita', 'Comissao'], [
          for (final r in s.byProfessional) [r.name, '${r.count}', _money(r.revenue), _money(r.commission)],
        ], widths: {0: const pw.FlexColumnWidth(3)}),
      ],
      if (s.byService.isNotEmpty) ...[
        title('Servicos'),
        table(['Servico', 'Qtd', 'Receita'], [
          for (final r in s.byService) [r.name, '${r.count}', _money(r.revenue)],
        ], widths: {0: const pw.FlexColumnWidth(3)}),
      ],
      title('Despesas fixas  (${_money(s.money('fixedExpenses'))})'),
      if (cat('fixedByCategory').isEmpty) pw.Text('Nenhuma no periodo.', style: const pw.TextStyle(fontSize: 10, color: muted)),
      for (final e in cat('fixedByCategory').entries) line(e.key, _money(e.value)),
      title('Despesas variaveis  (${_money(s.money('variableExpenses'))})'),
      if (cat('variableByCategory').isEmpty) pw.Text('Nenhuma no periodo.', style: const pw.TextStyle(fontSize: 10, color: muted)),
      for (final e in cat('variableByCategory').entries) line(e.key, _money(e.value)),
      if (products.isNotEmpty) ...[
        title('Produtos'),
        table(['Produto', 'Pago', 'Venda', 'Vendidos', 'Lucro', 'Usados', 'Estoque'], [
          for (final p in products)
            [
              p['name'] as String,
              _money(n(p, 'costPrice')),
              n(p, 'salePrice') > 0 ? _money(n(p, 'salePrice')) : '-',
              formatQuantity(n(p, 'soldQuantity')),
              _money(n(p, 'salesProfit')),
              formatQuantity(n(p, 'usedQuantity')),
              '${formatQuantity(n(p, 'stock'))} ${p['unit']}',
            ],
        ], widths: {0: const pw.FlexColumnWidth(3)}),
        pw.SizedBox(height: 3),
        line('Valor parado em estoque (preco pago)', _money(products.fold(0.0, (t, p) => t + n(p, 'stockValue')))),
      ],
      if ((rework['count'] as int? ?? 0) > 0) ...[
        title('Refacoes (cliente voltou e nao pagou)'),
        line('Quantidade', '${rework['count']}'),
        line('Custo total (material + produtos)', _money(n(rework, 'totalCost')), bold: true),
        for (final i in ((rework['items'] as List?) ?? const []).cast<Map<String, dynamic>>())
          line('${formatDate(DateTime.parse(i['startAt'] as String))} ${i['customer']} - ${i['service']}', _money(n(i, 'cost'))),
      ],
      if ((promo['appointments'] as int? ?? 0) > 0 || (promo['kitsSold'] as int? ?? 0) > 0) ...[
        title('Promocoes e pacotes'),
        line('Atendimentos com promocao', '${promo['appointments']}'),
        line('Descontos dados', _money(n(promo, 'discounts'))),
        line('Pacotes vendidos', '${promo['kitsSold']} (${_money(n(promo, 'kitsRevenue'))})'),
      ],
    ],
  ));
  return doc.save();
}
