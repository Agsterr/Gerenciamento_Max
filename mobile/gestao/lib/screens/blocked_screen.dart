import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

/// Conta/salão bloqueado pelo super-admin (API 403 ACCOUNT_BLOCKED). Não fecha: só "Sair".
class BlockedScreen extends StatelessWidget {
  const BlockedScreen({super.key, required this.reason, required this.onSignOut});

  final String reason;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Brand.nightDeep,
        body: Container(
          decoration: const BoxDecoration(gradient: Brand.nightGradient),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Icon(Icons.lock_person_rounded, size: 56, color: Theme.of(context).colorScheme.error),
                      const SizedBox(height: 12),
                      Text('Sua conta foi bloqueada', textAlign: TextAlign.center, style: text.titleLarge),
                      const SizedBox(height: 10),
                      Text(reason, textAlign: TextAlign.center, style: text.bodyLarge),
                      const SizedBox(height: 16),
                      Text('Se acha que é um engano, fale com o suporte:',
                          textAlign: TextAlign.center, style: text.bodySmall?.copyWith(color: Brand.muted)),
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.mail_outline_rounded),
                        label: Text(AppConfig.supportEmail),
                        onPressed: () => openUrl(Uri(
                          scheme: 'mailto',
                          path: AppConfig.supportEmail,
                          query: 'subject=${Uri.encodeComponent('Conta bloqueada - Salão Max Gestão')}',
                        )),
                      ),
                      const SizedBox(height: 16),
                      GradientButton(label: 'Sair', icon: Icons.logout_rounded, onPressed: onSignOut),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
