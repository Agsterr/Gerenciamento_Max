import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../session.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key, required this.session});

  final Session session;

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  static const _categories = ['Aluguel', 'Energia/Água', 'Salários', 'Produtos', 'Marketing', 'Impostos', 'Outros'];

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
    var category = _categories.first;
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
                items: [for (final c in _categories) DropdownMenuItem(value: c, child: Text(c))],
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
                  Expanded(child: Text('Financeiro', style: text.headlineSmall?.copyWith(color: Colors.white))),
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
                if (s != null)
                  Row(children: [
                    _HeaderStat(label: 'Receita', value: formatMoney(s.money('totalRevenue')), icon: Icons.trending_up_rounded, color: const Color(0xFF6EE7B7)),
                    const SizedBox(width: 10),
                    _HeaderStat(label: 'Custos', value: formatMoney(s.money('totalCosts')), icon: Icons.trending_down_rounded, color: const Color(0xFFFDA4AF)),
                  ]),
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
                  const SectionTitle('Para onde vai o dinheiro'),
                  SoftCard(
                    child: Column(children: [
                      for (final (label, key, color) in [
                        ('Despesas', 'expenses', const Color(0xFF8E2DE2)),
                        ('Comissões', 'commissions', Brand.rose),
                        ('Custo dos produtos vendidos', 'productsSoldCost', const Color(0xFFFFB547)),
                        ('Material dos serviços', 'serviceMaterialCost', const Color(0xFF38BDF8)),
                        ('Produtos usados/perdidos', 'productsUsedCost', const Color(0xFF10B981)),
                      ])
                        _Bar(label: label, value: s.money(key), total: s.money('totalCosts'), color: color),
                    ]),
                  ),
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
                  SectionTitle('Despesas', trailing: Text(formatMoney(s.money('expenses')), style: text.titleSmall)),
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
                            subtitle: Text('${formatDate(e.date)} · ${e.category}'),
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
