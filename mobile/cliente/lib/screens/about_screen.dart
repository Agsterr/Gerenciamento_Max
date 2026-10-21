import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../booking_store.dart';
import '../promo_alerts.dart';

/// Links legais exigidos pelas lojas e opção de apagar os dados locais.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, required this.store, required this.api});

  final BookingStore store;
  final ApiClient api;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget tile(IconData icon, String title, String? subtitle, VoidCallback onTap, {Color? color}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SoftCard(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            onTap: onTap,
            child: ListTile(
              leading: Icon(icon, color: color ?? Brand.rose),
              title: Text(title, style: text.titleSmall?.copyWith(color: color)),
              subtitle: subtitle != null ? Text(subtitle) : null,
              trailing: const Icon(Icons.chevron_right_rounded),
            ),
          ),
        );

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            child: Column(children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Voltar',
                  color: Colors.white,
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset('assets/icon.png', width: 88, height: 88),
              ),
              const SizedBox(height: 12),
              Text('Salão Max', style: text.headlineSmall?.copyWith(color: Colors.white)),
              Text('Agende no seu salão favorito, sem cadastro.',
                  style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: ListenableBuilder(
                    listenable: store,
                    builder: (context, _) => SwitchListTile(
                      secondary: const Icon(Icons.notifications_active_outlined, color: Brand.rose),
                      title: Text('Avisos de promoção', style: text.titleSmall),
                      subtitle: const Text('Notificação quando um salão que você usa lança promoção'),
                      value: !store.promoAlertsOff,
                      onChanged: (on) async {
                        await store.setPromoAlertsOff(!on);
                        // cada salão fica sabendo da escolha
                        for (final s in store.salons) {
                          await sendPresence(api, store, s.slug);
                        }
                      },
                    ),
                  ),
                ),
              ),
              tile(Icons.privacy_tip_outlined, 'Política de Privacidade', null, () => openUrl(AppConfig.privacyUrl)),
              tile(Icons.description_outlined, 'Termos de Uso', null, () => openUrl(AppConfig.termsUrl)),
              tile(Icons.mail_outline_rounded, 'Fale conosco', 'Inclusive para excluir seus dados no salão',
                  () => openUrl(Uri(scheme: 'mailto', path: AppConfig.supportEmail, query: 'subject=Salão Max'))),
              tile(Icons.delete_forever_outlined, 'Apagar dados deste aparelho', 'Agendamentos salvos, nome e telefone', () async {
                if (!await confirmDialog(context, 'Apagar os dados salvos neste aparelho?', confirm: 'Apagar', danger: true)) return;
                await store.clear();
                if (context.mounted) showMessage(context, 'Dados apagados.');
              }, color: Theme.of(context).colorScheme.error),
              const SoftCard(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: AppVersionTile(app: 'cliente'),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
