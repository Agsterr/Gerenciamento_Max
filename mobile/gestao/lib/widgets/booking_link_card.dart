import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:salao_core/salao_core.dart';

/// Link para os clientes agendarem sozinhos: copiar e enviar pelo WhatsApp.
/// [compact] é a versão da Agenda (título e botões numa faixa só); a de Ajustes explica mais.
class BookingLinkCard extends StatelessWidget {
  const BookingLinkCard({super.key, required this.link, this.compact = false});

  final String link;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        gradient: Brand.gradient,
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        boxShadow: [BoxShadow(color: Brand.rose.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.link_rounded, color: Colors.white),
          SizedBox(width: 8),
          Expanded(
            child: Text('Seu link de agendamento',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          compact
              ? 'Mande para seus clientes agendarem sozinhos.'
              : 'Compartilhe no Instagram, WhatsApp e Google. Seus clientes agendam sozinhos.',
          style: text.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
          child: Text(link, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Brand.rose),
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copiar'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (context.mounted) showMessage(context, 'Link copiado!');
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Brand.whatsapp, foregroundColor: Colors.white),
              icon: const Icon(Icons.chat_rounded),
              label: const Text('WhatsApp'),
              onPressed: () => openUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent('Agende seu horário comigo: $link')}')),
            ),
          ),
        ]),
      ]),
    );
  }
}
