import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

/// Avisos do salão: agendamentos, cancelamentos e remarcações feitos pelos clientes.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  Inbox? _inbox;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    // ao sair da tela, tudo que foi exibido conta como lido
    if (_inbox != null && _inbox!.unread > 0) widget.api.post('/api/notifications/read').catchError((_) => null);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final inbox = Inbox.fromJson(await widget.api.get('/api/notifications') as Map<String, dynamic>);
      if (mounted) setState(() => _inbox = inbox);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  static (IconData, Color) _style(String type) => switch (type) {
        'CANCELED' => (Icons.event_busy_rounded, const Color(0xFFBE123C)),
        'RESCHEDULED' => (Icons.event_repeat_rounded, const Color(0xFF6D28D9)),
        _ => (Icons.event_available_rounded, const Color(0xFF047857)),
      };

  @override
  Widget build(BuildContext context) {
    final inbox = _inbox;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: _error != null
          ? ErrorRetry(message: _error!, onRetry: _load)
          : inbox == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: inbox.items.isEmpty
                      ? ListView(children: const [
                          EmptyState(
                            icon: Icons.notifications_none_rounded,
                            title: 'Nada por aqui ainda',
                            message: 'Quando um cliente agendar, cancelar ou remarcar pelo link ou pelo app, aparece aqui.',
                          ),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: inbox.items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, i) {
                            final n = inbox.items[i];
                            final (icon, color) = _style(n.type);
                            return SoftCard(
                              padding: const EdgeInsets.all(14),
                              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Expanded(child: Text(n.title, style: text.titleSmall)),
                                      if (!n.read)
                                        Container(width: 10, height: 10, decoration: const BoxDecoration(color: Brand.rose, shape: BoxShape.circle)),
                                    ]),
                                    const SizedBox(height: 2),
                                    Text(n.message, style: text.bodyMedium),
                                    const SizedBox(height: 4),
                                    Text('${formatDate(n.createdAt)} ${formatTime(n.createdAt)}',
                                        style: text.bodySmall?.copyWith(color: Brand.muted)),
                                  ]),
                                ),
                              ]),
                            );
                          },
                        ),
                ),
    );
  }
}
