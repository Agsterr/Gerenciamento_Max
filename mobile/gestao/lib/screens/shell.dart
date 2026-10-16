import 'package:flutter/material.dart';

import '../session.dart';
import 'agenda_screen.dart';
import 'catalog_screen.dart';
import 'customers_screen.dart';
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
        (const NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Financeiro'),
            FinanceScreen(session: s)),
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
