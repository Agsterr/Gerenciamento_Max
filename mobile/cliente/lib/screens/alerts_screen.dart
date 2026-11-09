import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../alert_log.dart';
import '../booking_store.dart';
import '../confirm_reminders.dart';
import '../promo_alerts.dart';
import 'booking_screen.dart';
import 'salon_screen.dart';

enum _Status { all, unread, read }

enum _Period { all, today, week, month, custom }

/// Avisos que o app mostrou (horário confirmado/cancelado/alterado, promoções), guardados neste aparelho:
/// separados em lidos e não lidos, com filtro por dia ou período, e dá para apagar os já lidos.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, required this.store, required this.api});

  final BookingStore store;
  final ApiClient api;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  static const _step = 20;

  List<AlertItem> _all = [];
  bool _loading = true;
  bool _hadUnread = false;
  int _shown = _step;

  _Status _status = _Status.all;
  _Period _period = _Period.all;
  DateTimeRange? _custom;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    // ao sair da tela, o que foi exibido conta como lido
    if (_hadUnread) AlertLog.markAllRead();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await AlertLog.all();
    if (!mounted) return;
    setState(() {
      _all = items;
      _loading = false;
      if (items.any((i) => !i.read)) _hadUnread = true;
    });
  }

  DateTimeRange? get _range {
    final today = dateOnly(DateTime.now());
    return switch (_period) {
      _Period.all => null,
      _Period.today => DateTimeRange(start: today, end: today),
      _Period.week => DateTimeRange(start: today.subtract(const Duration(days: 6)), end: today),
      _Period.month => DateTimeRange(start: DateTime(today.year, today.month), end: today),
      _Period.custom => _custom,
    };
  }

  List<AlertItem> get _filtered {
    final r = _range;
    return _all.where((i) {
      if (_status == _Status.unread && i.read) return false;
      if (_status == _Status.read && !i.read) return false;
      if (r != null) {
        final d = dateOnly(i.at);
        if (d.isBefore(r.start) || d.isAfter(r.end)) return false;
      }
      return true;
    }).toList();
  }

  int get _unread => _all.where((i) => !i.read).length;

  void _setStatus(_Status s) => setState(() {
        _status = s;
        _shown = _step;
      });

  void _setPeriod(_Period p) => setState(() {
        _period = p;
        _shown = _step;
      });

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
      initialDateRange: _custom,
      helpText: 'Escolha um dia ou um período',
    );
    if (picked == null) return;
    setState(() {
      _custom = picked;
      _period = _Period.custom;
      _shown = _step;
    });
  }

  Future<void> _markAllRead() async {
    await AlertLog.markAllRead();
    _hadUnread = false;
    await _load();
  }

  Future<void> _clearRead() async {
    if (!await confirmDialog(context, 'Apagar todos os avisos já lidos? Não dá para desfazer.', confirm: 'Apagar lidos', danger: true)) return;
    final n = await AlertLog.clearRead();
    if (mounted) showMessage(context, '$n aviso(s) apagado(s).');
    await _load();
  }

  Future<void> _delete(AlertItem item) async {
    setState(() => _all = _all.where((i) => i.id != item.id).toList());
    await AlertLog.delete(item.id);
  }

  void _open(AlertItem item) {
    final booking = LocalReminders.payloadOf(item.payload, confirmGroup)?.split('/');
    if (booking != null && booking.length == 2) {
      final saved = widget.store.bookings.where((b) => b.token == booking[1]).firstOrNull;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingScreen(slug: booking[0], token: booking[1], api: widget.api, salonName: saved?.salonName),
        ),
      );
      return;
    }
    final promo = LocalReminders.payloadOf(item.payload, promoGroup);
    if (promo != null) {
      final [slug, service, ...] = '$promo/'.split('/');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SalonScreen(slug: slug, store: widget.store, api: widget.api, initialServiceId: int.tryParse(service)),
        ),
      );
    }
  }

  static (IconData, Color) _style(String kind) =>
      kind == 'promo' ? (Icons.local_offer_rounded, const Color(0xFFD97706)) : (Icons.event_available_rounded, const Color(0xFF047857));

  static String _dayLabel(DateTime d) {
    final today = dateOnly(DateTime.now());
    final day = dateOnly(d);
    if (day == today) return 'Hoje';
    if (day == today.subtract(const Duration(days: 1))) return 'Ontem';
    return formatWeekday(day);
  }

  String get _periodLabel {
    final r = _custom;
    if (r == null) return 'Escolher data';
    final a = formatDate(r.start).substring(0, 5), b = formatDate(r.end).substring(0, 5);
    return r.start == r.end ? a : '$a – $b';
  }

  Widget _chip(String label, bool selected, VoidCallback onTap, {IconData? icon}) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: icon == null ? null : Icon(icon, size: 18),
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );

  Widget _filters() => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _chip('Todos', _status == _Status.all, () => _setStatus(_Status.all)),
              _chip(_unread > 0 ? 'Não lidos ($_unread)' : 'Não lidos', _status == _Status.unread, () => _setStatus(_Status.unread)),
              _chip('Lidos', _status == _Status.read, () => _setStatus(_Status.read)),
            ]),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _chip('Todos os dias', _period == _Period.all, () => _setPeriod(_Period.all)),
              _chip('Hoje', _period == _Period.today, () => _setPeriod(_Period.today)),
              _chip('7 dias', _period == _Period.week, () => _setPeriod(_Period.week)),
              _chip('Este mês', _period == _Period.month, () => _setPeriod(_Period.month)),
              _chip(_periodLabel, _period == _Period.custom, _pickRange, icon: Icons.calendar_month_rounded),
            ]),
          ),
        ]),
      );

  Widget _card(AlertItem n) {
    final text = Theme.of(context).textTheme;
    final (icon, color) = _style(n.kind);
    return SoftCard(
      padding: const EdgeInsets.all(14),
      onTap: n.payload.isEmpty ? null : () => _open(n),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(n.title, style: text.titleSmall)),
              if (!n.read) Container(width: 10, height: 10, decoration: const BoxDecoration(color: Brand.rose, shape: BoxShape.circle)),
            ]),
            if (n.body.isNotEmpty) ...[const SizedBox(height: 2), Text(n.body, style: text.bodyMedium)],
            const SizedBox(height: 4),
            Text(formatTime(n.at), style: text.bodySmall?.copyWith(color: Brand.muted)),
          ]),
        ),
      ]),
    );
  }

  List<Widget> _list(List<AlertItem> items) {
    final children = <Widget>[];
    DateTime? currentDay;
    for (final n in items) {
      final day = dateOnly(n.at);
      if (day != currentDay) {
        currentDay = day;
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
          child: Text(_dayLabel(day), style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Brand.muted)),
        ));
      }
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        // só o que já foi lido pode ser apagado (deslizando); o não lido fica até ser visto
        child: n.read
            ? Dismissible(
                key: ValueKey(n.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(color: const Color(0xFFBE123C), borderRadius: BorderRadius.circular(20)),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                ),
                onDismissed: (_) => _delete(n),
                child: _card(n),
              )
            : _card(n),
      ));
    }
    return children;
  }

  String get _emptyMessage => switch (_status) {
        _Status.unread => 'Você não tem avisos novos.',
        _Status.read => 'Nenhum aviso lido neste período.',
        _Status.all => _period == _Period.all
            ? 'Quando o salão confirmar, cancelar ou mudar um horário seu, ou lançar uma promoção, o aviso fica guardado aqui.'
            : 'Nenhum aviso neste período.',
      };

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final visible = filtered.take(_shown).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avisos'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Mais opções',
            onSelected: (v) => v == 'read' ? _markAllRead() : _clearRead(),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'read',
                child: ListTile(leading: Icon(Icons.done_all_rounded), title: Text('Marcar todos como lidos'), contentPadding: EdgeInsets.zero),
              ),
              PopupMenuItem(
                value: 'clear',
                child: ListTile(leading: Icon(Icons.delete_sweep_outlined), title: Text('Apagar os lidos'), contentPadding: EdgeInsets.zero),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _filters(),
            if (_loading)
              const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
            else if (filtered.isEmpty)
              EmptyState(icon: Icons.notifications_none_rounded, title: 'Nada por aqui', message: _emptyMessage)
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  ..._list(visible),
                  if (filtered.length > visible.length)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _shown += _step),
                        icon: const Icon(Icons.expand_more_rounded),
                        label: const Text('Mostrar mais'),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      'Os avisos lidos há mais de ${AlertLog.keepReadDays} dias saem sozinhos. Deslize um aviso lido para o lado para apagar.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Brand.muted),
                    ),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
