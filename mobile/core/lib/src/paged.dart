import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';
import 'theme.dart';
import 'widgets.dart';

/// Lista que cresce com o uso (clientes, serviços, agendamentos): busca no servidor, página a página.
///
/// A API devolve `{items, page, size, total, hasMore}`. Use [search] para o campo de busca (espera o
/// usuário parar de digitar), [setFilter] para filtros e [loadMore] quando a rolagem chegar perto do fim.
/// Resposta de uma busca antiga que chega depois de uma mais nova é descartada.
class PagedController<T> extends ChangeNotifier {
  PagedController({
    required this.api,
    required this.path,
    required this.parse,
    this.pageSize = 20,
    Map<String, String> filters = const {},
    this.debounce = const Duration(milliseconds: 350),
  }) : _filters = Map.of(filters);

  final ApiClient api;
  final String path;
  final T Function(Map<String, dynamic>) parse;
  final int pageSize;
  final Duration debounce;

  final Map<String, String> _filters;

  String query = '';
  List<T> items = const [];
  int total = 0;
  bool hasMore = false;

  /// Carregando a primeira página (nova busca ou atualização).
  bool loadingFirst = false;

  /// Carregando páginas seguintes.
  bool loadingMore = false;
  String? error;

  /// Já terminou ao menos uma carga com sucesso.
  bool loaded = false;

  int _page = 0;
  int _generation = 0;
  Timer? _timer;

  bool get loading => loadingFirst || loadingMore;
  bool get isEmpty => loaded && items.isEmpty;

  /// Valor de um filtro (ex.: `status`), ou nulo se não houver.
  String? filter(String key) => _filters[key];

  Future<void> refresh() => _fetch(reset: true);

  Future<void> loadMore() {
    if (loading || !hasMore) return Future.value();
    return _fetch(reset: false);
  }

  /// Busca por texto (nome, telefone...). Espera [debounce] depois da última tecla.
  void search(String text) {
    final q = text.trim();
    if (q == query) return;
    query = q;
    _timer?.cancel();
    _timer = Timer(debounce, refresh);
  }

  /// Define (ou remove, com nulo) um filtro e recarrega do começo.
  void setFilter(String key, String? value) {
    if (_filters[key] == value) return;
    if (value == null) {
      _filters.remove(key);
    } else {
      _filters[key] = value;
    }
    _timer?.cancel();
    refresh();
  }

  String _url(int page) {
    final params = {
      ..._filters,
      if (query.isNotEmpty) 'q': query,
      'page': '$page',
      'size': '$pageSize',
    };
    final qs = params.entries.map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}').join('&');
    return '$path${path.contains('?') ? '&' : '?'}$qs';
  }

  Future<void> _fetch({required bool reset}) async {
    final generation = ++_generation;
    error = null;
    if (reset) {
      loadingFirst = true;
      loadingMore = false;
    } else {
      loadingMore = true;
    }
    notifyListeners();
    try {
      final page = reset ? 0 : _page + 1;
      final json = await api.get(_url(page)) as Map<String, dynamic>;
      if (generation != _generation) return; // chegou depois de uma busca mais nova
      final fresh = (json['items'] as List).map((e) => parse(e as Map<String, dynamic>)).toList();
      items = reset ? fresh : [...items, ...fresh];
      _page = json['page'] as int;
      total = json['total'] as int;
      hasMore = json['hasMore'] as bool;
      loaded = true;
    } catch (e) {
      if (generation != _generation) return;
      error = e.toString();
    } finally {
      if (generation == _generation) {
        loadingFirst = false;
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _generation++; // nada de notifyListeners depois de descartado
    super.dispose();
  }
}

/// Pede a próxima página quando a rolagem chega perto do fim. Use em um [NotificationListener].
bool loadMoreOnScroll(ScrollNotification n, PagedController<dynamic> c, {double threshold = 400}) {
  if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < threshold) c.loadMore();
  return false;
}

/// Rodapé da lista: carregando, "Carregar mais" (se a rolagem não bastar), erro e fim da lista.
class PagedFooter extends StatelessWidget {
  const PagedFooter({super.key, required this.controller, this.noun = 'itens'});

  final PagedController<dynamic> controller;

  /// Plural para o texto do fim da lista ("clientes", "agendamentos"...).
  final String noun;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (!c.loaded) return const SizedBox.shrink();
    if (c.error != null && c.items.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Text(c.error!, textAlign: TextAlign.center),
          TextButton(onPressed: c.loadMore, child: const Text('Tentar de novo')),
        ]),
      );
    }
    if (c.loadingMore) {
      return const Padding(padding: EdgeInsets.all(16), child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5))));
    }
    if (c.hasMore) {
      return Center(child: TextButton(onPressed: c.loadMore, child: const Text('Carregar mais')));
    }
    if (c.items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text('Fim da lista · ${c.total} $noun',
          textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Brand.muted)),
    );
  }
}

/// Campo de busca no estilo dos cabeçalhos (fundo claro, sem borda), ligado a um [PagedController].
class PagedSearchField extends StatelessWidget {
  const PagedSearchField({super.key, required this.controller, this.hint = 'Buscar'});

  final PagedController<dynamic> controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border() => OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none);
    return TextField(
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        prefixIcon: const Icon(Icons.search_rounded, color: Brand.rose),
        border: border(),
        enabledBorder: border(),
        focusedBorder: border(),
      ),
      onChanged: controller.search,
    );
  }
}

/// Estado da lista: carregando, erro (com "tentar de novo") ou vazia. Nulo = há itens para mostrar.
Widget? pagedStateOrNull(PagedController<dynamic> c, {required Widget empty}) {
  if (c.error != null && c.items.isEmpty) return ErrorRetry(message: c.error!, onRetry: c.refresh);
  if (c.loadingFirst && c.items.isEmpty) return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
  if (c.isEmpty) return empty;
  return null;
}
