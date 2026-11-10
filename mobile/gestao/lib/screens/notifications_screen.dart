import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

/// Avisos do salão: o que os clientes fizeram (agendar, cancelar, remarcar, confirmar) e os lembretes.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

enum _Status { all, unread, read }

enum _Period { all, today, week, month, custom }

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _pageSize = 20;

  final List<AppNotification> _items = [];
  int _page = 0;
  bool _hasMore = false;
  bool _loading = true;
  int _unread = 0;
  String? _error;

  _Status _status = _Status.all;
  _Period _period = _Period.all;
  DateTimeRange? _custom;
  bool _anyUnreadSeen = false;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    // ao sair da tela, o que foi exibido conta como lido
    if (_anyUnreadSeen || _unread > 0) widget.api.post('/api/notifications/read').catchError((_) => null);
    super.dispose();
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

  String get _query {
    final r = _range;
    return 'status=${_status.name}&size=$_pageSize&page=$_page'
        '${r == null ? '' : '&from=${isoDate(r.start)}&to=${isoDate(r.end)}'}';
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 0;
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final json = await widget.api.get('/api/notifications/history?$_query') as Map<String, dynamic>;
      final fresh = (json['items'] as List).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList();
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(fresh);
        _hasMore = json['hasMore'] as bool? ?? false;
        _unread = (json['unread'] as num?)?.toInt() ?? 0;
        if (fresh.any((n) => !n.read)) _anyUnreadSeen = true;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _more() async {
    _page++;
    await _load();
  }

  void _setStatus(_Status s) {
    if (_status == s) return;
    _status = s;
    _load(reset: true);
  }

  void _setPeriod(_Period p) {
    if (_period == p) return;
    _period = p;
    _load(reset: true);
  }

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
    _custom = picked;
    _period = _Period.custom;
    _load(reset: true);
  }

  Future<void> _markAllRead() async {
    try {
      await widget.api.post('/api/notifications/read');
      _anyUnreadSeen = false;
      await _load(reset: true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _clearRead() async {
    if (!await confirmDialog(context, 'Apagar todas as notificações já lidas? Não dá para desfazer.', confirm: 'Apagar lidas', danger: true)) {
      return;
    }
    try {
      final res = await widget.api.post('/api/notifications/clear-read') as Map<String, dynamic>;
      if (mounted) showMessage(context, '${res['deleted']} notificação(ões) apagada(s).');
      await _load(reset: true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _delete(AppNotification n) async {
    setState(() => _items.removeWhere((x) => x.id == n.id));
    try {
      await widget.api.delete('/api/notifications/${n.id}');
    } catch (e) {
      if (mounted) {
        showError(context, e);
        _load(reset: true);
      }
    }
  }

  static (IconData, Color) _style(String type) => switch (type) {
        'CANCELED' => (Icons.event_busy_rounded, const Color(0xFFBE123C)),
        'RESCHEDULED' => (Icons.event_repeat_rounded, const Color(0xFF6D28D9)),
        'CONFIRMED' => (Icons.verified_rounded, const Color(0xFF047857)),
        'REMINDERS' => (Icons.mark_chat_read_outlined, const Color(0xFFB45309)),
        'STAFF_REMINDER' => (Icons.alarm_rounded, Brand.rose),
        _ => (Icons.event_available_rounded, const Color(0xFF047857)),
      };

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
              _chip('Todas', _status == _Status.all, () => _setStatus(_Status.all)),
              _chip(_unread > 0 ? 'Não lidas ($_unread)' : 'Não lidas', _status == _Status.unread, () => _setStatus(_Status.unread)),
              _chip('Lidas', _status == _Status.read, () => _setStatus(_Status.read)),
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

  Widget _card(AppNotification n) {
    final text = Theme.of(context).textTheme;
    final (icon, color) = _style(n.type);
    return SoftCard(
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(n.title, style: text.titleSmall)),
              if (!n.read) Container(width: 10, height: 10, decoration: BoxDecoration(color: Brand.rose, shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 2),
            Text(n.message, style: text.bodyMedium),
            const SizedBox(height: 4),
            Text(formatTime(n.createdAt), style: text.bodySmall?.copyWith(color: Brand.muted)),
          ]),
        ),
      ]),
    );
  }

  List<Widget> _list() {
    final children = <Widget>[];
    DateTime? currentDay;
    for (final n in _items) {
      final day = dateOnly(n.createdAt);
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
                key: ValueKey('n${n.id}'),
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
        _Status.unread => 'Você não tem notificações novas.',
        _Status.read => 'Nenhuma notificação lida neste período.',
        _Status.all => _period == _Period.all
            ? 'Quando um cliente agendar, cancelar ou remarcar pelo link ou pelo app, aparece aqui.'
            : 'Nenhuma notificação neste período.',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Mais opções',
            onSelected: (v) => v == 'read' ? _markAllRead() : _clearRead(),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'read',
                child: ListTile(leading: Icon(Icons.done_all_rounded), title: Text('Marcar todas como lidas'), contentPadding: EdgeInsets.zero),
              ),
              PopupMenuItem(
                value: 'clear',
                child: ListTile(leading: Icon(Icons.delete_sweep_outlined), title: Text('Apagar as lidas'), contentPadding: EdgeInsets.zero),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _filters(),
            if (_error != null)
              ErrorRetry(message: _error!, onRetry: () => _load(reset: true))
            else if (_loading)
              const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
            else if (_items.isEmpty)
              EmptyState(icon: Icons.notifications_none_rounded, title: 'Nada por aqui', message: _emptyMessage)
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  ..._list(),
                  if (_hasMore)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: OutlinedButton.icon(onPressed: _more, icon: const Icon(Icons.expand_more_rounded), label: const Text('Mostrar mais')),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      'As lidas há mais de 30 dias saem sozinhas. Deslize uma lida para o lado para apagar.',
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
