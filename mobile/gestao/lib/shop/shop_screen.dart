import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../session.dart';
import 'purchases_screen.dart';
import 'shop_models.dart';

/// Loja dos vendedores do salão: produtos separados por vendedor, convites, carrinho e pedido (um por vendedor).
/// Abre com o que está guardado no aparelho e atualiza pela rede.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, required this.session, this.onChanged});

  final Session session;

  /// Avisa quem abriu (ex.: Ajustes) que convites/vendedores mudaram.
  final VoidCallback? onChanged;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  List<ShopVendor> _vendors = [];
  List<ShopInvite> _invites = [];
  bool _loaded = false;
  String? _error;
  int? _vendorFilter;
  String _filter = '';
  String _query = '';
  final Map<int, int> _cart = {};

  ApiClient get _api => widget.session.api;
  String get _key => 'shop:${widget.session.user.salonSlug}';

  @override
  void initState() {
    super.initState();
    _fromCache();
    _load();
  }

  Future<void> _fromCache() async {
    final catalog = await LocalCache.read('$_key:catalog');
    final invites = await LocalCache.read('$_key:invites');
    if (!mounted || _loaded) return;
    setState(() => _apply(catalog, invites));
  }

  void _apply(Object? catalog, Object? invites) {
    if (catalog is Map) {
      _vendors = [for (final v in (catalog['vendors'] as List? ?? const [])) ShopVendor.fromJson(v as Map<String, dynamic>)];
    }
    if (invites is List) {
      _invites = [for (final i in invites) ShopInvite.fromJson(i as Map<String, dynamic>)];
    }
  }

  Future<void> _load() async {
    try {
      final catalog = await _api.get('/api/shop/catalog');
      final invites = await _api.get('/api/shop/invites');
      await LocalCache.write('$_key:catalog', catalog);
      await LocalCache.write('$_key:invites', invites);
      if (!mounted) return;
      setState(() {
        _apply(catalog, invites);
        _loaded = true;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _vendors.isEmpty ? e.toString() : null);
    }
  }

  List<ShopProduct> get _all => [for (final v in _vendors) ...v.products];
  ShopVendor? _vendor(int id) => _vendors.where((v) => v.id == id).firstOrNull;

  List<ShopProduct> get _visible {
    final q = _query.trim().toLowerCase();
    return _all.where((p) {
      if (_vendorFilter != null && p.vendorId != _vendorFilter) return false;
      if (p.hidden) return false;
      if (q.isNotEmpty && !'${p.name} ${p.category ?? ''}'.toLowerCase().contains(q)) return false;
      if (_filter.isEmpty) return true;
      if (_filter.startsWith('cat:')) return p.category == _filter.substring(4);
      return p.tags.contains(_filter);
    }).toList();
  }

  Future<void> _act(Future<void> Function() fn) async {
    try {
      await fn();
      await _load();
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final lines = _all.where((p) => (_cart[p.id] ?? 0) > 0).toList();
    final total = lines.fold<int>(0, (s, p) => s + p.priceCents * _cart[p.id]!);
    final count = lines.fold<int>(0, (s, p) => s + _cart[p.id]!);
    final vendorsInCart = lines.map((p) => p.vendorId).toSet().length;
    final categories = {for (final v in _vendors) if (_vendorFilter == null || v.id == _vendorFilter) ...v.categories}.toList()..sort();
    final products = _visible;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loja dos vendedores'),
        actions: [
          IconButton(
            tooltip: 'Minhas compras',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PurchasesScreen(session: widget.session))),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            for (final i in _invites) _InviteCard(invite: i, onAccept: () => _act(() async {
                  await _api.post('/api/shop/invites/${i.id}/accept');
                }), onDecline: () => _act(() async {
                  await _api.post('/api/shop/invites/${i.id}/decline');
                })),
            if (!_loaded && _vendors.isEmpty && _error == null)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
            if (_loaded && _vendors.isEmpty && _invites.isEmpty)
              const EmptyState(icon: Icons.storefront_outlined, title: 'Nenhum vendedor ainda',
                  message: 'A loja aparece quando um vendedor convida o seu salão.'),
            if (_vendors.isNotEmpty) ...[
              Text(
                _vendors.length == 1
                    ? 'Produtos de ${_vendors.first.name}. O ganho é o que sobra para você vendendo pelo preço sugerido.'
                    : 'Produtos dos seus vendedores. Cada vendedor recebe um pedido separado.',
                style: text.bodyMedium?.copyWith(color: Brand.muted),
              ),
              for (final v in _vendors.where((v) => v.paused))
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _Notice('A loja de ${v.name} está pausada no momento. Fale com ele para voltar a fazer pedidos.'),
                ),
              if (_vendors.length > 1) ...[
                const SizedBox(height: 12),
                _ChipRow(
                  selected: _vendorFilter?.toString() ?? '',
                  options: [('', 'Todos os vendedores'), for (final v in _vendors) (v.id.toString(), v.name)],
                  onSelected: (k) => setState(() => _vendorFilter = k.isEmpty ? null : int.parse(k)),
                  strong: true,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Buscar produto'),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 10),
              _ChipRow(
                selected: _filter,
                options: [
                  ('', 'Todos'),
                  ('NOVO', 'Novos'),
                  ('PROMOCAO', 'Promoções'),
                  ('EQUIPAMENTO', 'Equipamentos'),
                  for (final c in categories) ('cat:$c', c),
                ],
                onSelected: (k) => setState(() => _filter = k),
              ),
              const SizedBox(height: 12),
              if (products.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Nenhum produto encontrado.'))),
              for (final p in products)
                _ProductCard(
                  product: p,
                  vendorName: _vendors.length > 1 ? _vendor(p.vendorId)?.name : null,
                  qty: _cart[p.id] ?? 0,
                  onQty: (n) => setState(() => _cart[p.id] = n.clamp(0, 999)),
                  onShowcase: (on) => _act(() async {
                    await _api.put('/api/shop/products/${p.id}/showcase', {'on': on});
                  }),
                  onHide: () => _act(() async {
                    await _api.put('/api/shop/products/${p.id}/visible', {'visible': false});
                  }),
                ),
              if (_all.any((p) => p.hidden))
                TextButton.icon(
                  onPressed: () => _showHidden(context),
                  icon: const Icon(Icons.visibility_outlined),
                  label: Text('Produtos ocultos (${_all.where((p) => p.hidden).length})'),
                ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: count == 0
          ? null
          : SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(gradient: Brand.nightGradient, borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('$count ${count == 1 ? 'item' : 'itens'} · ${cents(total)}',
                          style: text.titleSmall?.copyWith(color: Colors.white)),
                      if (vendorsInCart > 1)
                        Text('$vendorsInCart pedidos, um por vendedor', style: text.bodySmall?.copyWith(color: Colors.white70)),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Brand.rose, foregroundColor: Colors.white, minimumSize: const Size(48, 46)),
                    onPressed: () => _order(lines),
                    child: const Text('Pedir'),
                  ),
                ]),
              ),
            ),
    );
  }

  Future<void> _showHidden(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
          Text('Produtos ocultos', style: Theme.of(ctx).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final p in _all.where((p) => p.hidden))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(p.name),
              subtitle: Text(_vendor(p.vendorId)?.name ?? ''),
              trailing: TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _act(() async {
                    await _api.put('/api/shop/products/${p.id}/visible', {'visible': true});
                  });
                },
                child: const Text('Mostrar'),
              ),
            ),
        ]),
      ),
    );
  }

  Future<void> _order(List<ShopProduct> lines) async {
    final sent = await showModalBottomSheet<List<ShopOrder>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _OrderSheet(
        api: _api,
        lines: [for (final p in lines) (p, _cart[p.id]!)],
        vendorName: (id) => _vendor(id)?.name ?? '',
      ),
    );
    if (sent == null || !mounted) return;
    setState(_cart.clear);
    showMessage(
        context,
        sent.length == 1
            ? 'Pedido #${sent.first.id} enviado para ${sent.first.vendorName}!'
            : '${sent.length} pedidos enviados: ${sent.map((o) => o.vendorName).join(' e ')}.');
    Navigator.push(context, MaterialPageRoute(builder: (_) => PurchasesScreen(session: widget.session)));
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFFFF7E6), borderRadius: BorderRadius.circular(14)),
        child: Text(text, style: const TextStyle(color: Color(0xFF7C4A03), fontWeight: FontWeight.w600)),
      );
}

/// Linha de opções roláveis (vendedor, etiquetas, categorias).
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.selected, required this.options, required this.onSelected, this.strong = false});

  final String selected;
  final List<(String, String)> options;
  final ValueChanged<String> onSelected;
  final bool strong;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final (key, label) in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: selected == key,
                onSelected: (_) => onSelected(key),
                avatar: strong && key.isNotEmpty ? const Icon(Icons.storefront_outlined, size: 18) : null,
              ),
            ),
        ]),
      );
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.invite, required this.onAccept, required this.onDecline});

  final ShopInvite invite;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final waiting = invite.status == 'WAITING';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.mail_outline_rounded, color: Brand.rose),
            const SizedBox(width: 8),
            Expanded(child: Text('${invite.representativeName} convidou você para a loja dele', style: text.titleSmall)),
          ]),
          const SizedBox(height: 6),
          Text(
            waiting
                ? 'Você aceitou: já pode comprar os produtos dele. A comissão da sua mensalidade fica com quem já era seu vendedor.'
                : invite.replacesCurrent
                    ? 'Você já tem um vendedor. Aceitando, compra também dele, com pedidos separados por vendedor.'
                    : 'Aceitando, você vê os produtos dele aqui e pode fazer pedidos.',
            style: text.bodySmall?.copyWith(color: Brand.muted),
          ),
          if (!waiting) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton(onPressed: onAccept, child: const Text('Aceitar')),
              OutlinedButton(onPressed: onDecline, child: const Text('Recusar')),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.vendorName,
    required this.qty,
    required this.onQty,
    required this.onShowcase,
    required this.onHide,
  });

  final ShopProduct product;
  final String? vendorName;
  final int qty;
  final ValueChanged<int> onQty;
  final ValueChanged<bool> onShowcase;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // sem foto: nada de quadro vazio grande, só um ícone ao lado do nome
          if (p.thumbUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: p.imageUrl ?? p.thumbUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => Container(color: scheme.surfaceContainerHigh),
                  errorWidget: (_, _, _) => Container(color: scheme.surfaceContainerHigh, child: const Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (vendorName != null)
                Text('Vendedor: $vendorName'.toUpperCase(),
                    style: text.labelSmall?.copyWith(color: Brand.rose, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
              Row(children: [
                if (p.thumbUrl == null) ...[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
                    child: Icon(p.kind == 'EQUIPMENT' ? Icons.dry_outlined : Icons.inventory_2_outlined, color: Brand.muted),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name, style: text.titleMedium),
                    if (p.category != null) Text(p.category!, style: text.bodySmall?.copyWith(color: Brand.muted)),
                  ]),
                ),
              ]),
              if (p.tags.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [for (final t in p.tags) Pill(shopTagLabel[t] ?? t)]),
              ],
              const SizedBox(height: 10),
              Wrap(spacing: 18, runSpacing: 8, children: [
                _Price('Você paga', cents(p.priceCents), strike: p.onPromo ? cents(p.costCents) : null),
                _Price('Vender por', cents(p.suggestedCents)),
                _Price('Seu ganho', cents(p.gainCents), color: Brand.success),
              ]),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: p.showcase,
                onChanged: onShowcase,
                title: const Text('Mostrar para minhas clientes'),
                subtitle: const Text('Na sua página de agendamento. O pedido vai direto ao vendedor.'),
              ),
              Row(children: [
                IconButton.filledTonal(onPressed: qty > 0 ? () => onQty(qty - 1) : null, icon: const Icon(Icons.remove_rounded), tooltip: 'Menos'),
                SizedBox(width: 36, child: Text('$qty', textAlign: TextAlign.center, style: text.titleMedium)),
                IconButton.filled(onPressed: () => onQty(qty + 1), icon: const Icon(Icons.add_rounded), tooltip: 'Mais'),
                const Spacer(),
                TextButton(onPressed: onHide, child: const Text('Ocultar')),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price(this.label, this.value, {this.color, this.strike});

  final String label;
  final String value;
  final Color? color;
  final String? strike;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: text.bodySmall?.copyWith(color: Brand.muted)),
      Text(value, style: text.titleSmall?.copyWith(color: color)),
      if (strike != null)
        Text(strike!, style: text.bodySmall?.copyWith(color: Brand.muted, decoration: TextDecoration.lineThrough)),
    ]);
  }
}

/// Fechar o pedido: itens separados por vendedor e os dados de entrega (preenchidos com o último endereço).
class _OrderSheet extends StatefulWidget {
  const _OrderSheet({required this.api, required this.lines, required this.vendorName});

  final ApiClient api;
  final List<(ShopProduct, int)> lines;
  final String Function(int vendorId) vendorName;

  @override
  State<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<_OrderSheet> {
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _neighborhood = TextEditingController();
  final _city = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.api.get('/api/shop/address').then((a) {
      if (!mounted || a is! Map) return;
      String v(Object? x) => (x as String?) ?? '';
      if (_phone.text.isEmpty) _phone.text = v(a['phone']);
      if (_address.text.isEmpty) _address.text = v(a['address']);
      if (_neighborhood.text.isEmpty) _neighborhood.text = v(a['neighborhood']);
      if (_city.text.isEmpty) _city.text = v(a['city']);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    for (final c in [_contact, _phone, _address, _neighborhood, _city, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    if (_contact.text.trim().isEmpty || _neighborhood.text.trim().isEmpty) {
      showError(context, 'Informe quem recebe e o bairro.');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await widget.api.post('/api/shop/orders', {
        'items': [for (final (p, q) in widget.lines) {'productId': p.id, 'quantity': q}],
        'contactName': _contact.text.trim(),
        'phone': _phone.text.trim(),
        'address': _address.text.trim(),
        'neighborhood': _neighborhood.text.trim(),
        'city': _city.text.trim(),
        'note': _note.text.trim(),
      }) as List;
      if (mounted) Navigator.pop(context, [for (final o in res) ShopOrder.fromJson(o as Map<String, dynamic>)]);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final vendors = widget.lines.map((l) => l.$1.vendorId).toSet().toList();
    final total = widget.lines.fold<int>(0, (s, l) => s + l.$1.priceCents * l.$2);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
          Text('Fazer pedido', style: text.titleLarge),
          const SizedBox(height: 10),
          for (final v in vendors) ...[
            SoftCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Pedido para ${widget.vendorName(v)}'.toUpperCase(),
                    style: text.labelSmall?.copyWith(color: Brand.rose, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                const SizedBox(height: 6),
                for (final (p, q) in widget.lines.where((l) => l.$1.vendorId == v))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Expanded(child: Text('$q × ${p.name}')),
                      Text(cents(p.priceCents * q), style: text.titleSmall),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
          ],
          Row(children: [
            Expanded(child: Text('Total', style: text.titleMedium)),
            Text(cents(total), style: text.titleMedium),
          ]),
          const SizedBox(height: 14),
          Text('Entrega', style: text.titleSmall),
          const SizedBox(height: 8),
          TextField(controller: _contact, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Quem recebe')),
          const SizedBox(height: 10),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp')),
          const SizedBox(height: 10),
          TextField(controller: _address, decoration: const InputDecoration(labelText: 'Endereço (rua, número)')),
          const SizedBox(height: 10),
          TextField(controller: _neighborhood, decoration: const InputDecoration(labelText: 'Bairro')),
          const SizedBox(height: 10),
          TextField(controller: _city, decoration: const InputDecoration(labelText: 'Cidade')),
          const SizedBox(height: 10),
          TextField(controller: _note, decoration: const InputDecoration(labelText: 'Observação (opcional)')),
          const SizedBox(height: 8),
          Text('O pagamento é combinado direto com o vendedor. Nada é cobrado no app.', style: text.bodySmall?.copyWith(color: Brand.muted)),
          const SizedBox(height: 12),
          GradientButton(
            label: vendors.length > 1 ? 'Enviar ${vendors.length} pedidos' : 'Enviar pedido',
            icon: Icons.send_rounded,
            loading: _busy,
            onPressed: _busy ? null : _send,
          ),
        ]),
      ),
    );
  }
}
