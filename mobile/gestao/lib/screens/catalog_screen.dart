import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../session.dart';
import '../widgets/form_sheet.dart';
import '../widgets/service_photos.dart';

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
        body: Column(children: [
          GradientHeader(
            gradient: Brand.nightGradient,
            bottomPadding: 16,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Cadastros', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(gradient: Brand.gradient, borderRadius: BorderRadius.circular(12)),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                  tabs: const [Tab(text: 'Serviços'), Tab(text: 'Equipe'), Tab(text: 'Produtos')],
                ),
              ),
            ]),
          ),
          Expanded(child: TabBarView(children: [
          _CrudList<ServiceItem>(
            api: session.api,
            path: '/api/services',
            canEdit: owner,
            parse: ServiceItem.fromJson,
            title: 'serviço',
            withPhotos: true,
            fields: [
              const FieldSpec('name', 'Nome', required: true),
              const FieldSpec('category', 'Categoria', hint: 'Ex.: Cabelo, Unhas', suggestions: ['Cabelo', 'Unhas', 'Estética', 'Barba']),
              FieldSpec(
                'professionalIds',
                'Quem faz este serviço',
                kind: FieldKind.choices,
                emptyHint: 'Opcional. Sem nenhum marcado, vale o que cada profissional atende (categorias na aba Equipe).',
                loadOptions: () async => {
                  for (final p in (await session.api.get('/api/professionals') as List).map((e) => Professional.fromJson(e as Map<String, dynamic>)))
                    if (p.active) p.id: p.name,
                },
              ),
              const FieldSpec('description', 'Descrição'),
              const FieldSpec('durationMinutes', 'Duração (minutos)', kind: FieldKind.number, required: true),
              const FieldSpec('price', r'Preço (R$)', kind: FieldKind.decimal, required: true),
              const FieldSpec('cost', r'Custo de material (R$)', kind: FieldKind.decimal),
              const FieldSpec('active', 'Ativo (aparece no agendamento online)', kind: FieldKind.toggle),
            ],
            toForm: (s) => {
              'name': s?.name,
              'category': s?.category,
              'professionalIds': s?.professionalIds ?? const <int>[],
              'description': s?.description,
              'durationMinutes': s?.durationMinutes ?? 30,
              'price': s?.price,
              'cost': s?.cost ?? 0,
              'active': s?.active ?? true,
            },
            id: (s) => s.id,
            tile: (s, _, onTap) => _ItemCard(
              onTap: onTap,
              inactive: !s.active,
              leading: ServiceIcon(s.name),
              title: s.name,
              pills: [
                if (s.category != null) Pill(s.category!, icon: Icons.folder_outlined),
                Pill('${s.durationMinutes} min', icon: Icons.schedule_rounded),
                if (s.price > 0)
                  Pill('margem ${((s.price - s.cost) / s.price * 100).round()}%',
                      icon: Icons.trending_up_rounded, color: const Color(0xFFDCFCE7), textColor: const Color(0xFF15803D)),
              ],
              trailing: Text(formatMoney(s.price), style: const TextStyle(fontWeight: FontWeight.w800, color: Brand.rose, fontSize: 16)),
            ),
          ),
          _CrudList<Professional>(
            api: session.api,
            path: '/api/professionals',
            canEdit: owner,
            parse: Professional.fromJson,
            title: 'profissional',
            fields: [
              const FieldSpec('name', 'Nome', required: true),
              FieldSpec(
                'categories',
                'Atende (categorias)',
                kind: FieldKind.tags,
                suggestions: const ['Cabelo', 'Unhas', 'Estética', 'Barba'],
                emptyHint: 'O que você marcar define os serviços desta pessoa. Sem nenhuma marcada, ela faz todos.',
                loadTags: () async => {
                  'Cabelo',
                  'Unhas',
                  'Estética',
                  'Barba',
                  for (final s in await session.api.get('/api/services') as List)
                    if (((s as Map)['category'] as String?)?.isNotEmpty ?? false) s['category'] as String,
                }.toList(),
              ),
              const FieldSpec('phone', 'Telefone', kind: FieldKind.phone),
              const FieldSpec('commissionPercent', 'Comissão (%)', kind: FieldKind.decimal, required: true),
              const FieldSpec('active', 'Ativo (recebe agendamentos)', kind: FieldKind.toggle),
            ],
            toForm: (p) => {
              'name': p?.name,
              'categories': p?.categories ?? const <String>[],
              'phone': p?.phone,
              'commissionPercent': p?.commissionPercent ?? 0,
              'active': p?.active ?? true,
            },
            id: (p) => p.id,
            tile: (p, _, onTap) => _ItemCard(
              onTap: onTap,
              inactive: !p.active,
              leading: InitialsAvatar(p.name, size: 48),
              title: p.name,
              pills: [
                Pill(p.phone != null ? formatPhone(p.phone!) : 'Sem telefone', icon: Icons.phone_outlined),
                for (final c in p.categories) Pill(c, icon: Icons.folder_outlined),
              ],
              trailing: Pill('${formatQuantity(p.commissionPercent)}% comissão',
                  color: const Color(0xFFEDE9FE), textColor: const Color(0xFF6D28D9)),
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
            tile: (p, reload, onTap) => _ItemCard(
              onTap: onTap,
              inactive: !p.active,
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: p.lowStock ? const Color(0xFFFFE4E6) : const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.inventory_2_outlined, color: p.lowStock ? const Color(0xFFBE123C) : const Color(0xFF7C3AED)),
              ),
              title: p.name,
              pills: [
                Pill('${formatQuantity(p.stock)} ${p.unit}',
                    icon: p.lowStock ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                    color: p.lowStock ? const Color(0xFFFFE4E6) : const Color(0xFFDCFCE7),
                    textColor: p.lowStock ? const Color(0xFFBE123C) : const Color(0xFF15803D)),
                if (p.salePrice > 0) Pill(formatMoney(p.salePrice), icon: Icons.sell_outlined),
              ],
              trailing: IconButton.filledTonal(
                tooltip: 'Movimentar estoque',
                icon: const Icon(Icons.swap_vert_rounded),
                onPressed: () => _moveStock(context, session.api, p, reload),
              ),
            ),
          ),
        ])),
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
    this.withPhotos = false,
  });

  /// Mostra "Fotos deste serviço" no formulário (só para serviços).
  final bool withPhotos;

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
    final photos = widget.withPhotos ? ServicePhotosController(api: widget.api, serviceId: item == null ? null : widget.id(item)) : null;
    String? photoError;
    final saved = await showFormSheet(
      context,
      title: item == null ? 'Novo ${widget.title}' : 'Editar ${widget.title}',
      fields: widget.fields,
      initial: widget.toForm(item),
      extra: photos == null ? null : ServicePhotosSection(controller: photos),
      onSave: (v) async {
        if (item != null) return widget.api.put('${widget.path}/${widget.id(item)}', v);
        final created = await widget.api.post(widget.path, v) as Map<String, dynamic>;
        // o serviço já existe: se alguma foto falhar, avisa depois em vez de repetir o cadastro
        if (photos != null) photoError = await photos.uploadPending(created['id'] as int);
      },
    );
    if (photoError != null && mounted) showError(context, 'Serviço salvo, mas as fotos não foram enviadas: $photoError');
    if (saved) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      floatingActionButton: widget.canEdit
          ? SizedBox(width: 140, child: GradientButton(label: 'Novo', icon: Icons.add_rounded, onPressed: _edit))
          : null,
      body: _error != null
          ? ErrorRetry(message: _error!, onRetry: _load)
          : _items == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                    children: [
                      if (_items!.isEmpty)
                        EmptyState(icon: Icons.add_box_outlined, title: 'Nenhum ${widget.title} ainda', message: 'Toque em "Novo" para cadastrar.'),
                      for (final item in _items!)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: widget.tile(item, _load, widget.canEdit ? () => _edit(item) : null),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.leading,
    required this.title,
    required this.pills,
    required this.trailing,
    required this.onTap,
    required this.inactive,
  });

  final Widget leading;
  final String title;
  final List<Widget> pills;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool inactive;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: inactive ? 0.55 : 1,
        child: SoftCard(
          onTap: onTap,
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(inactive ? '$title (inativo)' : title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: pills),
              ]),
            ),
            const SizedBox(width: 8),
            trailing,
          ]),
        ),
      );
}
