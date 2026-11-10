import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:salao_core/salao_core.dart';

import '../session.dart';
import 'shop_models.dart';

/// "Minhas compras": pedidos do salão separados por vendedor (com o que deve a cada um) e as vendas às clientes.
class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key, required this.session});

  final Session session;

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  List<ShopOrder> _orders = [];
  List<ShopOrder> _sales = [];
  Map<String, dynamic>? _balance;
  bool _loaded = false;
  String? _error;
  int? _vendor;

  ApiClient get _api => widget.session.api;
  String get _key => 'shop:${widget.session.user.salonSlug}';

  @override
  void initState() {
    super.initState();
    _fromCache();
    _load();
  }

  Future<void> _fromCache() async {
    final cached = await LocalCache.read('$_key:purchases');
    if (!mounted || _loaded || cached is! Map) return;
    setState(() => _apply(cached));
  }

  void _apply(Map data) {
    _orders = [for (final o in (data['orders'] as List? ?? const [])) ShopOrder.fromJson(o as Map<String, dynamic>)];
    _sales = [for (final o in (data['sales'] as List? ?? const [])) ShopOrder.fromJson(o as Map<String, dynamic>)];
    _balance = data['balance'] as Map<String, dynamic>?;
  }

  Future<void> _load() async {
    try {
      final data = {
        'orders': await _api.get('/api/shop/orders'),
        'sales': await _api.get('/api/shop/customer-orders'),
        'balance': await _api.get('/api/shop/balance'),
      };
      await LocalCache.write('$_key:purchases', data);
      if (!mounted) return;
      setState(() {
        _apply(data);
        _loaded = true;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _orders.isEmpty ? e.toString() : null);
    }
  }

  Future<void> _act(Future<void> Function() fn) async {
    try {
      await fn();
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final vendors = [for (final v in (_balance?['vendors'] as List? ?? const [])) v as Map<String, dynamic>];
    final orders = _orders.where((o) => _vendor == null || o.vendorId == _vendor).toList();
    final saleCommission = _sales.where((o) => o.status == 'DELIVERED' && !o.commissionSettled).fold<int>(0, (s, o) => s + o.commissionCents);

    return Scaffold(
      appBar: AppBar(title: const Text('Minhas compras')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            if (!_loaded && _orders.isEmpty && _error == null)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
            if (_balance != null)
              Row(children: [
                Expanded(child: _Stat('Falta pagar', cents((_balance!['owedCents'] as num).toInt()), color: Brand.rose)),
                const SizedBox(width: 10),
                Expanded(child: _Stat('Já pago', cents((_balance!['paidCents'] as num).toInt()), color: Brand.success)),
              ]),
            if (vendors.length > 1) ...[
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: const Text('Todos'), selected: _vendor == null, onSelected: (_) => setState(() => _vendor = null)),
                  ),
                  for (final v in vendors)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('${v['vendorName']} · deve ${cents((v['owedCents'] as num).toInt())}'),
                        selected: _vendor == (v['vendorId'] as num).toInt(),
                        onSelected: (_) => setState(() => _vendor = (v['vendorId'] as num).toInt()),
                      ),
                    ),
                ]),
              ),
            ],
            if (_loaded && _orders.isEmpty)
              const EmptyState(icon: Icons.shopping_bag_outlined, title: 'Nenhuma compra ainda', message: 'Seus pedidos aos vendedores aparecem aqui.'),
            for (final o in orders)
              _OrderCard(
                order: o,
                onReceived: () => _act(() async {
                  await _api.post('/api/shop/orders/${o.id}/received');
                }),
                onCancel: () async {
                  if (await confirmDialog(context, 'Cancelar o pedido #${o.id}?', confirm: 'Cancelar pedido', danger: true)) {
                    await _act(() async {
                      await _api.post('/api/shop/orders/${o.id}/cancel');
                    });
                  }
                },
              ),
            if (_sales.isNotEmpty) ...[
              const SectionTitle('Vendas para minhas clientes'),
              Text('Pedidos das suas clientes pela sua página. Vão direto ao vendedor, que entrega e repassa a sua comissão.',
                  style: text.bodySmall?.copyWith(color: Brand.muted)),
              const SizedBox(height: 10),
              _Stat('Comissão a receber', cents(saleCommission), color: Brand.success),
              const SizedBox(height: 10),
              for (final o in _sales)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SoftCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text('${o.contactName} · ${cents(o.totalCents)}', style: text.titleSmall)),
                        _StatusPill(o.status),
                      ]),
                      Text('Entrega: ${o.vendorName}', style: text.bodySmall?.copyWith(color: Brand.muted)),
                      const SizedBox(height: 4),
                      Text(o.items.map((i) => '${i.quantity} × ${i.name}').join(', '), style: text.bodySmall),
                      const SizedBox(height: 4),
                      Text(
                        'Sua comissão: ${cents(o.commissionCents)}'
                        '${o.commissionSettled ? ' · repassada' : o.status == 'DELIVERED' ? ' · a receber' : o.status == 'CANCELED' ? '' : ' · depois da entrega'}',
                        style: text.bodySmall?.copyWith(color: Brand.success, fontWeight: FontWeight.w700),
                      ),
                    ]),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: text.bodySmall?.copyWith(color: Brand.muted)),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: text.titleLarge?.copyWith(color: color))),
      ]),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);

  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'PENDING' => (const Color(0xFFFFF3C4), const Color(0xFF7C4A03)),
      'PREPARING' => (const Color(0xFFDDEEFF), const Color(0xFF0B4A86)),
      'SHIPPED' => (const Color(0xFFEDE4FF), const Color(0xFF4C1D95)),
      'DELIVERED' => (const Color(0xFFD9F5E6), const Color(0xFF065F46)),
      _ => (const Color(0xFFE5E7EB), const Color(0xFF374151)),
    };
    return Pill(shopStatusLabel[status] ?? status, color: bg, textColor: fg);
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onReceived, required this.onCancel});

  final ShopOrder order;
  final VoidCallback onReceived;
  final VoidCallback onCancel;

  static const _steps = ['PENDING', 'PREPARING', 'SHIPPED', 'DELIVERED'];

  @override
  Widget build(BuildContext context) {
    final o = order;
    final text = Theme.of(context).textTheme;
    final step = _steps.indexOf(o.status);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Pedido #${o.id}', style: text.titleMedium),
                Text('Vendedor: ${o.vendorName}', style: text.bodyMedium?.copyWith(color: Brand.rose, fontWeight: FontWeight.w700)),
                Text(DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR').format(o.createdAt), style: text.bodySmall?.copyWith(color: Brand.muted)),
              ]),
            ),
            _StatusPill(o.status),
          ]),
          if (o.status != 'CANCELED') ...[
            const SizedBox(height: 12),
            Row(children: [
              for (var i = 0; i < _steps.length; i++)
                Expanded(
                  child: Container(
                    height: 6,
                    margin: EdgeInsets.only(right: i < _steps.length - 1 ? 4 : 0),
                    decoration: BoxDecoration(
                      gradient: i <= step ? Brand.gradient : null,
                      color: i <= step ? null : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 4),
            Text(shopStatusLabel[o.status] ?? o.status, style: text.labelMedium),
          ],
          const SizedBox(height: 8),
          for (final i in o.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Expanded(child: Text('${i.quantity} × ${i.name}')),
                Text(cents(i.quantity * i.unitCents)),
              ]),
            ),
          const Divider(height: 20),
          Wrap(spacing: 18, runSpacing: 6, children: [
            Text('Total ${cents(o.totalCents)}', style: text.titleSmall),
            Text('Pago ${cents(o.paidCents)}', style: text.titleSmall?.copyWith(color: Brand.success)),
            if (o.status != 'CANCELED') Text('Falta ${cents(o.balanceCents)}', style: text.titleSmall?.copyWith(color: Brand.rose)),
          ]),
          if (o.status == 'SHIPPED') ...[
            const SizedBox(height: 10),
            Text('O vendedor enviou. Quando receber, confirme.', style: text.bodySmall),
            const SizedBox(height: 6),
            FilledButton.icon(onPressed: onReceived, icon: const Icon(Icons.check_circle_outline), label: const Text('Confirmar recebimento')),
          ],
          if (o.status == 'PENDING') ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: onCancel, child: const Text('Cancelar pedido'))),
          ],
        ]),
      ),
    );
  }
}
