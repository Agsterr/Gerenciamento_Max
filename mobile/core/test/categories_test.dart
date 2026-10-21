import 'package:flutter_test/flutter_test.dart';
import 'package:salao_core/salao_core.dart';

void main() {
  specialtyTests();
  PublicService s(int id, String? category, [List<int> pros = const []]) =>
      PublicService(id: id, name: 's$id', durationMinutes: 30, price: 10, category: category, professionalIds: pros);

  test('agrupa por categoria e deixa "Outros" por último', () {
    final groups = groupByCategory([s(1, null), s(2, 'Unhas'), s(3, 'Cabelo'), s(4, 'Unhas')], (x) => x.category);
    expect(groups.keys.toList(), ['Unhas', 'Cabelo', 'Outros']);
    expect(groups['Unhas']!.map((x) => x.id), [2, 4]);
  });

  test('serviço sem profissionais marcados é de qualquer um; com marcados, só deles', () {
    expect(s(1, null).doneBy(7), isTrue);
    expect(s(2, 'Unhas', [3]).doneBy(3), isTrue);
    expect(s(2, 'Unhas', [3]).doneBy(7), isFalse);
  });

  test('lê categoria e profissionais do JSON, tolerando servidor antigo', () {
    final novo = PublicService.fromJson({'id': 1, 'name': 'Esmalte', 'durationMinutes': 60, 'price': 40, 'category': 'Unhas', 'professionalIds': [3]});
    expect(novo.category, 'Unhas');
    expect(novo.professionalIds, [3]);
    final antigo = PublicService.fromJson({'id': 1, 'name': 'Corte', 'durationMinutes': 60, 'price': 40});
    expect(antigo.category, isNull);
    expect(antigo.professionalIds, isEmpty);
  });
}

void specialtyTests() {
  group('especialidade do profissional', () {
    const nina = Professional(id: 2, name: 'Nina', commissionPercent: 30, active: true, categories: ['Unhas']);
    const bia = Professional(id: 1, name: 'Bia', commissionPercent: 30, active: true);
    ServiceItem service(String? category, [List<int> ids = const []]) => ServiceItem(
        id: 1, name: 's', durationMinutes: 30, price: 10, cost: 0, active: true, category: category, professionalIds: ids);

    test('sem lista no serviço, vale a categoria do profissional', () {
      expect(service('Unhas').doneBy(nina), isTrue);
      expect(service('unhas').doneBy(nina), isTrue);
      expect(service('Cabelo').doneBy(nina), isFalse);
      expect(service('Cabelo').doneBy(bia), isTrue); // sem especialidade faz tudo
      expect(service(null).doneBy(nina), isTrue); // sem categoria qualquer um faz
    });

    test('lista do serviço manda sobre a especialidade', () {
      expect(service('Unhas', [1]).doneBy(nina), isFalse);
      expect(service('Unhas', [1]).doneBy(bia), isTrue);
    });
  });
}
