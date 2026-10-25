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
  late final PagedController<Customer> _list =
      PagedController(api: _api, path: '/api/customers', parse: Customer.fromJson)..addListener(_changed);

  ApiClient get _api => widget.session.api;

  void _changed() {
    if (mounted) setState(() {});
  }

  static const _fields = [
    FieldSpec('name', 'Nome', required: true),
    FieldSpec('phone', 'Telefone (WhatsApp)', kind: FieldKind.phone, required: true),
    FieldSpec('email', 'E-mail', kind: FieldKind.email),
    FieldSpec('notes', 'Observações (alergias, preferências...)'),
  ];

  @override
  void initState() {
    super.initState();
    _list.refresh();
  }

  @override
  void dispose() {
    _list.dispose();
    super.dispose();
  }

  Future<void> _edit([Customer? c]) async {
    final saved = await showFormSheet(
      context,
      title: c == null ? 'Novo cliente' : 'Editar cliente',
      fields: _fields,
      initial: {'name': c?.name, 'phone': c?.phone, 'email': c?.email, 'notes': c?.notes},
      onSave: (v) => c == null ? _api.post('/api/customers', v) : _api.put('/api/customers/${c.id}', v),
    );
    if (saved) _list.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final items = _list.items;
    final state = pagedStateOrNull(
      _list,
      empty: EmptyState(
        icon: Icons.people_outline_rounded,
        title: _list.query.isEmpty ? 'Nenhum cliente' : 'Nenhum cliente encontrado',
        message: _list.query.isEmpty ? 'Clientes que agendam online entram aqui automaticamente.' : 'Confira o nome ou o telefone digitado.',
      ),
    );
    return Scaffold(
      floatingActionButton: SizedBox(
        width: 150,
        child: GradientButton(label: 'Cliente', icon: Icons.person_add_alt_1_rounded, onPressed: _edit),
      ),
      body: RefreshIndicator(
        onRefresh: _list.refresh,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) => loadMoreOnScroll(n, _list),
          child: ListView(
          padding: const EdgeInsets.only(bottom: 110),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            GradientHeader(
              gradient: Brand.nightGradient,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Clientes', style: text.headlineSmall?.copyWith(color: Colors.white)),
                Text(!_list.loaded ? ' ' : '${_list.total} cliente(s)${_list.query.isEmpty ? '' : ' encontrados'}',
                    style: text.bodyMedium?.copyWith(color: Colors.white70)),
                const SizedBox(height: 16),
                PagedSearchField(controller: _list, hint: 'Buscar nome ou telefone'),
              ]),
            ),
            if (state != null)
              state
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
                              if (c.lastSeenLabel != null || c.promoNotifications == false)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Wrap(spacing: 6, runSpacing: 4, children: [
                                    if (c.lastSeenLabel != null) Pill(c.lastSeenLabel!, icon: Icons.visibility_outlined),
                                    if (c.promoNotifications == false)
                                      const Pill('Avisos de promoção desligados',
                                          icon: Icons.notifications_off_outlined,
                                          color: Color(0xFFFFE4E6),
                                          textColor: Color(0xFFBE123C)),
                                  ]),
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
                  PagedFooter(controller: _list, noun: 'clientes'),
                ]),
              ),
          ],
        ),
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
              const SizedBox(height: 4),
              Text(customer.lastSeenLabel ?? 'Ainda não abriu o salão pelo app do cliente.',
                  style: Theme.of(context).textTheme.bodySmall),
              Text(
                switch (customer.promoNotifications) {
                  false => 'Avisos de promoção: desligados pelo cliente',
                  true => 'Avisos de promoção: ligados',
                  null => 'Avisos de promoção: ligados (padrão)',
                },
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Text('${done.length} atendimento(s) · total ${formatMoney(done.fold(0.0, (s, a) => s + a.price))}'),
              const Divider(),
              if (list.isEmpty) const Text('Sem atendimentos ainda.'),
              for (final a in list)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(a.service.name),
                  subtitle: Text('${formatDate(a.startAt)} ${formatTime(a.startAt)} · ${a.professional.name} · ${formatMoney(a.price)}'
                      '${a.serviceNotes != null ? '\n📝 ${a.serviceNotes}' : ''}'),
                  isThreeLine: a.serviceNotes != null,
                  trailing: StatusChip(a.status),
                ),
            ],
          );
        },
      ),
    );
  }
}
