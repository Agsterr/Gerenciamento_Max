import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../session.dart';
import 'finish_sheet.dart';
import 'new_appointment_sheet.dart';

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

  ApiClient get _api => widget.session.api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
      builder: (context) {
        Widget item(IconData icon, String label, String action) => ListTile(
              leading: Icon(icon),
              title: Text(label),
              onTap: () {
                Navigator.pop(context);
                _act(a, action);
              },
            );
        return Wrap(children: [
          ListTile(
            title: Text('${a.customer.name} · ${a.service.name}'),
            subtitle: Text('${formatTime(a.startAt)}–${formatTime(a.endAt)} com ${a.professional.name}'),
          ),
          ListTile(
            leading: const Icon(Icons.chat_outlined),
            title: Text('WhatsApp ${formatPhone(a.customerPhone)}'),
            onTap: () => openWhatsApp(a.customerPhone),
          ),
          if (a.status == AppointmentStatus.scheduled) item(Icons.check, 'Confirmar', 'confirm'),
          if (open) item(Icons.play_arrow, 'Iniciar atendimento', 'start'),
          if (open || a.status == AppointmentStatus.inProgress) item(Icons.done_all, 'Finalizar', 'finish'),
          if (open) item(Icons.person_off_outlined, 'Faltou', 'no-show'),
          if (open) item(Icons.close, 'Cancelar', 'cancel'),
        ]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final professionals = {for (final a in items ?? <Appointment>[]) a.professional.id: a.professional.name};
    final visible = (items ?? []).where((a) => _professionalFilter == null || a.professional.id == _professionalFilter).toList();
    final active = visible.where((a) => a.status != AppointmentStatus.canceled && a.status != AppointmentStatus.noShow);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          IconButton(tooltip: 'Dia anterior', onPressed: () => _go(-1), icon: const Icon(Icons.chevron_left)),
          TextButton(onPressed: _pickDay, child: Text(formatDate(_day))),
          IconButton(tooltip: 'Próximo dia', onPressed: () => _go(1), icon: const Icon(Icons.chevron_right)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await showNewAppointmentSheet(context, api: _api, day: _day);
          if (ok) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Agendar'),
      ),
      body: _error != null
          ? ErrorRetry(message: _error!, onRetry: _load)
          : items == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      Text(formatWeekday(_day), style: Theme.of(context).textTheme.titleMedium),
                      Text('${active.length} atendimento(s) · previsto ${formatMoney(active.fold(0.0, (s, a) => s + a.price))}'),
                      if (professionals.length > 1) ...[
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, children: [
                          ChoiceChip(
                            label: const Text('Todos'),
                            selected: _professionalFilter == null,
                            onSelected: (_) => setState(() => _professionalFilter = null),
                          ),
                          for (final p in professionals.entries)
                            ChoiceChip(
                              label: Text(p.value),
                              selected: _professionalFilter == p.key,
                              onSelected: (_) => setState(() => _professionalFilter = p.key),
                            ),
                        ]),
                      ],
                      const SizedBox(height: 8),
                      if (visible.isEmpty)
                        const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Nenhum agendamento neste dia.'))),
                      for (final a in visible) _AppointmentTile(a, onTap: () => _actions(a)),
                    ],
                  ),
                ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  const _AppointmentTile(this.a, {required this.onTap});

  final Appointment a;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final faded = a.status == AppointmentStatus.canceled || a.status == AppointmentStatus.noShow;
    return Opacity(
      opacity: faded ? 0.55 : 1,
      child: Card(
        child: ListTile(
          onTap: onTap,
          leading: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(formatTime(a.startAt), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(formatTime(a.endAt), style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          title: Text('${a.customer.name} · ${a.service.name}'),
          subtitle: Text([
            a.professional.name,
            formatMoney(a.price),
            if (a.online) 'online',
            if (a.realMinutes != null) 'real ${a.realMinutes} min (prev. ${a.estimatedMinutes})',
          ].join(' · ')),
          trailing: StatusChip(a.status),
        ),
      ),
    );
  }
}
