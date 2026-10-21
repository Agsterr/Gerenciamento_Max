import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../widgets/weekly_hours_editor.dart';

/// Agendamento pelo salão: horários livres ou manual (qualquer horário, duração e encaixe).
Future<bool> showNewAppointmentSheet(BuildContext context, {required ApiClient api, required DateTime day}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _NewAppointmentSheet(api: api, day: day),
  );
  return ok ?? false;
}

class _NewAppointmentSheet extends StatefulWidget {
  const _NewAppointmentSheet({required this.api, required this.day});

  final ApiClient api;
  final DateTime day;

  @override
  State<_NewAppointmentSheet> createState() => _NewAppointmentSheetState();
}

class _NewAppointmentSheetState extends State<_NewAppointmentSheet> {
  List<ServiceItem> _services = [];
  List<Professional> _professionals = [];

  Customer? _customer;
  final _search = TextEditingController();
  final _newPhone = TextEditingController();
  List<Customer> _matches = [];

  ServiceItem? _service;
  int? _professionalId;
  late DateTime _day = widget.day;
  bool _manual = false;
  List<Slot>? _slots;
  String? _time;
  final _duration = TextEditingController();
  bool _force = false;
  final _notes = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    for (final c in [_search, _newPhone, _duration, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final results = await Future.wait([widget.api.get('/api/services'), widget.api.get('/api/professionals')]);
      if (!mounted) return;
      setState(() {
        _services = (results[0] as List).map((e) => ServiceItem.fromJson(e as Map<String, dynamic>)).where((s) => s.active).toList();
        _professionals =
            (results[1] as List).map((e) => Professional.fromJson(e as Map<String, dynamic>)).where((p) => p.active).toList();
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _searchCustomers(String q) async {
    if (q.trim().length < 2) return setState(() => _matches = []);
    try {
      final json = await widget.api.get('/api/customers?q=${Uri.encodeQueryComponent(q.trim())}') as List;
      if (mounted) setState(() => _matches = json.map((e) => Customer.fromJson(e as Map<String, dynamic>)).take(5).toList());
    } catch (_) {}
  }

  Future<void> _loadSlots() async {
    if (_service == null || _manual) return;
    setState(() {
      _slots = null;
      _time = null;
    });
    final pro = _professionalId != null ? '&professionalId=$_professionalId' : '';
    try {
      final json =
          await widget.api.get('/api/appointments/availability?serviceId=${_service!.id}&date=${isoDate(_day)}$pro') as List;
      if (mounted) setState(() => _slots = json.map((e) => Slot.fromJson(e as Map<String, dynamic>)).toList());
    } catch (e) {
      if (mounted) setState(() => _slots = []);
    }
  }

  Future<void> _pickTime() async {
    final t = await pickTime(context, _time ?? '09:00', help: 'Horário do agendamento');
    if (t != null) setState(() => _time = t);
  }

  bool get _hasCustomer =>
      _customer != null || (_search.text.trim().isNotEmpty && _newPhone.text.replaceAll(RegExp(r'\D'), '').length >= 10);

  bool get _canSave => _hasCustomer && _service != null && _time != null && !(_manual && _force && _professionalId == null);

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final customer = _customer ??
          Customer.fromJson(await widget.api.post('/api/customers', {
            'name': _search.text.trim(),
            'phone': _newPhone.text.trim(),
          }) as Map<String, dynamic>);
      await widget.api.post('/api/appointments', {
        'customerId': customer.id,
        'serviceId': _service!.id,
        'professionalId': _professionalId,
        'startAt': '${isoDate(_day)}T$_time:00',
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'durationMinutes': _manual && _duration.text.isNotEmpty ? int.tryParse(_duration.text) : null,
        'force': _manual && _force,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: sheetBottomInset(context) + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Novo agendamento', style: text.titleLarge),
            const SizedBox(height: 16),
            if (_customer != null)
              SoftCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: InitialsAvatar(_customer!.name, size: 40),
                  title: Text(_customer!.name),
                  subtitle: Text(formatPhone(_customer!.phone)),
                  trailing: TextButton(onPressed: () => setState(() => _customer = null), child: const Text('Trocar')),
                ),
              )
            else ...[
              TextField(
                controller: _search,
                decoration: const InputDecoration(labelText: 'Cliente (nome ou telefone)', prefixIcon: Icon(Icons.search)),
                onChanged: (v) {
                  _searchCustomers(v);
                  setState(() {});
                },
              ),
              for (final c in _matches)
                ListTile(
                  dense: true,
                  title: Text(c.name),
                  subtitle: Text(formatPhone(c.phone)),
                  onTap: () => setState(() {
                    _customer = c;
                    _matches = [];
                  }),
                ),
              if (_search.text.trim().length >= 2) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _newPhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Ou novo cliente: telefone', hintText: '(11) 99999-9999'),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<ServiceItem>(
              initialValue: _service,
              decoration: const InputDecoration(labelText: 'Serviço'),
              isExpanded: true,
              items: [
                for (final s in _services)
                  DropdownMenuItem(value: s, child: Text('${s.name} · ${s.durationMinutes} min · ${formatMoney(s.price)}')),
              ],
              onChanged: (s) {
                setState(() => _service = s);
                _loadSlots();
              },
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _professionalId,
                  decoration: const InputDecoration(labelText: 'Profissional'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Qualquer um')),
                    for (final p in _professionals) DropdownMenuItem(value: p.id, child: Text(p.name)),
                  ],
                  onChanged: (v) {
                    setState(() => _professionalId = v);
                    _loadSlots();
                  },
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.event),
                label: Text(formatDate(_day)),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _day,
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) {
                    setState(() => _day = d);
                    _loadSlots();
                  }
                },
              ),
            ]),
            if (_service != null) ...[
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Horários livres'), icon: Icon(Icons.auto_awesome)),
                  ButtonSegment(value: true, label: Text('Manual'), icon: Icon(Icons.edit_calendar)),
                ],
                selected: {_manual},
                onSelectionChanged: (v) {
                  setState(() {
                    _manual = v.first;
                    _time = null;
                  });
                  _loadSlots();
                },
              ),
              const SizedBox(height: 12),
              if (_manual) ...[
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule),
                      label: Text(_time ?? 'Escolher horário'),
                      onPressed: _pickTime,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _duration,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Duração (min)', hintText: '${_service!.durationMinutes}'),
                    ),
                  ),
                ]),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _force,
                  onChanged: (v) => setState(() => _force = v),
                  title: const Text('Encaixe'),
                  subtitle: Text(_force && _professionalId == null
                      ? 'Escolha o profissional para o encaixe.'
                      : 'Marca mesmo com conflito ou fora do expediente.'),
                ),
              ] else if (_slots == null)
                const Center(child: CircularProgressIndicator())
              else
                SlotGrid(slots: _slots!, selected: _time, onSelected: (s) => setState(() => _time = s.time)),
            ],
            const SizedBox(height: 12),
            TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Observações')),
            const SizedBox(height: 16),
            GradientButton(
              label: _time != null ? 'Agendar às $_time' : 'Escolha um horário',
              icon: Icons.event_available_rounded,
              loading: _busy,
              onPressed: _canSave ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}
