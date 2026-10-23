import 'dart:async';

import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../session.dart';
import '../staff_reminders.dart';
import 'appointment_search_screen.dart';
import 'appointment_sheets.dart';
import 'finish_sheet.dart';
import 'new_appointment_sheet.dart';
import '../background.dart' show markNotified;
import 'notifications_screen.dart';
import 'pending_screen.dart';
import 'subscribe_screen.dart';

class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key, required this.session});

  final Session session;

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  DateTime _day = dateOnly(DateTime.now());
  List<Appointment>? _items;
  String? _error;
  int? _professionalFilter;
  int _unread = 0;
  Timer? _poll;
  PlanInfo? _plan;

  /// Agendamentos dos clientes que ainda esperam o aceite do salão (próximos 90 dias).
  List<Appointment> _pending = const [];

  ApiClient get _api => widget.session.api;

  @override
  void initState() {
    super.initState();
    _load();
    // confere avisos novos (agendamento/cancelamento/remarcação online) enquanto o app está aberto
    _poll = Timer.periodic(const Duration(minutes: 1), (_) => _loadUnread());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _loadUnread() async {
    try {
      final inbox = Inbox.fromJson(await _api.get('/api/notifications') as Map<String, dynamic>);
      if (!mounted) return;
      if (inbox.unread > _unread && inbox.items.isNotEmpty && !inbox.items.first.read) {
        final n = inbox.items.first;
        showMessage(context, '${n.title}: ${n.message}');
        markNotified(n.id); // o app aberto já avisou: o segundo plano não repete
        if (_unread > 0 || _items != null) _load(withUnread: false);
      }
      setState(() => _unread = inbox.unread);
    } catch (_) {
      // sem rede: tenta no próximo ciclo
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen(api: _api)));
    if (mounted) setState(() => _unread = 0);
    _load();
  }

  Future<void> _loadPending() async {
    try {
      final today = dateOnly(DateTime.now());
      final json = await _api.get('/api/appointments?from=${isoDate(today)}&to=${isoDate(today.add(const Duration(days: 90)))}') as List;
      final now = DateTime.now();
      final pending = json
          .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
          .where((a) => a.pendingAcceptance && a.endAt.isAfter(now))
          .toList();
      if (mounted) setState(() => _pending = pending);
    } catch (_) {
      // aviso opcional
    }
  }

  Future<void> _openPending() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => PendingAcceptanceScreen(api: _api, items: _pending)));
    if (mounted) _load();
  }

  Future<void> _loadPlan() async {
    try {
      final plan = PlanInfo.fromJson(await _api.get('/api/salon/plan') as Map<String, dynamic>);
      if (mounted) setState(() => _plan = plan);
    } catch (_) {
      // aviso do plano é opcional
    }
  }

  Future<void> _load({bool withUnread = true}) async {
    if (withUnread) {
      _loadUnread();
      _loadPlan();
      _loadPending();
      syncStaffReminders(_api);
    }
    setState(() => _error = null);
    try {
      final json = await _api.get('/api/appointments?from=${isoDate(_day)}') as List;
      if (mounted) setState(() => _items = json.map((e) => Appointment.fromJson(e as Map<String, dynamic>)).toList());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _go(int days) {
    setState(() {
      _day = _day.add(Duration(days: days));
      _items = null;
    });
    _load();
  }

  /// Busca em todas as datas; se tocar em um resultado, a agenda abre no dia dele.
  Future<void> _search() async {
    final day = await Navigator.push<DateTime>(context, MaterialPageRoute(builder: (_) => AppointmentSearchScreen(api: _api)));
    if (day != null && mounted) {
      setState(() {
        _day = dateOnly(day);
        _items = null;
      });
      _load();
    }
  }

  Future<void> _pickDay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() => _day = d);
      _load();
    }
  }

  Future<void> _act(Appointment a, String action) async {
    if (action == 'finish') {
      final ok = await showFinishSheet(context, api: _api, appointment: a);
      if (ok) _load();
      return;
    }
    if (action == 'reschedule') {
      if (await showStaffRescheduleSheet(context, api: _api, appointment: a)) _load();
      return;
    }
    if (action == 'notes') {
      if (await showServiceNotesSheet(context, api: _api, appointment: a)) _load();
      return;
    }
    if (action == 'cancel' && !await confirmDialog(context, 'Cancelar o horário de ${a.customer.name}?', danger: true)) return;
    try {
      await _api.post('/api/appointments/${a.id}/$action');
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _actions(Appointment a) {
    final open = a.status.isOpen;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) {
        Widget item(IconData icon, String label, String action) => ListTile(
              leading: Icon(icon),
              title: Text(label),
              onTap: () {
                Navigator.pop(context);
                _act(a, action);
              },
            );
        return SafeArea(top: false, child: SingleChildScrollView(child: Wrap(children: [
          ListTile(
            title: Text('${a.customer.name} · ${a.service.name}'),
            subtitle: Text('${formatTime(a.startAt)}–${formatTime(a.endAt)} com ${a.professional.name}'),
          ),
          ListTile(
            leading: const Icon(Icons.chat_outlined),
            title: Text('WhatsApp ${formatPhone(a.customerPhone)}'),
            onTap: () => openWhatsApp(
              a.customerPhone,
              text: open
                  ? 'Olá, ${a.customer.name.split(' ').first}! Passando para lembrar do seu horário de ${a.service.name} '
                      '${formatShortDateTime(a.startAt)}.'
                  : null,
            ),
          ),
          if (a.pendingAcceptance) item(Icons.verified_outlined, 'Aceitar horário', 'accept'),
          if (a.status == AppointmentStatus.scheduled) item(Icons.check, 'Cliente confirmou presença', 'confirm'),
          if (open) item(Icons.play_arrow, 'Iniciar atendimento', 'start'),
          if (open || a.status == AppointmentStatus.inProgress) item(Icons.done_all, 'Finalizar', 'finish'),
          if (open) item(Icons.event_repeat_rounded, 'Remarcar', 'reschedule'),
          if (a.status != AppointmentStatus.canceled)
            item(Icons.edit_note_rounded, a.serviceNotes == null ? 'Anotações (tinta, corte...)' : 'Editar anotações', 'notes'),
          if (open) item(Icons.person_off_outlined, 'Faltou', 'no-show'),
          if (open) item(Icons.close, 'Cancelar', 'cancel'),
        ])));
      },
    );
  }

  /// Semana (seg–dom) do dia selecionado, para a faixa de dias do cabeçalho.
  List<DateTime> get _week {
    final monday = _day.subtract(Duration(days: _day.weekday - 1));
    return [for (var i = 0; i < 7; i++) monday.add(Duration(days: i))];
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final items = _items;
    final professionals = {for (final a in items ?? <Appointment>[]) a.professional.id: a.professional.name};
    final visible = (items ?? []).where((a) => _professionalFilter == null || a.professional.id == _professionalFilter).toList();
    final active = visible.where((a) => a.status != AppointmentStatus.canceled && a.status != AppointmentStatus.noShow).toList();
    final firstName = widget.session.user.name.split(' ').first;

    return Scaffold(
      floatingActionButton: _GradientFab(
        onPressed: () async {
          final ok = await showNewAppointmentSheet(context, api: _api, day: _day);
          if (ok) _load();
        },
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            GradientHeader(
              gradient: Brand.nightGradient,
              bottomPadding: 20,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${greeting()}, $firstName', style: text.bodyMedium?.copyWith(color: Colors.white70)),
                      Text(formatWeekday(_day), style: text.titleLarge?.copyWith(color: Colors.white)),
                    ]),
                  ),
                  _Bell(unread: _unread, onTap: _openNotifications),
                  const SizedBox(width: 6),
                  _HeaderButton(icon: Icons.search_rounded, tooltip: 'Buscar agendamentos', onTap: _search),
                  const SizedBox(width: 6),
                  _HeaderButton(icon: Icons.chevron_left_rounded, tooltip: 'Semana anterior', onTap: () => _go(-7)),
                  const SizedBox(width: 6),
                  _HeaderButton(icon: Icons.calendar_month_rounded, tooltip: 'Escolher data', onTap: _pickDay),
                  const SizedBox(width: 6),
                  _HeaderButton(icon: Icons.chevron_right_rounded, tooltip: 'Próxima semana', onTap: () => _go(7)),
                ]),
                const SizedBox(height: 16),
                DayPicker(
                  dark: true,
                  days: _week,
                  selected: _day,
                  onSelected: (d) {
                    setState(() {
                      _day = d;
                      _items = null;
                    });
                    _load();
                  },
                ),
                const SizedBox(height: 16),
                Row(children: [
                  _Kpi(label: 'Atendimentos', value: '${active.length}', icon: Icons.event_available_rounded),
                  const SizedBox(width: 10),
                  _Kpi(label: 'Previsto', value: formatMoney(active.fold(0.0, (s, a) => s + a.price)), icon: Icons.payments_outlined),
                  const SizedBox(width: 10),
                  _Kpi(label: 'Online', value: '${active.where((a) => a.online).length}', icon: Icons.smartphone_rounded),
                ]),
              ]),
            ),
            if (_pending.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Material(
                  color: const Color(0xFFFFF4DB),
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: _openPending,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        const Icon(Icons.hourglass_top_rounded, color: Color(0xFFB45309)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                              _pending.length == 1
                                  ? '1 agendamento aguardando sua confirmação'
                                  : '${_pending.length} agendamentos aguardando sua confirmação',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: const Color(0xFF92400E)),
                            ),
                            const Text('Toque para aceitar ou recusar.', style: TextStyle(color: Color(0xFFB45309), fontSize: 12)),
                          ]),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFFB45309)),
                      ]),
                    ),
                  ),
                ),
              ),
            if (_plan != null && _plan!.status != 'ACTIVE') _PlanBanner(
              _plan!,
              onSubscribe: widget.session.user.isOwner && AppConfig.storeBuild && _plan!.billingAvailable
                  ? () async {
                      final ok = await Navigator.push<bool>(context,
                          MaterialPageRoute(builder: (_) => SubscribeScreen(session: widget.session, plan: _plan!)));
                      if (ok == true) _load();
                    }
                  : null,
            ),
            if (professionals.length > 1)
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  children: [
                    _FilterChip(label: 'Todos', selected: _professionalFilter == null, onTap: () => setState(() => _professionalFilter = null)),
                    for (final p in professionals.entries)
                      _FilterChip(
                        label: p.value,
                        avatar: p.value,
                        selected: _professionalFilter == p.key,
                        onTap: () => setState(() => _professionalFilter = p.key),
                      ),
                  ],
                ),
              ),
            if (_error != null)
              ErrorRetry(message: _error!, onRetry: _load)
            else if (items == null)
              const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
            else if (visible.isEmpty)
              const EmptyState(
                icon: Icons.event_note_rounded,
                title: 'Agenda livre',
                message: 'Nenhum agendamento neste dia. Toque em "Agendar" para marcar um horário.',
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(children: [
                  for (var i = 0; i < visible.length; i++)
                    _TimelineItem(visible[i], last: i == visible.length - 1, onTap: () => _actions(visible[i])),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, color: Colors.white)),
          ),
        ),
      );
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: const Color(0xFFFFA3C2), size: 20),
            const SizedBox(height: 8),
            FittedBox(
              child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
            ),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap, this.avatar});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? avatar;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.fromLTRB(avatar != null ? 4 : 14, 4, 14, 4),
              decoration: BoxDecoration(
                gradient: selected ? Brand.gradient : null,
                color: selected ? null : Colors.white,
                borderRadius: BorderRadius.circular(999),
                boxShadow: Brand.softShadow(),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (avatar != null) ...[InitialsAvatar(avatar!, size: 28), const SizedBox(width: 8)],
                Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? Colors.white : Brand.ink)),
              ]),
            ),
          ),
        ),
      );
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem(this.a, {required this.last, required this.onTap});

  final Appointment a;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final (bg, fg) = StatusChip.colors(a.status);
    final faded = a.status == AppointmentStatus.canceled || a.status == AppointmentStatus.noShow;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 52,
          child: Column(children: [
            const SizedBox(height: 16),
            Text(formatTime(a.startAt), style: text.titleSmall),
            Text(formatTime(a.endAt), style: text.bodySmall?.copyWith(color: Brand.muted)),
          ]),
        ),
        SizedBox(
          width: 20,
          child: Column(children: [
            const SizedBox(height: 20),
            Container(width: 12, height: 12, decoration: BoxDecoration(color: fg, shape: BoxShape.circle, border: Border.all(color: bg, width: 3))),
            if (!last) Expanded(child: Container(width: 2, color: Brand.line)),
          ]),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Opacity(
              opacity: faded ? 0.55 : 1,
              child: SoftCard(
                onTap: onTap,
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(a.customer.name, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    StatusChip(a.status),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(ServiceIcon.iconFor(a.service.name), size: 16, color: Brand.rose),
                    const SizedBox(width: 6),
                    Expanded(child: Text(a.service.name, style: text.bodyMedium?.copyWith(color: Brand.muted))),
                    Text(formatMoney(a.price), style: text.titleSmall?.copyWith(color: Brand.rose)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    InitialsAvatar(a.professional.name, size: 24),
                    const SizedBox(width: 6),
                    Text(a.professional.name, style: text.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (a.pendingAcceptance)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Pill('pendente', icon: Icons.hourglass_top_rounded, color: Color(0xFFFFF4DB), textColor: Color(0xFFB45309)),
                      ),
                    if (a.customerConfirmed)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Pill('confirmou', icon: Icons.verified_rounded, color: Color(0xFFDCFCE7), textColor: Color(0xFF047857)),
                      ),
                    if (a.online) const Pill('online', icon: Icons.smartphone_rounded, color: Color(0xFFEDE9FE), textColor: Color(0xFF6D28D9)),
                    if (a.realMinutes != null) ...[
                      const SizedBox(width: 6),
                      Pill('${a.realMinutes} min', icon: Icons.timer_outlined),
                    ],
                  ]),
                  if (a.serviceNotes != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFFFF7E6), borderRadius: BorderRadius.circular(12)),
                      child: Text.rich(
                        TextSpan(children: [
                          const TextSpan(text: 'Anotações: ', style: TextStyle(fontWeight: FontWeight.w800)),
                          TextSpan(text: a.serviceNotes),
                        ]),
                        style: text.bodySmall?.copyWith(color: const Color(0xFF7C4A03)),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Teste grátis (dias e limites) ou teste vencido, com atalho para assinar.
class _PlanBanner extends StatelessWidget {
  const _PlanBanner(this.plan, {this.onSubscribe});

  final PlanInfo plan;
  final VoidCallback? onSubscribe;

  @override
  Widget build(BuildContext context) {
    final expired = plan.expired;
    final text = Theme.of(context).textTheme;
    // Versão das lojas: sem atalho para assinar por fora (regra de pagamentos da Play/App Store).
    final hasContact = !AppConfig.storeBuild && (plan.contactWhatsapp.isNotEmpty || plan.contactEmail.isNotEmpty);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: expired ? const Color(0xFFFFE4E6) : const Color(0xFFFFF7E6),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            expired
                ? 'Seu período de teste terminou'
                : 'Teste grátis: ${plan.daysLeft == 1 ? 'falta 1 dia' : 'faltam ${plan.daysLeft} dias'}',
            style: text.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            expired
                ? 'Você ainda vê seus dados, mas não pode criar nem alterar nada, e o agendamento online está pausado.'
                : '${plan.professionals.$1}/${plan.professionals.$2} profissionais · '
                    '${plan.services.$1}/${plan.services.$2} serviços · ${plan.customers.$1}/${plan.customers.$2} clientes',
            style: text.bodySmall,
          ),
          if (onSubscribe != null) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Brand.rose),
              onPressed: onSubscribe,
              icon: const Icon(Icons.workspace_premium_outlined),
              label: Text(expired ? 'Assinar para continuar' : 'Assinar o plano completo'),
            ),
          ] else if (hasContact) ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Brand.rose),
              onPressed: () => plan.contactWhatsapp.isNotEmpty
                  ? openWhatsApp(plan.contactWhatsapp, text: 'Olá! Quero ativar o plano do Salão Max.')
                  : openUrl(Uri.parse('mailto:${plan.contactEmail}?subject=Ativar%20plano%20Sal%C3%A3o%20Max')),
              icon: const Icon(Icons.workspace_premium_outlined),
              label: Text(expired ? 'Ativar meu plano' : 'Quero assinar'),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Bell extends StatelessWidget {
  const _Bell({required this.unread, required this.onTap});

  final int unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 9 ? '9+' : '$unread'),
        backgroundColor: Brand.rose,
        child: _HeaderButton(
          icon: unread > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
          tooltip: unread > 0 ? '$unread notificações novas' : 'Notificações',
          onTap: onTap,
        ),
      );
}

class _GradientFab extends StatelessWidget {
  const _GradientFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        child: GradientButton(label: 'Agendar', icon: Icons.add_rounded, onPressed: onPressed),
      );
}
