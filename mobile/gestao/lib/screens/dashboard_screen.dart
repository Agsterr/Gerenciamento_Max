import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:salao_core/salao_core.dart';

import '../dashboard_period.dart';
import '../session.dart';

/// Painel de atendimentos: quantos foram concluídos, cancelados, faltas, refações e clientes,
/// por semana, mês, ano ou datas escolhidas, com gráfico e comparação com o período anterior.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.session});

  final Session session;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with AutomaticKeepAliveClientMixin {
  Period _period = Period.of(PeriodKind.month, DateTime.now());
  AttendanceDashboard? _data;
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
    final asked = _period;
    try {
      final json = await widget.session.api
          .get('/api/reports/dashboard?from=${isoDate(asked.from)}&to=${isoDate(asked.to)}&group=${asked.group}');
      if (mounted && asked == _period) setState(() => _data = AttendanceDashboard.fromJson(json as Map<String, dynamic>));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _set(Period p) {
    setState(() {
      _period = p;
      _data = null;
    });
    _load();
  }

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _period.from, end: _period.to),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (r != null) _set(Period(PeriodKind.custom, r.start, r.end));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final text = Theme.of(context).textTheme;
    final d = _data;
    final now = DateTime.now();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final (label, kind) in [
              ('Hoje', PeriodKind.day),
              ('Semana', PeriodKind.week),
              ('Mês', PeriodKind.month),
              ('Ano', PeriodKind.year),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: _period.kind == kind,
                  onSelected: (_) => _set(Period.of(kind, now)),
                ),
              ),
            ChoiceChip(
              avatar: const Icon(Icons.date_range_rounded, size: 18),
              label: const Text('Escolher'),
              selected: _period.kind == PeriodKind.custom,
              onSelected: (_) => _pickRange(),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Row(children: [
          IconButton(tooltip: 'Anterior', icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _set(_period.shift(-1))),
          Expanded(child: Text(_period.label, textAlign: TextAlign.center, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
          IconButton(tooltip: 'Seguinte', icon: const Icon(Icons.chevron_right_rounded), onPressed: () => _set(_period.shift(1))),
        ]),
        if (_error != null)
          ErrorRetry(message: _error!, onRetry: _load)
        else if (d == null)
          const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
        else ...[
          const SizedBox(height: 8),
          _Totals(data: d, period: _period),
          const SectionTitle('Ao longo do período'),
          SoftCard(child: _Chart(buckets: d.series, group: _period.group)),
          const SectionTitle('Clientes'),
          Row(children: [
            Expanded(child: _Stat(Icons.groups_rounded, 'Atendidos', d.totals.uniqueCustomers, hint: 'clientes diferentes')),
            const SizedBox(width: 12),
            Expanded(child: _Stat(Icons.replay_rounded, 'Voltaram', d.totals.returningCustomers, hint: 'já eram clientes')),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _Stat(Icons.person_add_alt_1_rounded, 'Novos', d.totals.newCustomers, hint: 'cadastrados')),
            const SizedBox(width: 12),
            Expanded(child: _Stat(Icons.smartphone_rounded, 'Pelo app', d.totals.online, hint: 'agendados online')),
          ]),
          const SectionTitle('Por profissional'),
          _Professionals(rows: d.byProfessional),
        ],
      ]),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.data, required this.period});

  final AttendanceDashboard data;
  final Period period;

  @override
  Widget build(BuildContext context) {
    final t = data.totals, p = data.previous;
    final text = Theme.of(context).textTheme;
    Widget tile(String label, int value, int before, IconData icon, Color color, {bool goodWhenUp = true}) =>
        Expanded(child: _Stat(icon, label, value, color: color, delta: _delta(value, before, goodWhenUp), hint: period.previousLabel));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(gradient: Brand.nightGradient, borderRadius: BorderRadius.circular(24)),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Atendimentos concluídos', style: text.bodyMedium?.copyWith(color: Colors.white70)),
              Text('${t.done}', style: text.displaySmall?.copyWith(color: Colors.white, fontSize: 44)),
              Text('de ${t.total} agendamentos${t.rework > 0 ? ' · ${t.rework} refação(ões)' : ''}',
                  style: text.bodySmall?.copyWith(color: Colors.white70)),
            ]),
          ),
          if (_delta(t.done, p.done, true) case final d?)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Text(d.text, style: TextStyle(color: d.color, fontWeight: FontWeight.w800, fontSize: 16)),
                Text(period.previousLabel, style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        tile('Cancelados', t.canceled, p.canceled, Icons.event_busy_rounded, const Color(0xFFE11D48), goodWhenUp: false),
        const SizedBox(width: 12),
        tile('Faltas', t.noShow, p.noShow, Icons.person_off_outlined, const Color(0xFFF59E0B), goodWhenUp: false),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _Stat(Icons.schedule_rounded, 'Por fazer', t.scheduled, color: const Color(0xFF6366F1), hint: 'marcados')),
        const SizedBox(width: 12),
        Expanded(
          child: _Stat(Icons.percent_rounded, 'Cancelamento', t.cancelRate.round(), color: const Color(0xFFE11D48), suffix: '%',
              hint: 'dos agendamentos'),
        ),
      ]),
    ]);
  }
}

class _Delta {
  const _Delta(this.text, this.color);

  final String text;
  final Color color;
}

/// Variação sobre o período anterior ("+12%", "−3"); nulo sem base de comparação.
_Delta? _delta(int now, int before, bool goodWhenUp) {
  if (before == 0 && now == 0) return null;
  final up = now >= before;
  final good = up == goodWhenUp || now == before;
  final color = now == before ? const Color(0xFF94A3B8) : (good ? const Color(0xFF34D399) : const Color(0xFFFB7185));
  final text = before == 0 ? '+$now' : '${up ? '+' : '−'}${((now - before).abs() * 100 / before).round()}%';
  return _Delta(text, color);
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.label, this.value, {this.color = Brand.rose, this.hint, this.delta, this.suffix = ''});

  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final String? hint;
  final _Delta? delta;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('$value$suffix', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              if (delta != null) ...[
                const SizedBox(width: 6),
                Text(delta!.text, style: TextStyle(color: delta!.color, fontWeight: FontWeight.w800, fontSize: 12)),
              ],
            ]),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall?.copyWith(color: Brand.muted)),
          ]),
        ),
      ]),
    );
  }
}

/// Barras empilhadas por dia, semana ou mês: concluídos, cancelados, faltas e por fazer.
class _Chart extends StatelessWidget {
  const _Chart({required this.buckets, required this.group});

  final List<AttendanceBucket> buckets;
  final String group;

  static const _done = Color(0xFF10B981);
  static const _canceled = Color(0xFFE11D48);
  static const _noShow = Color(0xFFF59E0B);
  static const _scheduled = Color(0xFFC7D2FE);

  String _label(AttendanceBucket b) => switch (group) {
        'MONTH' => DateFormat('MMM', 'pt_BR').format(b.start).replaceAll('.', ''),
        'WEEK' => DateFormat('d/M').format(b.start),
        _ => '${b.start.day}',
      };

  @override
  Widget build(BuildContext context) {
    final max = buckets.fold(0, (m, b) => b.total > m ? b.total : m);
    if (max == 0) {
      return const Padding(padding: EdgeInsets.all(12), child: Text('Nenhum agendamento neste período.'));
    }
    // poucos pontos: números em cima; muitos (mês inteiro): só os dias de 5 em 5
    final many = buckets.length > 16;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 140,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final b in buckets)
            Expanded(
              child: Tooltip(
                message: '${_label(b)}: ${b.done} concluídos, ${b.canceled} cancelados, ${b.noShow} faltas, ${b.scheduled} por fazer',
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: many ? 1 : 4),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (!many && b.total > 0)
                      Text('${b.total}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    for (final (n, color) in [(b.scheduled, _scheduled), (b.noShow, _noShow), (b.canceled, _canceled), (b.done, _done)])
                      if (n > 0) Container(height: 110 * n / max, color: color),
                  ]),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 4),
      Row(children: [
        for (final (i, b) in buckets.indexed)
          Expanded(
            child: Text(
              !many || i % 5 == 0 ? _label(b) : '',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: const TextStyle(fontSize: 10, color: Brand.muted),
            ),
          ),
      ]),
      const SizedBox(height: 10),
      const Wrap(spacing: 14, runSpacing: 4, children: [
        _Legend('Concluídos', _done),
        _Legend('Cancelados', _canceled),
        _Legend('Faltas', _noShow),
        _Legend('Por fazer', _scheduled),
      ]),
    ]);
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12, color: Brand.muted)),
      ]);
}

class _Professionals extends StatelessWidget {
  const _Professionals({required this.rows});

  final List<ProfessionalAttendance> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SoftCard(child: Text('Sem agendamentos no período.'));
    final text = Theme.of(context).textTheme;
    return SoftCard(
      child: Column(children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              InitialsAvatar(r.name, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.name, style: text.titleSmall),
                  Wrap(spacing: 10, children: [
                    Text('${r.done} concluídos', style: text.bodySmall?.copyWith(color: const Color(0xFF15803D), fontWeight: FontWeight.w700)),
                    if (r.canceled > 0) Text('${r.canceled} cancelados', style: text.bodySmall?.copyWith(color: const Color(0xFFBE123C))),
                    if (r.noShow > 0) Text('${r.noShow} faltas', style: text.bodySmall?.copyWith(color: const Color(0xFFB45309))),
                    if (r.rework > 0) Text('${r.rework} refações', style: text.bodySmall?.copyWith(color: Brand.muted)),
                    if (r.scheduled > 0) Text('${r.scheduled} por fazer', style: text.bodySmall?.copyWith(color: Brand.muted)),
                  ]),
                ]),
              ),
              Text('${r.total}', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            ]),
          ),
      ]),
    );
  }
}
