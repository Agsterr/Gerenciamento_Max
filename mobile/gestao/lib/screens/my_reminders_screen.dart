import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../staff_reminders.dart';

/// "Meus lembretes": quando o próprio profissional quer ser avisado dos atendimentos dele.
class MyRemindersScreen extends StatefulWidget {
  const MyRemindersScreen({super.key, required this.api});

  final ApiClient api;

  @override
  State<MyRemindersScreen> createState() => _MyRemindersScreenState();
}

class _MyRemindersScreenState extends State<MyRemindersScreen> {
  static const maxRules = 5;

  static const presets = [
    StaffReminderRule.daysBefore(1, '19:00'),
    StaffReminderRule.daysBefore(0, '08:00'),
    StaffReminderRule.minutesBefore(120),
    StaffReminderRule.minutesBefore(30),
  ];

  StaffReminderSettings? _settings;
  List<Professional> _professionals = const [];
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([widget.api.get('/api/me/reminders'), widget.api.get('/api/professionals')]);
      if (!mounted) return;
      setState(() {
        _settings = StaffReminderSettings.fromJson(results[0] as Map<String, dynamic>);
        _professionals = (results[1] as List)
            .map((e) => Professional.fromJson(e as Map<String, dynamic>))
            .where((p) => p.active)
            .toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final json = await widget.api.put('/api/me/reminders', _settings!.toJson()) as Map<String, dynamic>;
      final saved = StaffReminderSettings.fromJson(json);
      if (saved.rules.isNotEmpty) await LocalReminders.instance.requestPermission();
      await syncStaffReminders(widget.api);
      if (!mounted) return;
      setState(() => _settings = saved);
      showMessage(context, 'Salvo! Você recebe o aviso no celular e no sino.');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addCustom() async {
    var days = 1;
    var time = const TimeOfDay(hour: 19, minute: 0);
    var minutes = 60;
    var relative = false;
    final rule = await showModalBottomSheet<StaffReminderRule>(
      context: context,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Novo lembrete', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Dia e horário')),
                ButtonSegment(value: true, label: Text('Tempo antes')),
              ],
              selected: {relative},
              onSelectionChanged: (s) => setSheet(() => relative = s.first),
            ),
            const SizedBox(height: 16),
            if (relative)
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: minutes,
                decoration: const InputDecoration(labelText: 'Antecedência'),
                items: [
                  for (final m in [15, 30, 45, 60, 90, 120, 180, 240, 360, 720])
                    DropdownMenuItem(value: m, child: Text(StaffReminderRule.minutesBefore(m).label)),
                ],
                onChanged: (v) => setSheet(() => minutes = v!),
              )
            else ...[
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: days,
                decoration: const InputDecoration(labelText: 'Dia'),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('No próprio dia')),
                  DropdownMenuItem(value: 1, child: Text('1 dia antes')),
                  DropdownMenuItem(value: 2, child: Text('2 dias antes')),
                  DropdownMenuItem(value: 3, child: Text('3 dias antes')),
                  DropdownMenuItem(value: 7, child: Text('7 dias antes')),
                ],
                onChanged: (v) => setSheet(() => days = v!),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.schedule_rounded),
                label: Text('Às ${time.format(context)}'),
                onPressed: () async {
                  final picked = await showTimePicker(context: context, initialTime: time);
                  if (picked != null) setSheet(() => time = picked);
                },
              ),
            ],
            const SizedBox(height: 20),
            GradientButton(
              label: 'Adicionar',
              icon: Icons.add_rounded,
              onPressed: () => Navigator.pop(
                context,
                relative
                    ? StaffReminderRule.minutesBefore(minutes)
                    : StaffReminderRule.daysBefore(
                        days, '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'),
              ),
            ),
          ]),
        ),
      ),
    );
    if (rule != null) setState(() => _settings!.rules = [..._settings!.rules, rule]);
  }

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Meus lembretes')),
      body: _error != null
          ? ErrorRetry(message: _error!, onRetry: _load)
          : s == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: const EdgeInsets.all(16), children: [
                  Text('Escolha quando você quer ser avisado dos seus atendimentos. Só você recebe.',
                      style: text.bodySmall?.copyWith(color: Brand.muted)),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    initialValue: _professionals.any((p) => p.id == s.professionalId) ? s.professionalId : null,
                    decoration: const InputDecoration(labelText: 'Agenda', prefixIcon: Icon(Icons.person_outline_rounded)),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Todos os profissionais')),
                      for (final p in _professionals) DropdownMenuItem<int?>(value: p.id, child: Text('Só ${p.name}')),
                    ],
                    onChanged: (v) => setState(() => s.professionalId = v),
                  ),
                  const SectionTitle('Avisar'),
                  if (s.rules.isEmpty)
                    Text('Nenhum lembrete ainda. Escolha abaixo.', style: text.bodyMedium?.copyWith(color: Brand.muted)),
                  for (final (i, r) in s.rules.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SoftCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        child: Row(children: [
                          Icon(r.relative ? Icons.timer_outlined : Icons.event_rounded, color: Brand.rose),
                          const SizedBox(width: 12),
                          Expanded(child: Text(r.label, style: text.titleSmall)),
                          IconButton(
                            tooltip: 'Remover',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(() => s.rules = [...s.rules]..removeAt(i)),
                          ),
                        ]),
                      ),
                    ),
                  if (s.rules.length < maxRules) ...[
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final p in presets)
                        ActionChip(label: Text(p.label), onPressed: () => setState(() => s.rules = [...s.rules, p])),
                      ActionChip(avatar: const Icon(Icons.tune_rounded, size: 18), label: const Text('Outro...'), onPressed: _addCustom),
                    ]),
                  ],
                  const SizedBox(height: 24),
                  GradientButton(label: 'Salvar', icon: Icons.save_outlined, onPressed: _busy ? null : _save),
                ]),
    );
  }
}
