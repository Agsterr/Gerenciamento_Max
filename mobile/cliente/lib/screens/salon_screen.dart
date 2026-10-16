import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../booking_store.dart';
import 'booking_screen.dart';

/// Agendamento: serviço → profissional → dia/horário → nome e WhatsApp.
class SalonScreen extends StatefulWidget {
  const SalonScreen({super.key, required this.slug, required this.store, required this.api});

  final String slug;
  final BookingStore store;
  final ApiClient api;

  @override
  State<SalonScreen> createState() => _SalonScreenState();
}

class _SalonScreenState extends State<SalonScreen> {
  PublicSalon? _salon;
  String? _error;

  PublicService? _service;
  int? _professionalId;
  DateTime? _day;
  List<Slot>? _slots;
  String? _time;

  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.store.name);
  late final _phone = TextEditingController(text: widget.store.phone);
  bool _remember = true;
  bool _busy = false;

  String get _base => '/api/public/salons/${widget.slug}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final salon = PublicSalon.fromJson(await widget.api.get(_base) as Map<String, dynamic>);
      setState(() {
        _salon = salon;
        _day = _days(salon).firstOrNull;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  /// Próximos 14 dias de funcionamento.
  List<DateTime> _days(PublicSalon salon) {
    final today = dateOnly(DateTime.now());
    return [for (var i = 0; i < 28; i++) today.add(Duration(days: i))]
        .where((d) => salon.workDays.contains(d.weekday))
        .take(14)
        .toList();
  }

  Future<void> _loadSlots() async {
    if (_service == null || _day == null) return;
    setState(() {
      _slots = null;
      _time = null;
    });
    try {
      final pro = _professionalId != null ? '&professionalId=$_professionalId' : '';
      final json = await widget.api.get('$_base/availability?serviceId=${_service!.id}&date=${isoDate(_day!)}$pro') as List;
      if (mounted) setState(() => _slots = json.map((e) => Slot.fromJson(e as Map<String, dynamic>)).toList());
    } catch (e) {
      if (mounted) {
        setState(() => _slots = []);
        showError(context, e);
      }
    }
  }

  Future<void> _book() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final json = await widget.api.post('$_base/bookings', {
        'serviceId': _service!.id,
        'professionalId': _professionalId,
        'startAt': '${isoDate(_day!)}T$_time:00',
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
      }) as Map<String, dynamic>;
      final booking = Booking.fromJson(json);
      await widget.store.add(SavedBooking(slug: widget.slug, token: booking.token, salonName: _salon!.name));
      if (_remember) {
        await widget.store.rememberCustomer(_name.text.trim(), _phone.text.trim());
      } else {
        await widget.store.forgetCustomer();
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => BookingScreen(slug: widget.slug, token: booking.token, api: widget.api, justBooked: true)),
      );
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
    return Scaffold(
      appBar: AppBar(title: Text(salon?.name ?? 'Salão')),
      body: switch ((salon, _error)) {
        (_, final String error) => ErrorRetry(message: error, onRetry: _load),
        (null, _) => const Center(child: CircularProgressIndicator()),
        (final PublicSalon salon, _) => _content(salon),
      },
    );
  }

  Widget _content(PublicSalon salon) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (salon.address != null) Text(salon.address!, style: text.bodyMedium),
        const SizedBox(height: 8),
        _Step(n: 1, title: 'Serviço', children: [
          if (salon.services.isEmpty) const Text('Nenhum serviço disponível no momento.'),
          for (final s in salon.services)
            Card(
              color: _service?.id == s.id ? Theme.of(context).colorScheme.primaryContainer : null,
              child: ListTile(
                title: Text(s.name),
                subtitle: Text('${s.durationMinutes} min${s.description != null ? ' · ${s.description}' : ''}'),
                trailing: Text(formatMoney(s.price), style: text.titleMedium),
                onTap: () {
                  setState(() => _service = s);
                  _loadSlots();
                },
              ),
            ),
        ]),
        if (_service != null) ...[
          _Step(n: 2, title: 'Profissional', children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(
                label: const Text('Sem preferência'),
                selected: _professionalId == null,
                onSelected: (_) {
                  setState(() => _professionalId = null);
                  _loadSlots();
                },
              ),
              for (final p in salon.professionals)
                ChoiceChip(
                  label: Text(p.name),
                  selected: _professionalId == p.id,
                  onSelected: (_) {
                    setState(() => _professionalId = p.id);
                    _loadSlots();
                  },
                ),
            ]),
          ]),
          _Step(n: 3, title: 'Dia e horário', children: [
            DayPicker(
              days: _days(salon),
              selected: _day,
              label: formatWeekdayShort,
              onSelected: (d) {
                setState(() => _day = d);
                _loadSlots();
              },
            ),
            const SizedBox(height: 12),
            if (_slots == null)
              const Center(child: CircularProgressIndicator())
            else
              SlotGrid(slots: _slots!, selected: _time, onSelected: (s) => setState(() => _time = s.time)),
          ]),
        ],
        if (_time != null)
          _Step(n: 4, title: 'Seus dados', children: [
            Form(
              key: _form,
              child: Column(children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Informe seu nome' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  decoration: const InputDecoration(labelText: 'WhatsApp', hintText: '(11) 99999-9999'),
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length < 10 ? 'Telefone com DDD' : null,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _remember,
                  onChanged: (v) => setState(() => _remember = v ?? false),
                  title: const Text('Lembrar meus dados neste aparelho'),
                ),
                Text(
                  'Seu nome e telefone são enviados apenas para ${salon.name}, para confirmar o horário. '
                  'Veja a Política de Privacidade em "Sobre".',
                  style: text.bodySmall,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _book,
                    child: Text(_busy ? 'Agendando...' : 'Confirmar ${_service!.name} às $_time'),
                  ),
                ),
              ]),
            ),
          ]),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.title, required this.children});

  final int n;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(radius: 12, child: Text('$n', style: const TextStyle(fontSize: 12))),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      );
}
