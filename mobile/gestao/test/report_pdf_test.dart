import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salao_core/salao_core.dart';
import 'package:salao_gestao/report_pdf.dart';

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  test('gera o PDF do relatório com todas as seções', () async {
    final summary = Summary({
      'totalRevenue': 1500, 'servicesRevenue': 1200, 'productSalesRevenue': 300, 'totalCosts': 900, 'profit': 600,
      'servicesProfit': 700, 'productsProfit': 100, 'operatingProfit': 800, 'expenses': 200, 'commissions': 300,
      'serviceMaterialCost': 50, 'productsUsedCost': 20, 'productsSoldCost': 80, 'averageTicket': 75,
      'fixedExpenses': 150, 'variableExpenses': 50,
      'fixedByCategory': {'Aluguel': 150}, 'variableByCategory': {'Cortesias (café, água, lanches)': 50},
      'byProfessional': [
        {'name': 'Ana Souza', 'count': 10, 'revenue': 800, 'commission': 200, 'avgRealMinutes': null},
      ],
      'byService': [
        {'name': 'Corte', 'count': 10, 'revenue': 800, 'commission': 0, 'avgRealMinutes': null},
      ],
      'lowStock': [],
      'rework': {
        'count': 1, 'materialCost': 8, 'productsCost': 10, 'totalCost': 18,
        'items': [
          {'appointmentId': 1, 'startAt': '2026-10-05T10:00:00', 'customer': 'Rita', 'service': 'Escova', 'professional': 'Ana', 'cost': 18},
        ],
      },
      'products': [
        {
          'name': 'Esmalte', 'unit': 'un', 'costPrice': 10, 'salePrice': 15, 'soldQuantity': 2, 'salesProfit': 10,
          'usedQuantity': 1, 'stock': 7, 'stockValue': 70, 'lowStock': false,
        },
      ],
      'promotions': {'appointments': 2, 'discounts': 40, 'kitsSold': 1, 'kitsRevenue': 120, 'byPromotion': []},
    });
    const counts = {
      'total': 12, 'scheduled': 2, 'done': 7, 'canceled': 2, 'noShow': 1, 'rework': 1, 'online': 4,
      'newCustomers': 3, 'returningCustomers': 5, 'uniqueCustomers': 9,
    };
    final dash = AttendanceDashboard.fromJson({
      'totals': counts,
      'previous': counts,
      'byProfessional': [
        {'name': 'Ana Souza', 'total': 12, 'done': 7, 'canceled': 2, 'noShow': 1, 'rework': 1, 'scheduled': 2},
      ],
      'series': [],
    });

    final bytes = await buildReportPdf(
      salonName: 'Studio Bella',
      from: DateTime(2026, 10, 1),
      to: DateTime(2026, 10, 31),
      summary: summary,
      attendance: dash,
      generatedAt: DateTime(2026, 10, 22),
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(2000));
  });
}
