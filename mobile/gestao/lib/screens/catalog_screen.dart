import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../session.dart';
import '../widgets/form_sheet.dart';

/// Serviços, profissionais e produtos/estoque.
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final owner = session.user.isOwner;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cadastros'),
          bottom: const TabBar(tabs: [Tab(text: 'Serviços'), Tab(text: 'Profissionais'), Tab(text: 'Produtos')]),
        ),
        body: TabBarView(children: [
          _CrudList<ServiceItem>(
            api: session.api,
            path: '/api/services',
            canEdit: owner,
            parse: ServiceItem.fromJson,
            title: 'serviço',
            fields: const [
              FieldSpec('name', 'Nome', required: true),
              FieldSpec('description', 'Descrição'),
              FieldSpec('durationMinutes', 'Duração (minutos)', kind: FieldKind.number, required: true),
              FieldSpec('price', r'Preço (R$)', kind: FieldKind.decimal, required: true),
              FieldSpec('cost', r'Custo de material (R$)', kind: FieldKind.decimal),
              FieldSpec('active', 'Ativo (aparece no agendamento online)', kind: FieldKind.toggle),
            ],
            toForm: (s) => {
              'name': s?.name,
              'description': s?.description,
              'durationMinutes': s?.durationMinutes ?? 30,
              'price': s?.price,
              'cost': s?.cost ?? 0,
              'active': s?.active ?? true,
            },
            id: (s) => s.id,
            tile: (s, _, onTap) => ListTile(
              onTap: onTap,
              title: Text(s.active ? s.name : '${s.name} (inativo)'),
              subtitle: Text('${s.durationMinutes} min · custo ${formatMoney(s.cost)}'
                  '${s.price > 0 ? ' · margem ${((s.price - s.cost) / s.price * 100).round()}%' : ''}'),
              trailing: Text(formatMoney(s.price)),
            ),
          ),
          _CrudList<Professional>(
            api: session.api,
            path: '/api/professionals',
            canEdit: owner,
            parse: Professional.fromJson,
            title: 'profissional',
            fields: const [
              FieldSpec('name', 'Nome', required: true),
              FieldSpec('phone', 'Telefone', kind: FieldKind.phone),
              FieldSpec('commissionPercent', 'Comissão (%)', kind: FieldKind.decimal, required: true),
              FieldSpec('active', 'Ativo (recebe agendamentos)', kind: FieldKind.toggle),
            ],
            toForm: (p) => {
              'name': p?.name,
              'phone': p?.phone,
              'commissionPercent': p?.commissionPercent ?? 0,
              'active': p?.active ?? true,
            },
            id: (p) => p.id,
            tile: (p, _, onTap) => ListTile(
              onTap: onTap,
              title: Text(p.active ? p.name : '${p.name} (inativo)'),
              subtitle: Text(p.phone != null ? formatPhone(p.phone!) : 'Sem telefone'),
              trailing: Text('${formatQuantity(p.commissionPercent)}%'),
            ),
          ),
          _CrudList<Product>(
            api: session.api,
            path: '/api/products',
            canEdit: true,
            parse: Product.fromJson,
            title: 'produto',
            fields: const [
              FieldSpec('name', 'Nome', required: true),
              FieldSpec('unit', 'Unidade (un, ml, g...)', required: true),
              FieldSpec('costPrice', r'Custo unitário (R$)', kind: FieldKind.decimal, required: true),
              FieldSpec('salePrice', r'Preço de venda (R$, 0 = uso interno)', kind: FieldKind.decimal, required: true),
              FieldSpec('minStock', 'Estoque mínimo (alerta)', kind: FieldKind.decimal, required: true),
              FieldSpec('active', 'Ativo', kind: FieldKind.toggle),
            ],
            toForm: (p) => {
              'name': p?.name,
              'unit': p?.unit ?? 'un',
              'costPrice': p?.costPrice ?? 0,
              'salePrice': p?.salePrice ?? 0,
              'minStock': p?.minStock ?? 0,
              'active': p?.active ?? true,
            },
            id: (p) => p.id,
            tile: (p, reload, onTap) => ListTile(
              onTap: onTap,
              title: Text(p.active ? p.name : '${p.name} (inativo)'),
              subtitle: Text('Estoque ${formatQuantity(p.stock)} ${p.unit}${p.lowStock ? ' · BAIXO' : ''}',
                  style: p.lowStock ? TextStyle(color: Theme.of(context).colorScheme.error) : null),
              trailing: IconButton(
                tooltip: 'Movimentar estoque',
                icon: const Icon(Icons.swap_vert),
                onPressed: () => _moveStock(context, session.api, p, reload),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  static Future<void> _moveStock(BuildContext context, ApiClient api, Product p, VoidCallback reload) async {
    const types = {'IN': 'Entrada (compra)', 'SALE': 'Venda', 'USE': 'Uso interno', 'LOSS': 'Perda / ajuste'};
    var type = 'IN';
    final qty = TextEditingController(text: '1');
    final value = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(p.name),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: [for (final e in types.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
              onChanged: (v) => setState(() => type = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Quantidade (${p.unit})'),
            ),
            if (type == 'IN' || type == 'SALE') ...[
              const SizedBox(height: 12),
              TextField(
                controller: value,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: type == 'IN' ? 'Custo unitário' : 'Preço unitário',
                  hintText: formatQuantity(type == 'IN' ? p.costPrice : p.salePrice),
                ),
              ),
            ],
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Registrar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await api.post('/api/products/${p.id}/movements', {
        'type': type,
        'quantity': double.tryParse(qty.text.replaceAll(',', '.')) ?? 0,
        'unitValue': double.tryParse(value.text.replaceAll(',', '.')),
      });
      reload();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}

class _CrudList<T> extends StatefulWidget {
  const _CrudList({
    required this.api,
    required this.path,
    required this.canEdit,
    required this.parse,
    required this.title,
    required this.fields,
    required this.toForm,
    required this.id,
    required this.tile,
  });

  final ApiClient api;
  final String path;
  final bool canEdit;
  final T Function(Map<String, dynamic>) parse;
  final String title;
  final List<FieldSpec> fields;
  final Map<String, Object?> Function(T?) toForm;
  final int Function(T) id;
  final Widget Function(T item, VoidCallback reload, VoidCallback? onTap) tile;

  @override
  State<_CrudList<T>> createState() => _CrudListState<T>();
}

class _CrudListState<T> extends State<_CrudList<T>> with AutomaticKeepAliveClientMixin {
  List<T>? _items;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final json = await widget.api.get(widget.path) as List;
      if (mounted) setState(() => _items = json.map((e) => widget.parse(e as Map<String, dynamic>)).toList());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _edit([T? item]) async {
    final saved = await showFormSheet(
      context,
      title: item == null ? 'Novo ${widget.title}' : 'Editar ${widget.title}',
      fields: widget.fields,
      initial: widget.toForm(item),
      onSave: (v) => item == null ? widget.api.post(widget.path, v) : widget.api.put('${widget.path}/${widget.id(item)}', v),
    );
    if (saved) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      floatingActionButton: widget.canEdit
          ? FloatingActionButton(heroTag: widget.path, tooltip: 'Novo ${widget.title}', onPressed: _edit, child: const Icon(Icons.add))
          : null,
      body: _error != null
          ? ErrorRetry(message: _error!, onRetry: _load)
          : _items == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 88),
                    children: [
                      if (_items!.isEmpty)
                        const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Nenhum cadastro ainda.'))),
                      for (final item in _items!)
                        widget.tile(item, _load, widget.canEdit ? () => _edit(item) : null),
                    ],
                  ),
                ),
    );
  }
}
