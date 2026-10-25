import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

/// Busca e histórico de agendamentos em qualquer data: por nome ou telefone do cliente, serviço ou
/// profissional, e por situação (a agenda mostra um dia; aqui dá para achar um atendimento antigo).
/// Tocar em um item fecha a tela e devolve o dia dele, para a agenda abrir naquela data.
class AppointmentSearchScreen extends StatefulWidget {
  const AppointmentSearchScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<AppointmentSearchScreen> createState() => _AppointmentSearchScreenState();
}

class _AppointmentSearchScreenState extends State<AppointmentSearchScreen> {
  /// (rótulo, status enviados à API; nulo = todos)
  static const _statusChips = <(String, String?)>[
    ('Todos', null),
    ('Agendados', 'SCHEDULED,CONFIRMED'),
    ('Em atendimento', 'IN_PROGRESS'),
    ('Finalizados', 'DONE'),
    ('Cancelados', 'CANCELED'),
    ('Faltas', 'NO_SHOW'),
  ];

  late final PagedController<Appointment> _list = PagedController(
    api: widget.api,
    path: '/api/appointments/search',
    parse: Appointment.fromJson,
    filters: {'order': 'desc'},
  )..addListener(_changed);

  void _changed() {
    if (mounted) setState(() {});
  }

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

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final newestFirst = _list.filter('order') != 'asc';
    final state = pagedStateOrNull(
      _list,
      empty: EmptyState(
        icon: Icons.event_busy_outlined,
        title: 'Nenhum agendamento',
        message: _list.query.isEmpty && _list.filter('status') == null
            ? 'Quando houver agendamentos, eles aparecem aqui.'
            : 'Nada encontrado com esse filtro. Tente outro nome, telefone ou situação.',
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar agendamentos')),
      body: NotificationListener<ScrollNotification>(
        onNotification: (n) => loadMoreOnScroll(n, _list),
        child: RefreshIndicator(
          onRefresh: _list.refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              TextField(
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Nome, telefone, serviço ou profissional',
                  prefixIcon: const Icon(Icons.search_rounded, color: Brand.rose),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onChanged: _list.search,
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final (label, status) in _statusChips)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: _list.filter('status') == status,
                        onSelected: (_) => _list.setFilter('status', status),
                      ),
                    ),
                ]),
              ),
              Row(children: [
                Expanded(
                  child: Text(
                    _list.loaded ? '${_list.total} agendamento(s)' : ' ',
                    style: text.bodySmall?.copyWith(color: Brand.muted),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _list.setFilter('order', newestFirst ? 'asc' : 'desc'),
                  icon: Icon(newestFirst ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 18),
                  label: Text(newestFirst ? 'Mais recentes' : 'Mais antigos'),
                ),
              ]),
              if (state != null)
                state
              else ...[
                for (final a in _list.items) _tile(a),
                PagedFooter(controller: _list, noun: 'agendamentos'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(Appointment a) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        padding: const EdgeInsets.all(12),
        onTap: () => Navigator.pop(context, a.startAt),
        child: Row(children: [
          InitialsAvatar(a.customer.name, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.customer.name, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('${formatShortDateTime(a.startAt)} · ${a.service.name}',
                  style: text.bodySmall?.copyWith(color: Brand.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text('com ${a.professional.name} · ${formatPhone(a.customerPhone)}',
                  style: text.bodySmall?.copyWith(color: Brand.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          StatusChip(a.status),
        ]),
      ),
    );
  }
}
