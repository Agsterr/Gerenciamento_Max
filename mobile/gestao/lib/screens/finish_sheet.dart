import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

/// Fechamento: valor final + produtos usados/vendidos (baixa no estoque).
Future<bool> showFinishSheet(BuildContext context, {required ApiClient api, required Appointment appointment}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _FinishSheet(api: api, appointment: appointment),
  );
  return ok ?? false;
}

class _Line {
  Product? product;
  double quantity = 1;
  bool sold = false;
}

class _FinishSheet extends StatefulWidget {
  const _FinishSheet({required this.api, required this.appointment});

  final ApiClient api;
  final Appointment appointment;

  @override
  State<_FinishSheet> createState() => _FinishSheetState();
}

class _FinishSheetState extends State<_FinishSheet> {
  late final _price = TextEditingController(text: formatQuantity(widget.appointment.price));
  List<Product> _products = [];
  final List<_Line> _lines = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.api.get('/api/products').then((json) {
      if (mounted) {
        setState(() => _products =
            (json as List).map((e) => Product.fromJson(e as Map<String, dynamic>)).where((p) => p.active).toList());
      }
    }).catchError((Object e) {
      if (mounted) showError(context, e);
    });
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  double get _priceValue => double.tryParse(_price.text.replaceAll(',', '.')) ?? 0;

  double get _sales => _lines.where((l) => l.sold && l.product != null).fold(0, (s, l) => s + l.quantity * l.product!.salePrice);

  List<Map<String, Object>> _items(bool sold) => [
        for (final l in _lines.where((l) => l.product != null && l.quantity > 0 && l.sold == sold))
          {'productId': l.product!.id, 'quantity': l.quantity},
      ];

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await widget.api.post('/api/appointments/${widget.appointment.id}/finish', {
        'price': _priceValue,
        'usedProducts': _items(false),
        'soldProducts': _items(true),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.viewInsetsOf(context).bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Finalizar atendimento', style: Theme.of(context).textTheme.titleLarge),
            Text('${a.customer.name} · ${a.service.name} com ${a.professional.name}'),
            const SizedBox(height: 16),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: r'Valor do serviço (R$)'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Text('Produtos usados ou vendidos', style: Theme.of(context).textTheme.titleSmall),
            for (final l in _lines)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<Product>(
                      initialValue: l.product,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Produto'),
                      items: [
                        for (final p in _products)
                          DropdownMenuItem(value: p, child: Text('${p.name} (${formatQuantity(p.stock)} ${p.unit})')),
                      ],
                      onChanged: (p) => setState(() => l.product = p),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 64,
                    child: TextFormField(
                      initialValue: '1',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Qtd'),
                      onChanged: (v) => setState(() => l.quantity = double.tryParse(v.replaceAll(',', '.')) ?? 0),
                    ),
                  ),
                  IconButton(
                    tooltip: l.sold ? 'Venda' : 'Uso',
                    icon: Icon(l.sold ? Icons.sell : Icons.content_cut),
                    onPressed: () => setState(() => l.sold = !l.sold),
                  ),
                  IconButton(
                    tooltip: 'Remover',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _lines.remove(l)),
                  ),
                ]),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => setState(() => _lines.add(_Line())),
                icon: const Icon(Icons.add),
                label: const Text('Produto'),
              ),
            ),
            Text('Toque no ícone para alternar entre uso (tesoura) e venda (etiqueta).',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Text('Total a receber: ${formatMoney(_priceValue + _sales)}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Salvando...' : 'Finalizar')),
          ],
        ),
      ),
    );
  }
}
