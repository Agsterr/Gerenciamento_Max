import 'dart:async';

import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../session.dart';
import '../widgets/form_sheet.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key, required this.session});

  final Session session;

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Customer>? _items;
  String? _error;
  String _query = '';
  Timer? _debounce;

  ApiClient get _api => widget.session.api;

  static const _fields = [
    FieldSpec('name', 'Nome', required: true),
    FieldSpec('phone', 'Telefone (WhatsApp)', kind: FieldKind.phone, required: true),
    FieldSpec('email', 'E-mail', kind: FieldKind.email),
    FieldSpec('notes', 'Observações (alergias, preferências...)'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final json = await _api.get('/api/customers?q=${Uri.encodeQueryComponent(_query)}') as List;
      if (mounted) setState(() => _items = json.map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _edit([Customer? c]) async {
    final saved = await showFormSheet(
      context,
      title: c == null ? 'Novo cliente' : 'Editar cliente',
      fields: _fields,
      initial: {'name': c?.name, 'phone': c?.phone, 'email': c?.email, 'notes': c?.notes},
      onSave: (v) => c == null ? _api.post('/api/customers', v) : _api.put('/api/customers/${c.id}', v),
    );
    if (saved) _load();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final items = _items;
    return Scaffold(
      floatingActionButton: SizedBox(
        width: 150,
        child: GradientButton(label: 'Cliente', icon: Icons.person_add_alt_1_rounded, onPressed: _edit),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 110),
          children: [
            GradientHeader(
              gradient: Brand.nightGradient,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Clientes', style: text.headlineSmall?.copyWith(color: Colors.white)),
                Text(items == null ? ' ' : '${items.length} cliente(s)${_query.isEmpty ? '' : ' encontrados'}',
                    style: text.bodyMedium?.copyWith(color: Colors.white70)),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Buscar nome ou telefone',
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                    prefixIcon: const Icon(Icons.search_rounded, color: Brand.rose),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                  ),
                  onChanged: (v) {
                    _query = v.trim();
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 350), _load);
                  },
                ),
              ]),
            ),
            if (_error != null)
              ErrorRetry(message: _error!, onRetry: _load)
            else if (items == null)
              const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
            else if (items.isEmpty)
              const EmptyState(icon: Icons.people_outline_rounded, title: 'Nenhum cliente', message: 'Clientes que agendam online entram aqui automaticamente.')
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(children: [
                  for (final c in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SoftCard(
                        padding: const EdgeInsets.all(12),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => _CustomerDetail(api: _api, customer: c, onEdit: () => _edit(c))),
                        ),
                        child: Row(children: [
                          InitialsAvatar(c.name, size: 46),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c.name, style: text.titleSmall),
                              Text(formatPhone(c.phone), style: text.bodySmall?.copyWith(color: Brand.muted)),
                              if (c.notes != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Pill(c.notes!, icon: Icons.sticky_note_2_outlined),
                                ),
                            ]),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'WhatsApp',
                            style: IconButton.styleFrom(backgroundColor: const Color(0xFFDCFCE7), foregroundColor: Brand.whatsapp),
                            icon: const Icon(Icons.chat_rounded),
                            onPressed: () => openWhatsApp(c.phone),
                          ),
                        ]),
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

class _CustomerDetail extends StatelessWidget {
  const _CustomerDetail({required this.api, required this.customer, required this.onEdit});

  final ApiClient api;
  final Customer customer;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.pop(context);
              onEdit();
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: api.get('/api/customers/${customer.id}/appointments'),
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text(snap.error.toString()));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = (snap.data as List).map((e) => Appointment.fromJson(e as Map<String, dynamic>)).toList();
          final done = list.where((a) => a.status == AppointmentStatus.done);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(formatPhone(customer.phone), style: Theme.of(context).textTheme.titleMedium),
              if (customer.notes != null) Text(customer.notes!),
              const SizedBox(height: 8),
              Text('${done.length} atendimento(s) · total ${formatMoney(done.fold(0.0, (s, a) => s + a.price))}'),
              const Divider(),
              if (list.isEmpty) const Text('Sem atendimentos ainda.'),
              for (final a in list)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(a.service.name),
                  subtitle: Text('${formatDate(a.startAt)} ${formatTime(a.startAt)} · ${a.professional.name} · ${formatMoney(a.price)}'),
                  trailing: StatusChip(a.status),
                ),
            ],
          );
        },
      ),
    );
  }
}
