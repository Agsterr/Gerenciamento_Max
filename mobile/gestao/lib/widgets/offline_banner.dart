import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

/// Faixa no topo: sem internet (mostrando o que está guardado), alterações esperando envio ou recusadas pelo servidor.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, required this.api});

  final ApiClient api;

  static bool visibleFor(ApiStatus s) => s.failures.isNotEmpty || !s.online || s.pending > 0;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ApiStatus>(
        valueListenable: api.status,
        builder: (context, s, _) {
          final String? message;
          final Color bg, fg;
          final IconData icon;
          if (s.failures.isNotEmpty) {
            message = s.failures.length == 1
                ? 'Uma alteração feita sem internet não foi aceita: ${s.failures.first}'
                : '${s.failures.length} alterações feitas sem internet não foram aceitas. Confira a agenda.';
            (bg, fg, icon) = (const Color(0xFFFFE4E6), const Color(0xFF9F1239), Icons.error_outline_rounded);
          } else if (!s.online) {
            message = s.pending > 0
                ? 'Sem internet. ${s.pending == 1 ? '1 alteração guardada' : '${s.pending} alterações guardadas'}: enviamos quando conectar.'
                : 'Sem internet. Mostrando o que está guardado no celular.';
            (bg, fg, icon) = (const Color(0xFFFFF3C4), const Color(0xFF7C4A03), Icons.cloud_off_rounded);
          } else if (s.pending > 0) {
            message = s.pending == 1 ? 'Enviando 1 alteração feita sem internet...' : 'Enviando ${s.pending} alterações feitas sem internet...';
            (bg, fg, icon) = (const Color(0xFFDDEEFF), const Color(0xFF0B4A86), Icons.cloud_upload_outlined);
          } else {
            return const SizedBox.shrink();
          }
          return Material(
            color: bg,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                child: Row(children: [
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 8),
                  Expanded(child: Text(message, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13))),
                  if (s.failures.isNotEmpty)
                    IconButton(
                      tooltip: 'Fechar aviso',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close_rounded, size: 18, color: fg),
                      onPressed: api.clearFailures,
                    ),
                ]),
              ),
            ),
          );
        },
      );
}
