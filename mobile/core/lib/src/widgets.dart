import 'package:flutter/material.dart';

import 'models.dart';

/// Grade de horários livres.
class SlotGrid extends StatelessWidget {
  const SlotGrid({super.key, required this.slots, required this.selected, required this.onSelected});

  final List<Slot> slots;
  final String? selected;
  final ValueChanged<Slot> onSelected;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('Nenhum horário livre nesse dia.'),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in slots)
          ChoiceChip(
            label: Text(s.time),
            selected: s.time == selected,
            onSelected: (_) => onSelected(s),
          ),
      ],
    );
  }
}

/// Seletor horizontal de dias.
class DayPicker extends StatelessWidget {
  const DayPicker({super.key, required this.days, required this.selected, required this.onSelected, required this.label});

  final List<DateTime> days;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;
  final String Function(DateTime) label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = days[i];
          final active = selected != null && d.year == selected!.year && d.month == selected!.month && d.day == selected!.day;
          return Semantics(
            button: true,
            selected: active,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelected(d),
              child: Container(
                width: 56,
                decoration: BoxDecoration(
                  color: active ? scheme.primary : null,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: active ? scheme.primary : scheme.outlineVariant),
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label(d), style: TextStyle(fontSize: 12, color: active ? scheme.onPrimary : null)),
                    Text('${d.day}',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: active ? scheme.onPrimary : null)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      AppointmentStatus.scheduled => (Colors.blue.shade50, Colors.blue.shade800),
      AppointmentStatus.confirmed => (Colors.indigo.shade50, Colors.indigo.shade800),
      AppointmentStatus.inProgress => (Colors.amber.shade100, Colors.brown.shade800),
      AppointmentStatus.done => (Colors.green.shade50, Colors.green.shade800),
      AppointmentStatus.canceled => (Colors.grey.shade200, Colors.grey.shade700),
      AppointmentStatus.noShow => (Colors.red.shade50, Colors.red.shade800),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status.label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w500)),
    );
  }
}

/// Estado padrão de erro com botão de tentar novamente.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 40),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Tentar novamente')),
            ],
          ),
        ),
      );
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

/// Confirmação simples. Retorna true se o usuário confirmar.
Future<bool> confirmDialog(BuildContext context, String message, {String confirm = 'Confirmar', bool danger = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voltar')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}
