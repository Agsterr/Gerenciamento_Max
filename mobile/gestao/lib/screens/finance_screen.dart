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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financeiro'),
        actions: [
          TextButton.icon(
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range),
            label: Text('${formatDate(_range.start).substring(0, 5)}–${formatDate(_range.end).substring(0, 5)}'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'expense',
        onPressed: _addExpense,
        icon: const Icon(Icons.add),
        label: const Text('Despesa'),
      ),
      body: _error != null
          ? ErrorRetry(message: _error!, onRetry: _load)
          : s == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.7,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: [
                          _Stat('Receita', formatMoney(s.money('totalRevenue'))),
                          _Stat('Custos', formatMoney(s.money('totalCosts'))),
                          _Stat('Lucro', formatMoney(s.money('profit')), highlight: true),
                          _Stat('Ticket médio', formatMoney(s.money('averageTicket'))),
                        ],
                      ),
                      _Section('Custos', [
                        _Row('Comissões', formatMoney(s.money('commissions'))),
                        _Row('Material dos serviços', formatMoney(s.money('serviceMaterialCost'))),
                        _Row('Produtos usados/perdidos', formatMoney(s.money('productsUsedCost'))),
                        _Row('Custo dos produtos vendidos', formatMoney(s.money('productsSoldCost'))),
                        _Row('Despesas', formatMoney(s.money('expenses'))),
                      ]),
                      _Section('Operação', [
                        _Row('Atendimentos finalizados', '${s.count('appointmentsDone')}'),
                        _Row('Agendamentos online', '${s.count('onlineBookings')}'),
                        _Row('Cancelados / faltas', '${s.count('appointmentsCanceled')} / ${s.count('appointmentsNoShow')}'),
                        _Row('Tempo médio previsto', _minutes(s.minutes('averageEstimatedMinutes'))),
                        _Row('Tempo médio real', _minutes(s.minutes('averageRealMinutes'))),
                      ]),
                      _Section('Por profissional', [
                        if (s.byProfessional.isEmpty) const Text('Sem atendimentos no período.'),
                        for (final r in s.byProfessional)
                          _Row('${r.name} (${r.count})', '${formatMoney(r.revenue)} · comissão ${formatMoney(r.commission)}'),
                      ]),
                      _Section('Por serviço', [
                        if (s.byService.isEmpty) const Text('Sem atendimentos no período.'),
                        for (final r in s.byService) _Row('${r.name} (${r.count})', formatMoney(r.revenue)),
                      ]),
                      if (s.lowStock.isNotEmpty)
                        _Section('Estoque baixo', [
                          for (final p in s.lowStock)
                            _Row(p['name'] as String, '${formatQuantity(p['stock'] as num)} ${p['unit']}'),
                        ]),
                      _Section('Despesas', [
                        if (_expenses.isEmpty) const Text('Nenhuma despesa no período.'),
                        for (final e in _expenses)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(e.description),
                            subtitle: Text('${formatDate(e.date)} · ${e.category}'),
                            trailing: Text(formatMoney(e.amount)),
                            onLongPress: () => _deleteExpense(e),
                          ),
                        if (_expenses.isNotEmpty)
                          Text('Toque e segure para excluir.', style: Theme.of(context).textTheme.bodySmall),
                      ]),
                    ],
                  ),
                ),
    );
  }

  static String _minutes(double? m) => m == null ? '—' : '${m.round()} min';
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.highlight = false});

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: highlight ? scheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            FittedBox(child: Text(value, style: Theme.of(context).textTheme.titleLarge)),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}
