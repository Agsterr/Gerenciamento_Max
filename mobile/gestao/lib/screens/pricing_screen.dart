import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

/// Ajuda a precificar: preço mínimo, sugerido e lucro de cada serviço.
class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  Pricing? _pricing;
  List<ServiceItem> _services = [];
  String? _error;

  final _margin = TextEditingController();
  final _fees = TextEditingController();
  final _occupancy = TextEditingController();
  final _fixed = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load(fillForm: true);
  }

  @override
  void dispose() {
    for (final c in [_margin, _fees, _occupancy, _fixed]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load({bool fillForm = false}) async {
    setState(() => _error = null);
    try {
      final r = await Future.wait([widget.api.get('/api/pricing'), widget.api.get('/api/services')]);
      final pricing = Pricing.fromJson(r[0] as Map<String, dynamic>);
      if (!mounted) return;
      setState(() {
        _pricing = pricing;
        _services = (r[1] as List).map((e) => ServiceItem.fromJson(e as Map<String, dynamic>)).toList();
      });
      if (fillForm) {
        final s = pricing.settings;
        _margin.text = formatQuantity(s['targetMarginPercent'] as num);
        _fees.text = formatQuantity(s['cardFeePercent'] as num);
        _occupancy.text = formatQuantity(s['occupancyPercent'] as num);
        _fixed.text = s['fixedMonthlyCost'] == null ? '' : formatQuantity(s['fixedMonthlyCost'] as num);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  double? _n(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '.'));

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.api.put('/api/pricing/settings', {
        'targetMarginPercent': _n(_margin) ?? 20,
        'cardFeePercent': _n(_fees) ?? 0,
        'occupancyPercent': _n(_occupancy) ?? 70,
        'fixedMonthlyCost': _fixed.text.trim().isEmpty ? null : _n(_fixed),
      });
      await _load();
      if (mounted) showMessage(context, 'Preços recalculados');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _apply(ServicePricing p, double price) async {
    final s = _services.where((x) => x.id == p.serviceId).firstOrNull;
    if (s == null) return;
    if (!await confirmDialog(context, 'Mudar o preço de ${s.name} de ${formatMoney(s.price)} para ${formatMoney(price)}?',
        confirm: 'Aplicar')) {
      return;
    }
    try {
      await widget.api.put('/api/services/${s.id}', {
        'name': s.name,
        'description': s.description,
        'durationMinutes': s.durationMinutes,
        'price': price,
        'cost': s.cost,
        'active': s.active,
      });
      await _load();
      if (mounted) showMessage(context, 'Preço de ${s.name} atualizado');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _simulate(ServicePricing p) async {
    final ctrl = TextEditingController(text: formatQuantity(p.suggestedPrice ?? p.currentPrice));
    final apply = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        final price = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
        final r = p.simulate(price);
        final target = (_pricing!.settings['targetMarginPercent'] as num).toDouble();
        final color = r.profit < 0 ? const Color(0xFFBE123C) : (r.margin < target ? const Color(0xFFB45309) : const Color(0xFF15803D));
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, sheetBottomInset(context) + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Simular preço · ${p.name}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: r'Preço (R$)', prefixIcon: Icon(Icons.sell_outlined)),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(18)),
              child: Column(children: [
                Text(r.profit < 0 ? 'Prejuízo por atendimento' : 'Lucro por atendimento', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                Text(formatMoney(r.profit.abs()), style: TextStyle(color: color, fontSize: 30, fontWeight: FontWeight.w800)),
                Text('${r.margin.toStringAsFixed(1)}% do preço', style: TextStyle(color: color)),
              ]),
            ),
            const SizedBox(height: 16),
            GradientButton(label: 'Usar ${formatMoney(price)}', icon: Icons.check_rounded, onPressed: price > 0 ? () => Navigator.pop(context, price) : null),
          ]),
        );
      }),
    );
    if (apply != null) await _apply(p, apply);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = _pricing;
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            GradientHeader(
              gradient: Brand.nightGradient,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                IconButton(
                  tooltip: 'Voltar',
                  color: Colors.white,
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
                Text('Precificação', style: text.headlineSmall?.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text('Quanto cada serviço precisa custar para pagar tudo e ainda dar lucro.',
                    style: text.bodyMedium?.copyWith(color: Colors.white70)),
                if (p != null) ...[
                  const SizedBox(height: 16),
                  Row(children: [
                    _Mini('Custo fixo/mês', formatMoney(p.money('monthlyFixedCost'))),
                    const SizedBox(width: 8),
                    _Mini('Custo por hora', formatMoney(p.money('fixedCostPerHour'))),
                    const SizedBox(width: 8),
                    _Mini('Comissão média', '${formatQuantity(p.basis['averageCommissionPercent'] as num)}%'),
                  ]),
                ],
              ]),
            ),
            if (_error != null)
              ErrorRetry(message: _error!, onRetry: _load)
            else if (p == null)
              const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SoftCard(
                    padding: EdgeInsets.zero,
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        leading: const Icon(Icons.tune_rounded, color: Brand.rose),
                        title: Text('Seus parâmetros', style: text.titleSmall),
                        subtitle: Text('Lucro ${_margin.text}% · taxas ${_fees.text}% · ocupação ${_occupancy.text}%'),
                        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        children: [
                          _field(_margin, 'Lucro desejado (%)'),
                          _field(_fees, 'Taxa de cartão + impostos (%)'),
                          _field(_occupancy, 'Ocupação média da agenda (%)'),
                          _field(_fixed, r'Custo fixo mensal (R$)',
                              hint: 'Vazio = média das despesas (${formatMoney(p.basis['fixedCostFromExpenses'] == true ? p.money('monthlyFixedCost') : 0)})'),
                          const SizedBox(height: 4),
                          GradientButton(label: 'Recalcular', icon: Icons.calculate_outlined, loading: _saving, onPressed: _save),
                        ],
                      ),
                    ),
                  ),
                  if (p.services.isEmpty)
                    const EmptyState(icon: Icons.content_cut, title: 'Nenhum serviço', message: 'Cadastre serviços para ver a precificação.'),
                  for (final s in p.services)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _ServiceCard(
                        p: s,
                        target: (p.settings['targetMarginPercent'] as num).toDouble(),
                        onSimulate: () => _simulate(s),
                        // o sugerido é um piso: só oferece subir, nunca baixar um preço que já está acima
                        onApply: s.suggestedPrice != null && s.currentPrice < s.suggestedPrice! ? () => _apply(s, s.suggestedPrice!) : null,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Preço mínimo = custo direto ÷ (1 − comissão − taxas). Sugerido inclui o lucro desejado e é '
                    'arredondado de R\$ 5 em R\$ 5. Compare também com os preços da sua região.',
                    style: text.bodySmall?.copyWith(color: Brand.muted),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label, helperText: hint),
        ),
      );
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15))),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
          ]),
        ),
      );
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.p, required this.target, required this.onSimulate, required this.onApply});

  final ServicePricing p;
  final double target;
  final VoidCallback onSimulate;
  final VoidCallback? onApply;

  static (Color, Color) _healthColors(PricingHealth h) => switch (h) {
        PricingHealth.loss => (const Color(0xFFFFE4E6), const Color(0xFFBE123C)),
        PricingHealth.low => (const Color(0xFFFFF4DB), const Color(0xFFB45309)),
        PricingHealth.healthy => (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
        PricingHealth.noPrice => (const Color(0xFFF1F0F4), const Color(0xFF6B6880)),
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (bg, fg) = _healthColors(p.health);
    final variable = p.currentPrice * p.variablePercent / 100;
    final parts = [
      ('Material', p.materialCost, const Color(0xFF38BDF8)),
      ('Custo fixo', p.fixedCostShare, const Color(0xFF8E2DE2)),
      ('Comissão + taxas', variable, Brand.gold),
      (p.currentProfit >= 0 ? 'Lucro' : 'Prejuízo', p.currentProfit.abs(), p.currentProfit >= 0 ? const Color(0xFF10B981) : const Color(0xFFE11D48)),
    ];
    final total = parts.fold(0.0, (s, x) => s + x.$2);

    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ServiceIcon(p.name, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: text.titleMedium),
              Text(
                '${p.plannedMinutes} min${p.realAverageMinutes != null ? ' · ${p.realAverageMinutes} min reais' : ''}'
                ' · ${formatMoney(p.profitPerHour)}/h',
                style: text.bodySmall?.copyWith(color: Brand.muted),
              ),
            ]),
          ),
          Pill(p.health.label, color: bg, textColor: fg),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _Value('Atual', formatMoney(p.currentPrice),
              p.currentMarginPercent != null ? '${formatQuantity(p.currentMarginPercent!)}% lucro' : null),
          _Value('Mínimo', p.breakEvenPrice != null ? formatMoney(p.breakEvenPrice!) : '—', 'lucro zero'),
          _Value('Sugerido', p.suggestedPrice != null ? formatMoney(p.suggestedPrice!) : '—', '${formatQuantity(target)}% lucro',
              highlight: true),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 10,
            child: Row(children: [
              for (final x in parts)
                if (x.$2 > 0) Expanded(flex: (x.$2 / (total == 0 ? 1 : total) * 1000).round().clamp(1, 1000), child: Container(color: x.$3)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 12, runSpacing: 4, children: [
          for (final x in parts)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: x.$3, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text('${x.$1} ${formatMoney(x.$2)}', style: text.bodySmall?.copyWith(color: Brand.muted)),
            ]),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(onPressed: onSimulate, icon: const Icon(Icons.calculate_outlined), label: const Text('Simular')),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: onApply != null
                ? GradientButton(label: 'Subir preço', icon: Icons.trending_up_rounded, onPressed: onApply)
                : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 18),
                    SizedBox(width: 6),
                    Flexible(child: Text('Preço já cobre o sugerido', style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w700))),
                  ]),
          ),
        ]),
      ]),
    );
  }
}

class _Value extends StatelessWidget {
  const _Value(this.label, this.value, this.hint, {this.highlight = false});

  final String label;
  final String value;
  final String? hint;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: highlight ? Brand.gradient : null,
            color: highlight ? null : const Color(0xFFFFF7FA),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: highlight ? Colors.white70 : Brand.muted)),
            FittedBox(
              child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: highlight ? Colors.white : Brand.ink)),
            ),
            if (hint != null) Text(hint!, style: TextStyle(fontSize: 10, color: highlight ? Colors.white70 : Brand.muted)),
          ]),
        ),
      );
}
