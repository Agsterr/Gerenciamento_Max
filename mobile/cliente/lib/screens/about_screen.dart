import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../booking_store.dart';

/// Links legais exigidos pelas lojas e opção de apagar os dados locais.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, required this.store});

  final BookingStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sobre')),
      body: ListView(
        children: [
          const ListTile(
            title: Text('Salão Max'),
            subtitle: Text('Agende em salões de beleza sem precisar criar conta.'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Política de Privacidade'),
            onTap: () => openUrl(AppConfig.privacyUrl),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Termos de Uso'),
            onTap: () => openUrl(AppConfig.termsUrl),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Fale conosco / excluir meus dados no salão'),
            subtitle: const Text(AppConfig.supportEmail),
            onTap: () => openUrl(Uri(scheme: 'mailto', path: AppConfig.supportEmail, query: 'subject=Salão Max')),
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
            title: const Text('Apagar dados deste aparelho'),
            subtitle: const Text('Remove seus agendamentos salvos, nome e telefone do aparelho.'),
            onTap: () async {
              if (!await confirmDialog(context, 'Apagar os dados salvos neste aparelho?', confirm: 'Apagar', danger: true)) {
                return;
              }
              await store.clear();
              if (context.mounted) showMessage(context, 'Dados apagados.');
            },
          ),
        ],
      ),
    );
  }
}
