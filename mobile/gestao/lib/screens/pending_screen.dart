import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

/// Agendamentos feitos pelos clientes que ainda esperam o aceite do salão: aceitar ou recusar.
class PendingAcceptanceScreen extends StatefulWidget {
  const PendingAcceptanceScreen({super.key, required this.api, required this.items});

  final ApiClient api;
  final List<Appointment> items;

  @override
  State<PendingAcceptanceScreen> createState() => _PendingAcceptanceScreenState();
}

class _PendingAcceptanceScreenState extends State<PendingAcceptanceScreen> {
  late final List<Appointment> _items = [...widget.items];
  final Set<int> _busy = {};

  Future<void> _act(Appointment a, String action) async {
    if (action == 'cancel' &&
        !await confirmDialog(context, 'Recusar o horário de ${a.customer.name}? O cliente fica sabendo que foi cancelado.',
            confirm: 'Recusar', danger: true)) {
      return;
    }
    setState(() => _busy.add(a.id));
    try {
      await widget.api.post('/api/appointments/${a.id}/$action');
      if (!mounted) return;
      setState(() => _items.removeWhere((x) => x.id == a.id));
      showMessage(context, action == 'accept' ? 'Horário confirmado para ${a.customer.name}.' : 'Horário cancelado.');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy.remove(a.id));
    }
  }

  Future<void> _acceptAll() async {
    for (final a in [..._items]) {
      if (!mounted) return;
      setState(() => _busy.add(a.id));
      try {
        await widget.api.post('/api/appointments/${a.id}/accept');
        if (mounted) setState(() => _items.removeWhere((x) => x.id == a.id));
      } catch (e) {
        if (mounted) showError(context, e);
        break;
      } finally {
        if (mounted) setState(() => _busy.remove(a.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (_, _) {},
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Aguardando sua confirmação'),
          actions: [
            if (_items.length > 1) TextButton(onPressed: _acceptAll, child: const Text('Aceitar todos')),
          ],
        ),
        body: _items.isEmpty
            ? const EmptyState(
                icon: Icons.check_circle_outline_rounded,
                title: 'Tudo confirmado',
                message: 'Quando um cliente marcar um horário pelo app ou pelo site, ele aparece aqui para você aceitar.',
              )
            : ListView(padding: const EdgeInsets.all(16), children: [
                Text('O cliente vê "Aguardando confirmação do salão" até você aceitar.',
                    style: text.bodySmall?.copyWith(color: Brand.muted)),
                const SizedBox(height: 12),
                for (final a in _items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SoftCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(children: [
                          InitialsAvatar(a.customer.name, size: 42),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(a.customer.name, style: text.titleSmall),
                              Text('${a.service.name} · ${formatMoney(a.price)}',
                                  style: text.bodySmall?.copyWith(color: Brand.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ]),
                          ),
                          IconButton(
                            tooltip: 'Chamar no WhatsApp',
                            icon: const Icon(Icons.chat_rounded, color: Brand.whatsapp),
                            onPressed: () => openWhatsApp(a.customerPhone),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 4, children: [
                          Pill(formatShortDateTime(a.startAt), icon: Icons.event_rounded),
                          Pill(a.professional.name, icon: Icons.person_outline_rounded),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                              onPressed: _busy.contains(a.id) ? null : () => _act(a, 'cancel'),
                              icon: const Icon(Icons.close_rounded),
                              label: const Text('Recusar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _busy.contains(a.id) ? null : () => _act(a, 'accept'),
                              icon: _busy.contains(a.id)
                                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.check_rounded),
                              label: const Text('Aceitar'),
                            ),
                          ),
                        ]),
                      ]),
                    ),
                  ),
              ]),
      ),
    );
  }
}
