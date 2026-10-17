import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

/// Cliente escolhe outro dia/horário livre para o mesmo serviço. Retorna o agendamento atualizado.
Future<Booking?> showRescheduleSheet(BuildContext context, {required ApiClient api, required String slug, required Booking booking}) {
  return showModalBottomSheet<Booking>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _RescheduleSheet(api: api, slug: slug, booking: booking),
  );
}

class _RescheduleSheet extends StatefulWidget {
  const _RescheduleSheet({required this.api, required this.slug, required this.booking});

  final ApiClient api;
  final String slug;
  final Booking booking;

  @override
  State<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<_RescheduleSheet> {
  PublicSalon? _salon;
  late int? _professionalId = widget.booking.professionalId == 0 ? null : widget.booking.professionalId;
  DateTime? _day;
  List<Slot>? _slots;
  Slot? _slot;
  bool _busy = false;

  String get _base => '/api/public/salons/${widget.slug}';

  @override
  void initState() {
    super.initState();
    _loadSalon();
  }

  Future<void> _loadSalon() async {
    try {
      final salon = PublicSalon.fromJson(await widget.api.get(_base) as Map<String, dynamic>);
      final days = _days(salon);
      final current = dateOnly(widget.booking.startAt);
      setState(() {
        _salon = salon;
        _day = days.contains(current) ? current : days.firstOrNull;
      });
      _loadSlots();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  List<DateTime> _days(PublicSalon salon) {
    final today = dateOnly(DateTime.now());
    return [for (var i = 0; i < 28; i++) today.add(Duration(days: i))]
        .where((d) => salon.workDays.contains(d.weekday))
        .take(14)
        .toList();
  }

  Future<void> _loadSlots() async {
    if (_day == null) return;
    setState(() {
      _slots = null;
      _slot = null;
    });
    try {
      final pro = _professionalId != null ? '&professionalId=$_professionalId' : '';
      final json = await widget.api.get('$_base/availability?serviceId=${widget.booking.serviceId}&date=${isoDate(_day!)}$pro') as List;
      if (mounted) setState(() => _slots = json.map((e) => Slot.fromJson(e as Map<String, dynamic>)).toList());
    } catch (e) {
      if (mounted) {
        setState(() => _slots = []);
        showError(context, e);
      }
    }
  }

  Future<void> _confirm() async {
    final slot = _slot;
    if (slot == null) return;
    setState(() => _busy = true);
    try {
      final json = await widget.api.post('$_base/bookings/${widget.booking.token}/reschedule', {
        'startAt': '${isoDate(_day!)}T${slot.time}:00',
        'professionalId': _professionalId ?? slot.professionalIds.firstOrNull,
      }) as Map<String, dynamic>;
      if (mounted) Navigator.pop(context, Booking.fromJson(json));
    } catch (e) {
      if (mounted) {
        showError(context, e);
        _loadSlots();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final salon = _salon;
    final text = Theme.of(context).textTheme;
    if (salon == null) return const SizedBox(height: 240, child: Center(child: CircularProgressIndicator()));
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewPaddingOf(context).bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Remarcar horário', style: text.titleLarge),
        Text('${widget.booking.serviceName} · hoje ${formatShortDateTime(widget.booking.startAt)}',
            style: text.bodyMedium?.copyWith(color: Brand.muted)),
        if (salon.professionals.length > 1) ...[
          const SizedBox(height: 16),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final p in [null, ...salon.professionals])
              ChoiceChip(
                label: Text(p?.name ?? 'Qualquer um'),
                selected: _professionalId == p?.id,
                onSelected: (_) {
                  setState(() => _professionalId = p?.id);
                  _loadSlots();
                },
              ),
          ]),
        ],
        const SizedBox(height: 16),
        DayPicker(
          days: _days(salon),
          selected: _day,
          onSelected: (d) {
            setState(() => _day = d);
            _loadSlots();
          },
        ),
        const SizedBox(height: 16),
        if (_slots == null)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else
          SlotGrid(slots: _slots!, selected: _slot?.time, onSelected: (s) => setState(() => _slot = s)),
        const SizedBox(height: 20),
        GradientButton(
          label: _slot == null ? 'Escolha um horário' : 'Remarcar para ${_slot!.time}',
          icon: Icons.event_repeat_rounded,
          loading: _busy,
          onPressed: _slot == null ? null : _confirm,
        ),
      ]),
    );
  }
}
