import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:salao_core/salao_core.dart';

http.Response _json(Object body) => http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

/// API de mentira com [total] itens "Item 0..N" e busca por texto simples.
ApiClient _api(int total, {List<Uri>? seen, Map<String, Completer<void>>? gate}) {
  return ApiClient(
    baseUrl: 'http://api',
    httpClient: MockClient((req) async {
      seen?.add(req.url);
      final q = req.url.queryParameters['q'] ?? '';
      final page = int.parse(req.url.queryParameters['page']!);
      final size = int.parse(req.url.queryParameters['size']!);
      await gate?[q]?.future;
      final all = [for (var i = 0; i < total; i++) 'Item $i'].where((s) => s.contains(q)).toList();
      final from = page * size;
      final slice = all.skip(from).take(size).toList();
      return _json({'items': slice, 'page': page, 'size': size, 'total': all.length, 'hasMore': from + slice.length < all.length});
    }),
  );
}

PagedController<String> _controller(ApiClient api, {Map<String, String> filters = const {}}) => PagedController<String>(
      api: api,
      path: '/api/things',
      parse: (j) => j as String,
      pageSize: 10,
      filters: filters,
      debounce: const Duration(milliseconds: 10),
    );

void main() {
  test('carrega a primeira página e as seguintes até o fim', () async {
    final c = _controller(_api(25));
    await c.refresh();
    expect(c.items, hasLength(10));
    expect(c.total, 25);
    expect(c.hasMore, isTrue);

    await c.loadMore();
    await c.loadMore();
    expect(c.items, hasLength(25));
    expect(c.hasMore, isFalse);

    // sem mais páginas: não faz nova chamada
    final seen = <Uri>[];
    final done = _controller(_api(3, seen: seen));
    await done.refresh();
    await done.loadMore();
    expect(seen, hasLength(1));
    c.dispose();
    done.dispose();
  });

  test('busca recomeça do começo, com filtros na URL', () async {
    final seen = <Uri>[];
    final c = _controller(_api(25, seen: seen), filters: {'status': 'DONE'});
    await c.refresh();
    await c.loadMore();
    c.search('Item 2');
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(c.items.every((s) => s.contains('Item 2')), isTrue);
    expect(c.items, hasLength(c.total));
    final last = seen.last.queryParameters;
    expect(last['q'], 'Item 2');
    expect(last['status'], 'DONE');
    expect(last['page'], '0');
    expect(last['size'], '10');

    c.setFilter('status', null);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(seen.last.queryParameters.containsKey('status'), isFalse);
    c.dispose();
  });

  test('resposta de busca antiga que chega atrasada é descartada', () async {
    final gate = {'Item 1': Completer<void>()};
    final c = _controller(_api(30, gate: gate));
    await c.refresh();

    c.search('Item 1'); // fica presa
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(c.loadingFirst, isTrue);

    c.search('Item 2'); // mais nova, responde logo
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(c.items.every((s) => s.contains('Item 2')), isTrue);

    gate['Item 1']!.complete(); // a antiga chega depois
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(c.items.every((s) => s.contains('Item 2')), isTrue);
    c.dispose();
  });

  test('erro vira mensagem e a lista continua', () async {
    final api = ApiClient(baseUrl: 'http://api', httpClient: MockClient((_) async => http.Response('{"detail":"Falhou"}', 500)));
    final c = _controller(api);
    await c.refresh();
    expect(c.error, 'Falhou');
    expect(c.loaded, isFalse);
    c.dispose();
  });
}
