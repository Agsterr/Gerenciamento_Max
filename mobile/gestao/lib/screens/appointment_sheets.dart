import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../widgets/weekly_hours_editor.dart' show pickTime;

/// Anotações internas do atendimento (tinta usada, corte feito...). Só a equipe vê.
Future<bool> showServiceNotesSheet(BuildContext context, {required ApiClient api, required Appointment appointment}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _NotesSheet(api: api, appointment: appointment),
  );
  return ok ?? false;
}

class ServiceNotesField extends StatelessWidget {
  const ServiceNotesField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        minLines: 3,
        maxLines: 6,
        maxLength: 1000,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Anotações do atendimento',
          hintText: 'Ex.: tinta 7.1 + OX 20 vol, pausa 35 min; corte em camadas, franja lateral',
          helperText: 'Só a equipe vê. Fica no histórico do cliente.',
          alignLabelWithHint: true,
        ),
      );
}

class _NotesSheet extends StatefulWidget {
  const _NotesSheet({required this.api, required this.appointment});

  final ApiClient api;
  final Appointment appointment;

  @override
  State<_NotesSheet> createState() => _NotesSheetState();
}

class _NotesSheetState extends State<_NotesSheet> {
  late final _text = TextEditingController(text: widget.appointment.serviceNotes);
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await widget.api.put('/api/appointments/${widget.appointment.id}/service-notes', {'serviceNotes': _text.text});
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, sheetBottomInset(context) + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Anotações', style: Theme.of(context).textTheme.titleLarge),
        Text('${a.customer.name} · ${a.service.name} com ${a.professional.name}'),
        const SizedBox(height: 16),
        ServiceNotesField(controller: _text),
        const SizedBox(height: 12),
        GradientButton(label: 'Salvar anotações', icon: Icons.save_outlined, loading: _busy, onPressed: _save),
      ]),
    );
  }
}

/// Salão remarca: dia, horário e profissional. Depois oferece avisar o cliente no WhatsApp.
Future<bool> showStaffRescheduleSheet(BuildContext context, {required ApiClient api, required Appointment appointment}) async {
  final updated = await showModalBottomSheet<Appointment>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _RescheduleSheet(api: api, appointment: appointment),
  );
  if (updated == null || !context.mounted) return updated != null;
  final a = appointment;
  final notify = await confirmDialog(
    context,
    'Remarcado para ${formatShortDateTime(updated.startAt)} com ${updated.professional.name}. Avisar ${a.customer.name.split(' ').first} no WhatsApp?',
    confirm: 'Avisar no WhatsApp',
  );
  if (notify) {
    await openWhatsApp(
      a.customerPhone,
      text: 'Olá, ${a.customer.name.split(' ').first}! Seu horário de ${a.service.name} foi remarcado para '
          '${formatShortDateTime(updated.startAt)} com ${updated.professional.name}. Qualquer dúvida é só responder aqui.',
    );
  }
  return true;
}

class _RescheduleSheet extends StatefulWidget {
  const _RescheduleSheet({required this.api, required this.appointment});

  final ApiClient api;
  final Appointment appointment;

  @override
  State<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<_RescheduleSheet> {
  List<Professional> _professionals = [];
  late int _professionalId = widget.appointment.professional.id;
  late DateTime _day = dateOnly(widget.appointment.startAt);
  List<Slot>? _slots;
  String? _time;
  bool _manual = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.api.get('/api/professionals').then((json) {
      if (mounted) {
        setState(() => _professionals = (json as List)
            .map((e) => Professional.fromJson(e as Map<String, dynamic>))
            .where((p) => p.active || p.id == _professionalId)
            .toList());
      }
    }).catchError((Object e) {
      if (mounted) showError(context, e);
    });
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    setState(() {
      _slots = null;
      _time = null;
    });
    try {
      final json = await widget.api.get('/api/appointments/availability?serviceId=${widget.appointment.service.id}'
          '&date=${isoDate(_day)}&professionalId=$_professionalId') as List;
      if (mounted) setState(() => _slots = json.map((e) => Slot.fromJson(e as Map<String, dynamic>)).toList());
    } catch (e) {
      if (mounted) {
        setState(() => _slots = []);
        showError(context, e);
      }
    }
  }

  Future<void> _pickDay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: dateOnly(DateTime.now()),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() => _day = d);
      _loadSlots();
    }
  }

  Future<void> _save() async {
    final a = widget.appointment;
    setState(() => _busy = true);
    try {
      final json = await widget.api.put('/api/appointments/${a.id}', {
        'customerId': a.customer.id,
        'serviceId': a.service.id,
        'professionalId': _professionalId,
        'startAt': '${isoDate(_day)}T$_time:00',
        'notes': a.notes,
        'durationMinutes': a.estimatedMinutes,
        'force': _manual,
      }) as Map<String, dynamic>;
      if (mounted) Navigator.pop(context, Appointment.fromJson(json));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.appointment;
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + sheetBottomInset(context)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Remarcar horário', style: text.titleLarge),
        Text('${a.customer.name} · ${a.service.name} · hoje ${formatShortDateTime(a.startAt)}',
            style: text.bodyMedium?.copyWith(color: Brand.muted)),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          initialValue: _professionalId,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Profissional'),
          items: [
            for (final p in _professionals) DropdownMenuItem(value: p.id, child: Text(p.name)),
            if (_professionals.isEmpty) DropdownMenuItem(value: a.professional.id, child: Text(a.professional.name)),
          ],
          onChanged: (v) {
            if (v == null) return;
            setState(() => _professionalId = v);
            _loadSlots();
          },
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickDay,
          icon: const Icon(Icons.calendar_month_rounded),
          label: Text(formatWeekday(_day)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Encaixe'),
          subtitle: const Text('Qualquer horário, mesmo com conflito ou fora do expediente'),
          value: _manual,
          onChanged: (v) => setState(() {
            _manual = v;
            _time = null;
          }),
        ),
        if (_manual)
          OutlinedButton.icon(
            onPressed: () async {
              final t = await pickTime(context, _time ?? formatTime(a.startAt), help: 'Novo horário');
              if (t != null) setState(() => _time = t);
            },
            icon: const Icon(Icons.schedule_rounded),
            label: Text(_time ?? 'Escolher horário'),
          )
        else if (_slots == null)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else
          SlotGrid(slots: _slots!, selected: _time, onSelected: (s) => setState(() => _time = s.time)),
        const SizedBox(height: 16),
        GradientButton(
          label: _time == null ? 'Escolha um horário' : 'Remarcar para $_time',
          icon: Icons.event_repeat_rounded,
          loading: _busy,
          onPressed: _time == null ? null : _save,
        ),
      ]),
    );
  }
}
