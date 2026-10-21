import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../session.dart';
import 'pricing_screen.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key, required this.session});

  final Session session;

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  static const _fixed = ['Aluguel', 'Água', 'Luz', 'Internet e telefone', 'Salários', 'Contador', 'Sistemas e assinaturas'];
  static const _variable = [
    'Produtos e materiais',
    'Cortesias (café, água, lanches)',
    'Marketing',
    'Manutenção',
    'Impostos e taxas',
    'Outros',
  ];

  late DateTimeRange _range = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month),
    end: dateOnly(DateTime.now()),
  );
  Summary? _summary;
  List<Expense> _expenses = [];
  String? _error;

  ApiClient get _api => widget.session.api;
  String get _query => 'from=${isoDate(_range.start)}&to=${isoDate(_range.end)}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Future.wait([_api.get('/api/reports/summary?$_query'), _api.get('/api/expenses?$_query')]);
      if (!mounted) return;
      setState(() {
        _summary = Summary(r[0] as Map<String, dynamic>);
        _expenses = (r[1] as List).map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (r != null) {
      setState(() => _range = r);
      _load();
    }
  }

  Future<void> _addExpense() async {
    final description = TextEditingController();
    final amount = TextEditingController();
    var category = _fixed.first;
    var date = dateOnly(DateTime.now());
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nova despesa'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: description, decoration: const InputDecoration(labelText: 'Descrição')),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Categoria'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(enabled: false, child: Text('FIXAS (TODO MÊS)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Brand.muted))),
                  for (final c in _fixed) DropdownMenuItem(value: c, child: Text(c)),
                  const DropdownMenuItem(enabled: false, child: Text('VARIÁVEIS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Brand.muted))),
                  for (final c in _variable) DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: (v) => setState(() => category = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: r'Valor (R$)'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text(formatDate(date)),
                onPressed: () async {
                  final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2024), lastDate: DateTime(2100));
                  if (d != null) setState(() => date = d);
                },
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _api.post('/api/expenses', {
        'description': description.text.trim(),
        'category': category,
        'amount': double.tryParse(amount.text.replaceAll(',', '.')) ?? 0,
        'date': isoDate(date),
      });
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  /// Lança no mês do fim do período as despesas fixas do mês anterior (aluguel, água, luz...).
  Future<void> _repeatFixed() async {
    final month = isoDate(_range.end).substring(0, 7);
    try {
      final r = await _api.post('/api/expenses/repeat-fixed', {'month': month}) as Map<String, dynamic>;
      final created = r['created'] as int;
      if (mounted) {
        showMessage(context, created == 0 ? 'As fixas do mês anterior já estão lançadas.' : '$created despesa(s) fixa(s) lançada(s).');
      }
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _deleteExpense(Expense e) async {
    if (!await confirmDialog(context, 'Excluir "${e.description}"?', confirm: 'Excluir', danger: true)) return;
    try {
      await _api.delete('/api/expenses/${e.id}');
      _load();
    } catch (err) {
      if (mounted) showError(context, err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      floatingActionButton: SizedBox(
        width: 160,
        child: GradientButton(label: 'Despesa', icon: Icons.add_rounded, onPressed: _addExpense),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            GradientHeader(
              gradient: Brand.nightGradient,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('Financeiro e relatórios', style: text.headlineSmall?.copyWith(color: Colors.white))),
                  Material(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _pickRange,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(children: [
                          const Icon(Icons.date_range_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text('${formatDate(_range.start).substring(0, 5)} – ${formatDate(_range.end).substring(0, 5)}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 22),
                Text('Lucro do período', style: text.bodyMedium?.copyWith(color: Colors.white70)),
                const SizedBox(height: 2),
                Text(s == null ? '—' : formatMoney(s.money('profit')),
                    style: text.displaySmall?.copyWith(color: Colors.white, fontSize: 40)),
                const SizedBox(height: 16),
                if (s != null) ...[
                  Row(children: [
                    _HeaderStat(label: 'Receita', value: formatMoney(s.money('totalRevenue')), icon: Icons.trending_up_rounded, color: const Color(0xFF6EE7B7)),
                    const SizedBox(width: 10),
                    _HeaderStat(label: 'Custos', value: formatMoney(s.money('totalCosts')), icon: Icons.trending_down_rounded, color: const Color(0xFFFDA4AF)),
                  ]),
                  const SizedBox(height: 10),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PricingScreen(api: _api))),
                      child: const Padding(
                        padding: EdgeInsets.all(14),
                        child: Row(children: [
                          Icon(Icons.calculate_rounded, color: Brand.rose),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text('Precificação: descubra o preço certo de cada serviço',
                                style: TextStyle(fontWeight: FontWeight.w800, color: Brand.ink)),
                          ),
                          Icon(Icons.arrow_forward_rounded, color: Brand.rose),
                        ]),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
            if (_error != null)
              ErrorRetry(message: _error!, onRetry: _load)
            else if (s == null)
              const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.9,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      _Stat(Icons.receipt_long_rounded, 'Ticket médio', formatMoney(s.money('averageTicket'))),
                      _Stat(Icons.event_available_rounded, 'Atendimentos', '${s.count('appointmentsDone')}'),
                      _Stat(Icons.smartphone_rounded, 'Agendados online', '${s.count('onlineBookings')}'),
                      _Stat(Icons.timer_outlined, 'Tempo real médio', _minutes(s.minutes('averageRealMinutes'))),
                    ],
                  ),
                  const SectionTitle('Receitas'),
                  SoftCard(
                    child: Column(children: [
                      _Line('Serviços', s.money('servicesRevenue')),
                      _Line('Venda de produtos', s.money('productSalesRevenue')),
                      const Divider(),
                      _Line('Total', s.money('totalRevenue'), bold: true, color: const Color(0xFF15803D)),
                    ]),
                  ),
                  const SectionTitle('Para onde vai o dinheiro'),
                  SoftCard(
                    child: Column(children: [
                      for (final (label, value, color) in [
                        ('Custos dos atendimentos', s.money('commissions') + s.money('serviceMaterialCost') + s.money('productsUsedCost'), Brand.rose),
                        ('Despesas fixas', s.money('fixedExpenses'), const Color(0xFF6366F1)),
                        ('Despesas variáveis', s.money('variableExpenses'), const Color(0xFF8E2DE2)),
                        ('Custo dos produtos vendidos', s.money('productsSoldCost'), const Color(0xFFFFB547)),
                      ])
                        _Bar(label: label, value: value, total: s.money('totalCosts'), color: color),
                    ]),
                  ),
                  const SectionTitle('Custos dos atendimentos'),
                  SoftCard(
                    child: Column(children: [
                      _Line('Comissões', s.money('commissions')),
                      _Line('Material dos serviços', s.money('serviceMaterialCost')),
                      _Line('Produtos usados e perdas', s.money('productsUsedCost')),
                    ]),
                  ),
                  SectionTitle('Despesas fixas', trailing: Text(formatMoney(s.money('fixedExpenses')), style: text.titleSmall)),
                  _CategoryCard(values: s.byCategory('fixedByCategory'), empty: 'Nenhuma despesa fixa (aluguel, água, luz...) no período.'),
                  SectionTitle('Despesas variáveis', trailing: Text(formatMoney(s.money('variableExpenses')), style: text.titleSmall)),
                  _CategoryCard(values: s.byCategory('variableByCategory'), empty: 'Nenhuma despesa variável no período.'),
                  _ReworkSection(rework: s.rework),
                  const SectionTitle('Produtos'),
                  _ProductsCard(rows: s.products),
                  const SectionTitle('Ranking de profissionais'),
                  _RankingCard(rows: s.byProfessional, showCommission: true),
                  const SectionTitle('Serviços que mais faturam'),
                  _RankingCard(rows: s.byService),
                  if (s.lowStock.isNotEmpty) ...[
                    const SectionTitle('Estoque baixo'),
                    SoftCard(
                      color: const Color(0xFFFFF1F2),
                      child: Column(children: [
                        for (final p in s.lowStock)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.warning_amber_rounded, color: Color(0xFFBE123C)),
                            title: Text(p['name'] as String),
                            trailing: Text('${formatQuantity(p['stock'] as num)} ${p['unit']}',
                                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFBE123C))),
                          ),
                      ]),
                    ),
                  ],
                  SectionTitle('Despesas lançadas',
                      trailing: TextButton.icon(
                        onPressed: _repeatFixed,
                        icon: const Icon(Icons.repeat_rounded, size: 18),
                        label: const Text('Repetir fixas'),
                      )),
                  if (_expenses.isEmpty)
                    const SoftCard(child: Text('Nenhuma despesa no período.'))
                  else
                    SoftCard(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(children: [
                        for (final e in _expenses)
                          ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.receipt_outlined, color: Color(0xFF7C3AED)),
                            ),
                            title: Text(e.description, style: text.titleSmall),
                            subtitle: Text('${formatDate(e.date)} · ${e.category}${e.fixed ? ' · fixa' : ''}'),
                            trailing: Text(formatMoney(e.amount), style: text.titleSmall),
                            onLongPress: () => _deleteExpense(e),
                          ),
                      ]),
                    ),
                  if (_expenses.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Toque e segure para excluir.', textAlign: TextAlign.center, style: text.bodySmall?.copyWith(color: Brand.muted)),
                    ),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  static String _minutes(double? m) => m == null ? '—' : '${m.round()} min';
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.label, required this.value, required this.icon, required this.color});

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                FittedBox(child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
              ]),
            ),
          ]),
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => SoftCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: const Color(0xFFFFEAF2), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Brand.rose, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              FittedBox(child: Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Brand.muted)),
            ]),
          ),
        ]),
      );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.label, required this.value, required this.total, required this.color});

  final String label;
  final double value;
  final double total;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(formatMoney(value), style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: total > 0 ? (value / total).clamp(0, 1) : 0,
              minHeight: 8,
              backgroundColor: const Color(0xFFF6EEF3),
              color: color,
            ),
          ),
        ]),
      );
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({required this.rows, this.showCommission = false});

  final List<Ranking> rows;
  final bool showCommission;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SoftCard(child: Text('Sem atendimentos no período.'));
    final max = rows.map((r) => r.revenue).fold(0.0, (a, b) => a > b ? a : b);
    final text = Theme.of(context).textTheme;
    return SoftCard(
      child: Column(children: [
        for (final (i, r) in rows.indexed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Stack(clipBehavior: Clip.none, children: [
                InitialsAvatar(r.name, size: 40),
                if (i == 0)
                  const Positioned(right: -4, top: -6, child: Icon(Icons.workspace_premium_rounded, color: Brand.gold, size: 20)),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(r.name, style: text.titleSmall)),
                    Text(formatMoney(r.revenue), style: text.titleSmall?.copyWith(color: Brand.rose)),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: max > 0 ? r.revenue / max : 0,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFF6EEF3),
                      color: Brand.rose,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${r.count} atendimento(s)${showCommission ? ' · comissão ${formatMoney(r.commission)}' : ''}',
                    style: text.bodySmall?.copyWith(color: Brand.muted),
                  ),
                ]),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.bold = false, this.color});

  final String label;
  final double value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: color);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(child: Text(label, style: style)),
        Text(formatMoney(value), style: style),
      ]),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.values, required this.empty});

  final Map<String, double> values;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return SoftCard(child: Text(empty));
    return SoftCard(child: Column(children: [for (final e in values.entries) _Line(e.key, e.value)]));
  }
}

/// Refações: cliente voltou para refazer e não pagou; só gera custo.
class _ReworkSection extends StatelessWidget {
  const _ReworkSection({required this.rework});

  final Map<String, dynamic> rework;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final count = rework['count'] as int? ?? 0;
    final items = ((rework['items'] as List?) ?? const []).cast<Map<String, dynamic>>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle('Refações', trailing: Text(formatMoney((rework['totalCost'] as num? ?? 0).toDouble()), style: text.titleSmall)),
      SoftCard(
        child: count == 0
            ? const Text('Nenhuma refação no período. Marque "Refação" ao finalizar quando o cliente voltar para refazer.')
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    const Expanded(child: Text('Quantidade', style: TextStyle(fontWeight: FontWeight.w600))),
                    Text('$count', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ]),
                ),
                _Line('Material dos serviços', (rework['materialCost'] as num).toDouble()),
                _Line('Produtos usados', (rework['productsCost'] as num).toDouble()),
                const Divider(),
                for (final i in items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(
                        child: Text('${formatDate(DateTime.parse(i['startAt'] as String))} · ${i['customer']} · ${i['service']}',
                            style: text.bodySmall, maxLines: 2),
                      ),
                      Text(formatMoney((i['cost'] as num).toDouble()), style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                    ]),
                  ),
              ]),
      ),
    ]);
  }
}

/// Vendas, uso e estoque de cada produto no período.
class _ProductsCard extends StatelessWidget {
  const _ProductsCard({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (rows.isEmpty) return const SoftCard(child: Text('Nenhum produto cadastrado.'));
    double n(Map<String, dynamic> r, String k) => (r[k] as num? ?? 0).toDouble();
    final stockValue = rows.fold(0.0, (t, r) => t + n(r, 'stockValue'));
    final profit = rows.fold(0.0, (t, r) => t + n(r, 'salesProfit'));
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final r in rows) ...[
          Row(children: [
            Expanded(child: Text(r['name'] as String, style: text.titleSmall)),
            if (r['lowStock'] == true) const Icon(Icons.warning_amber_rounded, color: Color(0xFFBE123C), size: 18),
          ]),
          const SizedBox(height: 2),
          Text(
            'Pago ${formatMoney(n(r, 'costPrice'))}'
            '${n(r, 'salePrice') > 0 ? ' · venda ${formatMoney(n(r, 'salePrice'))}' : ' · uso interno'}'
            ' · estoque ${formatQuantity(n(r, 'stock'))} ${r['unit']} (${formatMoney(n(r, 'stockValue'))})',
            style: text.bodySmall?.copyWith(color: Brand.muted),
          ),
          if (n(r, 'soldQuantity') > 0 || n(r, 'usedQuantity') > 0 || n(r, 'lostQuantity') > 0)
            Text(
              [
                if (n(r, 'soldQuantity') > 0)
                  'vendeu ${formatQuantity(n(r, 'soldQuantity'))} = ${formatMoney(n(r, 'salesRevenue'))} (lucro ${formatMoney(n(r, 'salesProfit'))})',
                if (n(r, 'usedQuantity') > 0) 'usou ${formatQuantity(n(r, 'usedQuantity'))} (${formatMoney(n(r, 'usedCost'))})',
                if (n(r, 'lostQuantity') > 0) 'perdas ${formatQuantity(n(r, 'lostQuantity'))} (${formatMoney(n(r, 'lostCost'))})',
              ].join(' · '),
              style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          const Divider(height: 18),
        ],
        _Line('Lucro com vendas de produtos', profit, bold: true),
        _Line('Valor parado em estoque (preço pago)', stockValue),
      ]),
    );
  }
}
