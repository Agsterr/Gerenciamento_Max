import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:salao_core/salao_core.dart';

import '../dashboard_period.dart';
import '../report_pdf.dart';
import '../push.dart';
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
    // avisos na hora pelo servidor (Firebase), quando o build tem a configuração
    Push.start(widget.session);
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
class PanelScreen extends StatefulWidget {
  const PanelScreen({super.key, required this.session});

  final Session session;

  @override
  State<PanelScreen> createState() => _PanelScreenState();
}

class _PanelScreenState extends State<PanelScreen> {
  Session get session => widget.session;
  bool _generating = false;

  /// Escolhe o período e gera o relatório em PDF (atendimentos + financeiro) para compartilhar ou imprimir.
  Future<void> _pdf() async {
    final period = await showModalBottomSheet<Period>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _PdfPeriodSheet(),
    );
    if (period == null || !mounted) return;
    setState(() => _generating = true);
    try {
      final q = 'from=${isoDate(period.from)}&to=${isoDate(period.to)}';
      final r = await Future.wait([
        session.api.get('/api/reports/summary?$q'),
        session.api.get('/api/reports/dashboard?$q&group=${period.group}'),
        session.api.get('/api/salon'),
      ]);
      final bytes = await buildReportPdf(
        salonName: (r[2] as Map<String, dynamic>)['name'] as String,
        from: period.from,
        to: period.to,
        summary: Summary(r[0] as Map<String, dynamic>),
        attendance: AttendanceDashboard.fromJson(r[1] as Map<String, dynamic>),
      );
      await Printing.sharePdf(bytes: bytes, filename: 'relatorio-${isoDate(period.from)}-a-${isoDate(period.to)}.pdf');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

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
              Row(children: [
                Expanded(child: Text('Painel', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white))),
                if (_generating)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                  )
                else
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.white.withValues(alpha: 0.14)),
                    onPressed: _pdf,
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                    label: const Text('Relatório PDF'),
                  ),
              ]),
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

/// Períodos prontos para o relatório em PDF (ou escolher as datas).
class _PdfPeriodSheet extends StatelessWidget {
  const _PdfPeriodSheet();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final month = Period.of(PeriodKind.month, now);
    final options = <(String, Period)>[
      ('Hoje', Period.of(PeriodKind.day, now)),
      ('Esta semana', Period.of(PeriodKind.week, now)),
      ('Semana passada', Period.of(PeriodKind.week, now).shift(-1)),
      ('Este mês', month),
      ('Mês passado', month.shift(-1)),
      ('Este ano', Period.of(PeriodKind.year, now)),
    ];
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Relatório em PDF — qual período?', style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          for (final (label, p) in options)
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined, color: Brand.rose),
              title: Text(label),
              subtitle: Text(p.label),
              onTap: () => Navigator.pop(context, p),
            ),
          ListTile(
            leading: const Icon(Icons.date_range_rounded, color: Brand.rose),
            title: const Text('Escolher datas'),
            onTap: () async {
              final r = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2024),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (r != null && context.mounted) Navigator.pop(context, Period(PeriodKind.custom, r.start, r.end));
            },
          ),
        ]),
      ),
    );
  }
}
