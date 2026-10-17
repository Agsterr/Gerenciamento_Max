import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

/// Abre o seletor de horário do app (24h), limitando o tamanho da fonte para os botões
/// "Cancelar"/"OK" sempre caberem na tela, mesmo com a fonte do celular no máximo.
Future<String?> pickTime(BuildContext context, String? current, {String? help}) async {
  final parts = (current ?? '09:00').split(':');
  final t = await showTimePicker(
    context: context,
    helpText: help,
    initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        alwaysUse24HourFormat: true,
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.15),
      ),
      child: child!,
    ),
  );
  if (t == null) return null;
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// Grade semanal: cada dia aberto/fechado, com horário próprio e pausa opcional (almoço).
class WeeklyHoursEditor extends StatelessWidget {
  const WeeklyHoursEditor({super.key, required this.hours, required this.onChanged});

  final List<DayHours> hours;
  final ValueChanged<List<DayHours>> onChanged;

  static const _days = {1: 'Segunda', 2: 'Terça', 3: 'Quarta', 4: 'Quinta', 5: 'Sexta', 6: 'Sábado', 7: 'Domingo'};

  List<DayHours> _sorted(List<DayHours> l) => [...l]..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

  void _toggle(int day, DayHours? current) {
    if (current != null) {
      onChanged(hours.where((h) => h.dayOfWeek != day).toList());
    } else {
      final model = hours.isNotEmpty ? hours.first : DayHours(dayOfWeek: day, openTime: '09:00', closeTime: '18:00');
      onChanged(_sorted([...hours, model.copyFor(day)]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final byDay = {for (final h in hours) h.dayOfWeek: h};
    return Column(children: [
      for (final e in _days.entries)
        _DayRow(
          label: e.value,
          hours: byDay[e.key],
          canCopy: hours.length > 1,
          onToggle: () => _toggle(e.key, byDay[e.key]),
          onChanged: () => onChanged(_sorted(hours)),
          onCopyToAll: (h) => onChanged([for (final x in hours) h.copyFor(x.dayOfWeek)]),
        ),
    ]);
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.label,
    required this.hours,
    required this.canCopy,
    required this.onToggle,
    required this.onChanged,
    required this.onCopyToAll,
  });

  final String label;
  final DayHours? hours;
  final bool canCopy;
  final VoidCallback onToggle;
  final VoidCallback onChanged;
  final ValueChanged<DayHours> onCopyToAll;

  @override
  Widget build(BuildContext context) {
    final h = hours;
    final text = Theme.of(context).textTheme;
    Future<void> edit(String? current, String help, void Function(String) apply) async {
      final v = await pickTime(context, current, help: help);
      if (v != null) {
        apply(v);
        onChanged();
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 10),
      decoration: BoxDecoration(
        color: h != null ? Colors.white : const Color(0xFFFFFBFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Brand.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(label, style: text.titleSmall?.copyWith(color: h != null ? Brand.ink : Brand.muted)),
          ),
          Text(h != null ? 'Aberto' : 'Fechado',
              style: TextStyle(fontWeight: FontWeight.w700, color: h != null ? Brand.rose : Brand.muted)),
          Switch(value: h != null, onChanged: (_) => onToggle()),
        ]),
        if (h != null) ...[
          Wrap(spacing: 8, runSpacing: 8, children: [
            _TimeChip(label: 'Abre', value: h.openTime, onTap: () => edit(h.openTime, '$label — abre', (v) => h.openTime = v)),
            _TimeChip(label: 'Fecha', value: h.closeTime, onTap: () => edit(h.closeTime, '$label — fecha', (v) => h.closeTime = v)),
          ]),
          const SizedBox(height: 8),
          if (h.hasBreak)
            Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 8, children: [
              _TimeChip(
                  label: 'Pausa', value: h.breakStart!, tinted: true, onTap: () => edit(h.breakStart, '$label — início da pausa', (v) => h.breakStart = v)),
              _TimeChip(
                  label: 'até', value: h.breakEnd!, tinted: true, onTap: () => edit(h.breakEnd, '$label — fim da pausa', (v) => h.breakEnd = v)),
              TextButton(
                onPressed: () {
                  h.breakStart = null;
                  h.breakEnd = null;
                  onChanged();
                },
                child: const Text('Remover pausa'),
              ),
            ])
          else
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () {
                h.breakStart = '12:00';
                h.breakEnd = '13:00';
                onChanged();
              },
              icon: const Icon(Icons.restaurant_rounded, size: 18),
              label: const Text('Adicionar pausa (almoço)'),
            ),
          if (canCopy)
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: Brand.muted),
              onPressed: () => onCopyToAll(h),
              child: const Text('Usar este horário em todos os dias abertos'),
            ),
        ],
      ]),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.value, required this.onTap, this.tinted = false});

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool tinted;

  @override
  Widget build(BuildContext context) => Material(
        color: tinted ? const Color(0xFFFFF1F6) : const Color(0xFFF7F2FA),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('$label ', style: const TextStyle(color: Brand.muted, fontWeight: FontWeight.w600)),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Brand.ink)),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more_rounded, size: 18, color: Brand.muted),
            ]),
          ),
        ),
      );
}
