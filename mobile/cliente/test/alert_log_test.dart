import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:salao_cliente/alert_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final now = DateTime(2026, 11, 9, 12);

  test('guarda os avisos, o mais novo primeiro, sem repetir a mesma chave', () async {
    await AlertLog.add(key: 'a', title: 'A', body: 'x', kind: 'booking', now: now.subtract(const Duration(hours: 2)));
    await AlertLog.add(key: 'b', title: 'B', body: 'y', kind: 'promo', now: now);
    await AlertLog.add(key: 'a', title: 'A de novo', body: 'x', kind: 'booking', now: now);
    final all = await AlertLog.all();
    expect(all.map((i) => i.id), ['b', 'a']);
    expect(await AlertLog.unread(), 2);
  });

  test('marcar como lidos e apagar: só o lido sai', () async {
    await AlertLog.add(key: 'a', title: 'A', body: '', kind: 'booking', now: now);
    await AlertLog.add(key: 'b', title: 'B', body: '', kind: 'promo', now: now);
    expect(await AlertLog.delete('a'), isFalse); // ainda não lido
    await AlertLog.markAllRead();
    expect(await AlertLog.unread(), 0);
    expect(await AlertLog.delete('a'), isTrue);
    expect(await AlertLog.delete('a'), isFalse);
    await AlertLog.add(key: 'c', title: 'C', body: '', kind: 'promo', now: now);
    expect(await AlertLog.clearRead(), 1); // só o B; o C é novo
    expect((await AlertLog.all()).map((i) => i.id), ['c']);
  });

  test('limpeza automática: lido há mais de 30 dias e qualquer um com mais de 90 saem', () async {
    await AlertLog.add(key: 'lido-velho', title: '', body: '', kind: 'booking', now: now.subtract(const Duration(days: 40)));
    await AlertLog.add(key: 'novo-velho', title: '', body: '', kind: 'booking', now: now.subtract(const Duration(days: 100)));
    await AlertLog.add(key: 'novo-40', title: '', body: '', kind: 'booking', now: now.subtract(const Duration(days: 40)));
    await AlertLog.add(key: 'lido-recente', title: '', body: '', kind: 'booking', now: now.subtract(const Duration(days: 2)));
    // marca como lidos só dois deles
    final all = await AlertLog.all();
    SharedPreferences.setMockInitialValues({
      'alerts.log': [
        for (final i in all) jsonEncode((i.id == 'lido-velho' || i.id == 'lido-recente' ? i.asRead() : i).toJson()),
      ],
    });
    expect(await AlertLog.prune(now: now), 2); // lido-velho (lido há 40 dias) e novo-velho (100 dias)
    expect((await AlertLog.all()).map((i) => i.id).toSet(), {'novo-40', 'lido-recente'});
  });
}
