import 'package:flutter_test/flutter_test.dart';
import 'package:salao_core/salao_core.dart';

void main() {
  test('simulação de preço usa custo direto, comissão e taxas', () {
    final p = ServicePricing.fromJson({
      'serviceId': 1, 'name': 'Corte', 'plannedMinutes': 60, 'realAverageMinutes': null,
      'currentPrice': 100, 'materialCost': 10, 'fixedCostShare': 10, 'directCost': 20, 'variablePercent': 44,
      'breakEvenPrice': 35.72, 'suggestedPrice': 60, 'currentProfit': 36, 'currentMarginPercent': 36,
      'profitPerHour': 36, 'health': 'HEALTHY',
    });
    final s = p.simulate(100);
    expect(s.profit, closeTo(36, 0.001));
    expect(s.margin, closeTo(36, 0.001));
    expect(p.simulate(30).profit, lessThan(0));
    expect(p.health, PricingHealth.healthy);
  });
}
