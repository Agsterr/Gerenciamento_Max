import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salao_core/salao_core.dart';

import '../support/screenshot.dart';

/// Amostra dos temas de cor (cabeçalho, seletor, cartão, botões, chips, barra de baixo) em claro e escuro.
class _Sample extends StatelessWidget {
  const _Sample();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        GradientHeader(
          gradient: Brand.nightGradient,
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(gradient: Brand.gradient, shape: BoxShape.circle),
              child: const InitialsAvatar('Max Barbearia', size: 60),
            ),
            const SizedBox(width: 14),
            Text('Max Barbearia', style: text.titleLarge?.copyWith(color: Colors.white)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionTitle('Cor do aplicativo'),
            const SoftCard(child: ThemePicker()),
            const SizedBox(height: 14),
            SoftCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Corte masculino', style: text.titleMedium),
                const SizedBox(height: 4),
                Text('45 min · R\$ 50,00', style: text.bodySmall?.copyWith(color: Brand.muted)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, children: const [Chip(label: Text('Barba')), Chip(label: Text('Cabelo'))]),
              ]),
            ),
            const SizedBox(height: 14),
            GradientButton(label: 'Salvar', icon: Icons.check_rounded, onPressed: () {}),
            const SizedBox(height: 10),
            FilledButton(onPressed: () {}, child: const Text('Confirmar')),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: () {}, child: const Text('Cancelar')),
            const SizedBox(height: 10),
            TextField(decoration: const InputDecoration(labelText: 'Nome')),
          ]),
        ),
      ]),
      bottomNavigationBar: NavigationBar(selectedIndex: 0, destinations: const [
        NavigationDestination(icon: Icon(Icons.calendar_month_rounded), label: 'Agenda'),
        NavigationDestination(icon: Icon(Icons.people_alt_rounded), label: 'Clientes'),
        NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Ajustes'),
      ]),
    );
  }
}

void main() {
  for (final p in BrandPalette.all) {
    for (final dark in [true, false]) {
      testWidgets('tema ${p.id} ${dark ? 'escuro' : 'claro'}', (tester) async {
        Brand.palette = p;
        addTearDown(() => Brand.palette = BrandPalette.rosa);
        await shot(tester, const _Sample(), 'tema_${p.id}_${dark ? 'escuro' : 'claro'}', width: 360, height: 800, dark: dark);
      }, skip: !shotsEnabled);
    }
  }
}
