import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

/// Clientes de amanhã/depois de amanhã: abre o WhatsApp com a mensagem e o link de confirmação prontos.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  ReminderMode? _mode;
  List<int> _days = const [];
  List<ReminderItem>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final json = await widget.api.get('/api/reminders') as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _mode = ReminderMode.parse(json['mode'] as String?);
        _days = (json['days'] as List).cast<int>();
        _items = (json['items'] as List).map((e) => ReminderItem.fromJson(e as Map<String, dynamic>)).toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _send(ReminderItem item) async {
    await openUrl(Uri.parse(item.whatsappUrl));
    try {
      await widget.api.post('/api/reminders/${item.appointmentId}/sent');
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Lembretes dos clientes')),
      body: _error != null
          ? ErrorRetry(message: _error!, onRetry: _load)
          : items == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(16), children: [
                    Text(
                      'Lembrete: ${_mode?.label ?? ''}. Mande a mensagem pelo WhatsApp: o cliente confirma pelo link '
                      'e aparece como Confirmado na agenda. Quem tem o app também recebe o aviso no celular.',
                      style: text.bodySmall?.copyWith(color: Brand.muted),
                    ),
                    if (_mode == ReminderMode.off)
                      const EmptyState(
                        icon: Icons.notifications_off_outlined,
                        title: 'Lembrete desligado',
                        message: 'O dono do salão liga em Ajustes → Funcionamento.',
                      )
                    else if (items.isEmpty)
                      const EmptyState(
                        icon: Icons.event_available_rounded,
                        title: 'Ninguém para lembrar',
                        message: 'Os horários dos próximos dias aparecem aqui.',
                      ),
                    for (final d in _days)
                      if (items.any((i) => i.daysBefore == d)) ...[
                        SectionTitle(d == 1 ? 'Amanhã' : 'Depois de amanhã'),
                        for (final i in items.where((i) => i.daysBefore == d)) _tile(i),
                      ],
                  ]),
                ),
    );
  }

  Widget _tile(ReminderItem i) {
    final text = Theme.of(context).textTheme;
    final confirmed = i.status == AppointmentStatus.confirmed;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          InitialsAvatar(i.customerName, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(i.customerName, style: text.titleSmall),
              Text('${formatTime(i.startAt)} · ${i.serviceName} com ${i.professionalName}',
                  style: text.bodySmall?.copyWith(color: Brand.muted)),
              const SizedBox(height: 6),
              if (confirmed)
                Pill(i.customerConfirmed ? 'Cliente confirmou' : 'Confirmado',
                    icon: Icons.verified_rounded, color: const Color(0xFFDCFCE7), textColor: const Color(0xFF047857))
              else if (i.reminderSent)
                const Pill('Lembrete enviado', icon: Icons.mark_chat_read_outlined),
            ]),
          ),
          if (!confirmed)
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Brand.whatsapp),
              onPressed: () => _send(i),
              icon: const Icon(Icons.chat_rounded, size: 18),
              label: Text(i.reminderSent ? 'Reenviar' : 'Enviar'),
            ),
        ]),
      ),
    );
  }
}
