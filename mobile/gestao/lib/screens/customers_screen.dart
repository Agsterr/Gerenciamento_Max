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
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton(tooltip: 'Novo cliente', onPressed: _edit, child: const Icon(Icons.person_add)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Buscar nome ou telefone'),
            onChanged: (v) {
              _query = v.trim();
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), _load);
            },
          ),
        ),
        Expanded(
          child: _error != null
              ? ErrorRetry(message: _error!, onRetry: _load)
              : _items == null
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _items!.isEmpty
                          ? ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Nenhum cliente.')))])
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 88),
                              itemCount: _items!.length,
                              itemBuilder: (context, i) {
                                final c = _items![i];
                                return ListTile(
                                  title: Text(c.name),
                                  subtitle: Text([formatPhone(c.phone), if (c.notes != null) c.notes!].join(' · ')),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => _CustomerDetail(api: _api, customer: c, onEdit: () => _edit(c))),
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'WhatsApp',
                                    icon: const Icon(Icons.chat_outlined),
                                    onPressed: () => openWhatsApp(c.phone),
                                  ),
                                );
                              },
                            ),
                    ),
        ),
      ]),
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
