import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../session.dart';
import '../staff_reminders.dart';
import 'agenda_screen.dart';
import 'catalog_screen.dart';
import 'customers_screen.dart';
import 'dashboard_screen.dart';
import 'finance_screen.dart';
import 'settings_screen.dart';

class Shell extends StatefulWidget {
  const Shell({super.key, required this.session});

  final Session session;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // lembretes de atendimento do usuário agendados no celular (atualiza a cada abertura)
    syncStaffReminders(widget.session.api);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final owner = s.user.isOwner;
    final tabs = <(NavigationDestination, Widget)>[
      (const NavigationDestination(icon: Icon(Icons.calendar_today_outlined), selectedIcon: Icon(Icons.calendar_today), label: 'Agenda'),
          AgendaScreen(session: s)),
      (const NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Clientes'),
          CustomersScreen(session: s)),
      (const NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Cadastros'),
          CatalogScreen(session: s)),
      if (owner)
        (const NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Painel'),
            PanelScreen(session: s)),
      (const NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Ajustes'),
          SettingsScreen(session: s)),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: [for (final t in tabs) t.$2]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [for (final t in tabs) t.$1],
      ),
    );
  }
}

/// Painel do dono: atendimentos (quantidades) e financeiro (valores), cada um na sua aba.
class PanelScreen extends StatelessWidget {
  const PanelScreen({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(children: [
          GradientHeader(
            gradient: Brand.nightGradient,
            bottomPadding: 16,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Painel', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(gradient: Brand.gradient, borderRadius: BorderRadius.circular(12)),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white70,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                  tabs: const [Tab(text: 'Atendimentos'), Tab(text: 'Financeiro')],
                ),
              ),
            ]),
          ),
          Expanded(
            child: TabBarView(children: [DashboardScreen(session: session), FinanceScreen(session: session)]),
          ),
        ]),
      ),
    );
  }
}
