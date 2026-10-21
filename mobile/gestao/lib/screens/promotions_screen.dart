import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../session.dart';

/// Pacotes (vários serviços com desconto) e promoções (desconto em % por um período).
/// O cliente vê o preço promocional e recebe o aviso no app.
class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key, required this.session});

  final Session session;

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  List<ServiceItem>? _services;
  List<Promotion>? _promos;
  String? _error;

  ApiClient get _api => widget.session.api;
  bool get _owner => widget.session.user.isOwner;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Future.wait([_api.get('/api/services'), _api.get('/api/promotions')]);
      if (!mounted) return;
      setState(() {
        _services = (r[0] as List).map((e) => ServiceItem.fromJson(e as Map<String, dynamic>)).toList();
        _promos = (r[1] as List).map((e) => Promotion.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  List<ServiceItem> get _plain => [for (final s in _services ?? const <ServiceItem>[]) if (!s.isKit && s.active) s];

  Future<void> _editKit([ServiceItem? kit]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _KitSheet(api: _api, services: _plain, kit: kit),
    );
    if (saved == true) _load();
  }

  Future<void> _editPromo([Promotion? promo]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PromoSheet(api: _api, services: [for (final s in _services ?? const <ServiceItem>[]) if (s.active) s], promo: promo),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final kits = [for (final s in _services ?? const <ServiceItem>[]) if (s.isKit) s];
    final names = {for (final s in _services ?? const <ServiceItem>[]) s.id: s.name};
    final today = DateTime.now();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pacotes e promoções'),
          bottom: const TabBar(tabs: [Tab(text: 'Pacotes'), Tab(text: 'Promoções')]),
        ),
        body: _error != null
            ? ErrorRetry(message: _error!, onRetry: _load)
            : _services == null
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(children: [
                    RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
                        Text('Vários serviços juntos com desconto. Ex.: corte + escova + hidratação.',
                            style: text.bodySmall?.copyWith(color: Brand.muted)),
                        const SizedBox(height: 12),
                        if (kits.isEmpty) const SoftCard(child: Text('Nenhum pacote ainda.')),
                        for (final k in kits)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: SoftCard(
                              onTap: _owner ? () => _editKit(k) : null,
                              child: Row(children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(k.name, style: text.titleSmall),
                                    Text('${k.kitServiceIds.map((id) => names[id] ?? '').join(' + ')} · ${k.durationMinutes} min',
                                        style: text.bodySmall?.copyWith(color: Brand.muted)),
                                    if (!k.active) const Pill('inativo'),
                                  ]),
                                ),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  if (k.kitFullPrice != null)
                                    Text.rich(
                                      TextSpan(children: [
                                        const TextSpan(text: 'De '),
                                        TextSpan(
                                            text: formatMoney(k.kitFullPrice!),
                                            style: const TextStyle(decoration: TextDecoration.lineThrough)),
                                        const TextSpan(text: ' por'),
                                      ]),
                                      style: text.bodySmall?.copyWith(color: Brand.muted),
                                    ),
                                  Text(formatMoney(k.price), style: text.titleSmall?.copyWith(color: Brand.rose)),
                                  Text('-${formatQuantity(k.kitDiscountPercent ?? 0)}%',
                                      style: text.bodySmall?.copyWith(color: const Color(0xFF15803D), fontWeight: FontWeight.w700)),
                                ]),
                              ]),
                            ),
                          ),
                        if (_owner)
                          OutlinedButton.icon(onPressed: _editKit, icon: const Icon(Icons.add), label: const Text('Novo pacote')),
                      ]),
                    ),
                    RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
                        Text('Desconto em % para horários dentro do período. O cliente vê o preço promocional e recebe o aviso no app.',
                            style: text.bodySmall?.copyWith(color: Brand.muted)),
                        const SizedBox(height: 12),
                        if (_promos!.isEmpty) const SoftCard(child: Text('Nenhuma promoção ainda.')),
                        for (final p in _promos!)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: SoftCard(
                              onTap: _owner ? () => _editPromo(p) : null,
                              child: Row(children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('${p.name} · ${formatQuantity(p.discountPercent)}%', style: text.titleSmall),
                                    Text('${formatDate(p.startsOn)} a ${formatDate(p.endsOn)} · '
                                        '${p.serviceNames.isEmpty ? 'Todos os serviços' : p.serviceNames.join(', ')}',
                                        style: text.bodySmall?.copyWith(color: Brand.muted)),
                                  ]),
                                ),
                                _StatusPill(p.status(today)),
                              ]),
                            ),
                          ),
                        if (_owner)
                          OutlinedButton.icon(onPressed: _editPromo, icon: const Icon(Icons.add), label: const Text('Nova promoção')),
                      ]),
                    ),
                  ]),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(this.status);

  final String status;

  @override
  Widget build(BuildContext context) => switch (status) {
        'No ar' => Pill(status, color: const Color(0xFFDCFCE7), textColor: const Color(0xFF15803D)),
        'Agendada' => Pill(status, color: const Color(0xFFFFF7E6), textColor: const Color(0xFFB45309)),
        _ => Pill(status),
      };
}

/// Escolha de serviços em botões.
class _ServiceChips extends StatelessWidget {
  const _ServiceChips({required this.services, required this.selected, required this.onChanged});

  final List<ServiceItem> services;
  final Set<int> selected;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 4, children: [
        for (final s in services)
          FilterChip(
            label: Text('${s.name} · ${formatMoney(s.price)}'),
            selected: selected.contains(s.id),
            onSelected: (v) {
              v ? selected.add(s.id) : selected.remove(s.id);
              onChanged();
            },
          ),
      ]);
}

class _KitSheet extends StatefulWidget {
  const _KitSheet({required this.api, required this.services, this.kit});

  final ApiClient api;
  final List<ServiceItem> services;
  final ServiceItem? kit;

  @override
  State<_KitSheet> createState() => _KitSheetState();
}

class _KitSheetState extends State<_KitSheet> {
  late final _name = TextEditingController(text: widget.kit?.name);
  late final _percent = TextEditingController(text: formatQuantity(widget.kit?.kitDiscountPercent ?? 10));
  late final Set<int> _chosen = {...?widget.kit?.kitServiceIds};
  late bool _active = widget.kit?.active ?? true;
  bool _busy = false;

  double get _pct => double.tryParse(_percent.text.replaceAll(',', '.')) ?? 0;

  Future<void> _save() async {
    final chosen = widget.services.where((s) => _chosen.contains(s.id)).toList();
    if (_name.text.trim().isEmpty || chosen.length < 2) {
      showError(context, 'Dê um nome e escolha pelo menos 2 serviços.');
      return;
    }
    final full = chosen.fold(0.0, (t, s) => t + s.price);
    final minutes = chosen.fold(0, (t, s) => t + s.durationMinutes);
    final body = {
      'name': _name.text.trim(),
      'description': widget.kit?.description,
      'category': widget.kit?.category ?? 'Pacotes',
      'durationMinutes': minutes < 5 ? 5 : minutes,
      'price': full * (100 - _pct) / 100,
      'cost': 0,
      'active': _active,
      'professionalIds': widget.kit?.professionalIds ?? const <int>[],
      'kitServiceIds': _chosen.toList(),
      'kitDiscountPercent': _pct,
    };
    setState(() => _busy = true);
    try {
      if (widget.kit == null) {
        await widget.api.post('/api/services', body);
      } else {
        await widget.api.put('/api/services/${widget.kit!.id}', body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chosen = widget.services.where((s) => _chosen.contains(s.id));
    final full = chosen.fold(0.0, (t, s) => t + s.price);
    final price = full * (100 - _pct) / 100;
    final minutes = chosen.fold(0, (t, s) => t + s.durationMinutes);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, sheetBottomInset(context) + 16),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.kit == null ? 'Novo pacote' : 'Editar pacote', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nome do pacote', hintText: 'Dia da noiva')),
          const SizedBox(height: 12),
          Text('Serviços do pacote (pelo menos 2)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          _ServiceChips(services: widget.services, selected: _chosen, onChanged: () => setState(() {})),
          const SizedBox(height: 12),
          TextField(
            controller: _percent,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Desconto do pacote (%)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(14)),
            child: Text(
              'De ${formatMoney(full)} por ${formatMoney(price)} · '
              'cliente economiza ${formatMoney(full - price)} · $minutes min',
              style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ativo (aparece no agendamento)'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          GradientButton(label: 'Salvar', icon: Icons.check_rounded, loading: _busy, onPressed: _save),
        ]),
      ),
    );
  }
}

class _PromoSheet extends StatefulWidget {
  const _PromoSheet({required this.api, required this.services, this.promo});

  final ApiClient api;
  final List<ServiceItem> services;
  final Promotion? promo;

  @override
  State<_PromoSheet> createState() => _PromoSheetState();
}

class _PromoSheetState extends State<_PromoSheet> {
  late final _name = TextEditingController(text: widget.promo?.name);
  late final _description = TextEditingController(text: widget.promo?.description);
  late final _percent = TextEditingController(text: formatQuantity(widget.promo?.discountPercent ?? 10));
  late DateTimeRange _range = DateTimeRange(
    start: widget.promo?.startsOn ?? dateOnly(DateTime.now()),
    end: widget.promo?.endsOn ?? dateOnly(DateTime.now()).add(const Duration(days: 7)),
  );
  late final Set<int> _chosen = {...?widget.promo?.serviceIds};
  late bool _active = widget.promo?.active ?? true;
  bool _busy = false;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showError(context, 'Dê um nome para a promoção.');
      return;
    }
    final body = {
      'name': _name.text.trim(),
      'description': _description.text.trim(),
      'discountPercent': double.tryParse(_percent.text.replaceAll(',', '.')) ?? 0,
      'startsOn': isoDate(_range.start),
      'endsOn': isoDate(_range.end),
      'active': _active,
      'serviceIds': _chosen.toList(),
    };
    setState(() => _busy = true);
    try {
      if (widget.promo == null) {
        await widget.api.post('/api/promotions', body);
      } else {
        await widget.api.put('/api/promotions/${widget.promo!.id}', body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    if (!await confirmDialog(context, 'Excluir esta promoção?', confirm: 'Excluir', danger: true)) return;
    try {
      await widget.api.delete('/api/promotions/${widget.promo!.id}');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, sheetBottomInset(context) + 16),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.promo == null ? 'Nova promoção' : 'Editar promoção', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nome', hintText: 'Semana da escova')),
          const SizedBox(height: 12),
          TextField(controller: _description, decoration: const InputDecoration(labelText: 'Descrição (aparece para o cliente)')),
          const SizedBox(height: 12),
          TextField(
            controller: _percent,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Desconto (%)'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range_rounded),
            label: Text('De ${formatDate(_range.start)} a ${formatDate(_range.end)}'),
            onPressed: () async {
              final r = await showDateRangePicker(
                context: context,
                initialDateRange: _range,
                firstDate: DateTime(2024),
                lastDate: DateTime.now().add(const Duration(days: 730)),
              );
              if (r != null) setState(() => _range = r);
            },
          ),
          const SizedBox(height: 12),
          Text('Serviços (nenhum marcado = todos, menos pacotes)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          _ServiceChips(services: widget.services, selected: _chosen, onChanged: () => setState(() {})),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ativa'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          GradientButton(label: 'Salvar', icon: Icons.check_rounded, loading: _busy, onPressed: _save),
          if (widget.promo != null)
            TextButton(onPressed: _delete, child: Text('Excluir promoção', style: TextStyle(color: Theme.of(context).colorScheme.error))),
        ]),
      ),
    );
  }
}
