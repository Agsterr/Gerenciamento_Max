import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:salao_core/salao_core.dart';

/// Link para os clientes agendarem sozinhos: copiar e enviar pelo WhatsApp.
/// [compact] é a faixa baixa da Agenda; a de Ajustes é o cartão completo, com explicação.
class BookingLinkCard extends StatelessWidget {
  const BookingLinkCard({super.key, required this.link, this.compact = false});

  final String link;
  final bool compact;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) showMessage(context, 'Link copiado!');
  }

  void _whatsApp() => openUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent('Agende seu horário comigo: $link')}'));

  /// Faixa baixa para a Agenda: título e link à esquerda, "copiar" e "WhatsApp" como botões redondos.
  Widget _strip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        gradient: Brand.gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Brand.rose.withValues(alpha: 0.22), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: Row(children: [
        const Icon(Icons.link_rounded, color: Colors.white),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Link de agendamento',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            // o fim do endereço (/s/nome-do-salão) é o que identifica o salão: é ele que tem de aparecer inteiro
            Text('…${link.replaceFirst(RegExp(r'^https?://[^/]+'), '')}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(width: 6),
        IconButton.filled(
          tooltip: 'Copiar link',
          style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Brand.rose),
          icon: const Icon(Icons.copy_rounded, size: 20),
          onPressed: () => _copy(context),
        ),
        const SizedBox(width: 4),
        IconButton.filled(
          tooltip: 'Enviar pelo WhatsApp',
          style: IconButton.styleFrom(backgroundColor: Brand.whatsapp, foregroundColor: Colors.white),
          icon: const Icon(Icons.chat_rounded, size: 20),
          onPressed: _whatsApp,
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (compact) return _strip(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: Brand.gradient,
        borderRadius: BorderRadius.circular(24),
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
          'Compartilhe no Instagram, WhatsApp e Google. Seus clientes agendam sozinhos.',
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
              onPressed: () => _copy(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Brand.whatsapp, foregroundColor: Colors.white),
              icon: const Icon(Icons.chat_rounded),
              label: const Text('WhatsApp'),
              onPressed: _whatsApp,
            ),
          ),
        ]),
      ]),
    );
  }
}
