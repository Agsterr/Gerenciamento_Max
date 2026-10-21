import 'package:flutter/material.dart';

import 'format.dart';
import 'models.dart';
import 'theme.dart';

/// Cabeçalho com gradiente e cantos arredondados, usado no topo das telas principais.
class GradientHeader extends StatelessWidget {
  const GradientHeader({super.key, required this.child, this.gradient = Brand.gradient, this.bottomPadding = 28});

  final Widget child;
  final Gradient gradient;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          // brilhos decorativos
          Positioned(right: -40, top: -30, child: _Glow(size: 180, opacity: 0.18)),
          Positioned(left: -60, bottom: -70, child: _Glow(size: 200, opacity: 0.10)),
          SafeArea(
            bottom: false,
            child: Padding(padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding), child: child),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [Colors.white.withValues(alpha: opacity), Colors.white.withValues(alpha: 0)]),
          ),
        ),
      );
}

/// Cartão branco com sombra suave.
class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.border, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final BoxBorder? border;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: color ?? scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: border,
        boxShadow: Brand.softShadow(),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Botão principal com gradiente da marca.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, required this.onPressed, this.icon, this.loading = false, this.gradient = Brand.gradient});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1 : 0.5,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: enabled
                ? [BoxShadow(color: Brand.rose.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: enabled ? onPressed : null,
              child: Center(
                child: loading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
                        Flexible(
                          child: Text(
                            label,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ),
                      ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar com iniciais sobre gradiente (cor estável por nome).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.name, {super.key, this.size = 44, this.icon});

  final String name;
  final double size;
  final IconData? icon;

  static String initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Brand.avatarGradients[name.codeUnits.fold(0, (a, b) => a + b) % Brand.avatarGradients.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
      ),
      alignment: Alignment.center,
      child: icon != null
          ? Icon(icon, color: Colors.white, size: size * 0.5)
          : Text(initials(name),
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
    );
  }
}

/// Ícone em círculo tingido, escolhido pelo nome do serviço.
class ServiceIcon extends StatelessWidget {
  const ServiceIcon(this.serviceName, {super.key, this.size = 48, this.selected = false});

  final String serviceName;
  final double size;
  final bool selected;

  static IconData iconFor(String name) {
    final n = name.toLowerCase();
    if (RegExp('unha|manicure|pedicure|esmalt|gel').hasMatch(n)) return Icons.back_hand_outlined;
    if (RegExp('barba|bigode').hasMatch(n)) return Icons.face_6_outlined;
    if (RegExp('maqui|make').hasMatch(n)) return Icons.brush_outlined;
    if (RegExp('sobrancelha|cílio|cilio|lash').hasMatch(n)) return Icons.remove_red_eye_outlined;
    if (RegExp('massag|depila|spa|limpeza|pele|facial').hasMatch(n)) return Icons.spa_outlined;
    if (RegExp('escova|chapinha|hidrat|progressiva|selagem').hasMatch(n)) return Icons.air;
    if (RegExp('corte|cabelo|franja').hasMatch(n)) return Icons.content_cut;
    if (RegExp('colora|tintura|luzes|mecha|balayage|loiro|tonal').hasMatch(n)) return Icons.palette_outlined;
    return Icons.auto_awesome_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: selected ? Brand.gradient : null,
        color: selected ? null : const Color(0xFFFFEAF2),
      ),
      child: Icon(iconFor(serviceName), color: selected ? Colors.white : Brand.rose, size: size * 0.5),
    );
  }
}

/// Título de seção com ação opcional.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(4, 24, 4, 12)});

  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
          ?trailing,
        ]),
      );
}

/// Etiqueta pequena arredondada.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.icon, this.color, this.textColor});

  final String text;
  final IconData? icon;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final fg = textColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color ?? const Color(0xFFF6EEF3), borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }
}

/// Estado vazio com ícone em gradiente.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: Brand.gradient,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Brand.rose.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10))],
          ),
          child: Icon(icon, color: Colors.white, size: 40),
        ),
        const SizedBox(height: 20),
        Text(title, style: text.titleLarge, textAlign: TextAlign.center),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(message!, style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
        ],
        if (action != null) ...[const SizedBox(height: 20), action!],
      ]),
    );
  }
}

/// Grade de horários livres.
class SlotGrid extends StatelessWidget {
  const SlotGrid({super.key, required this.slots, required this.selected, required this.onSelected});

  final List<Slot> slots;
  final String? selected;
  final ValueChanged<Slot> onSelected;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: const Color(0xFFFFF1F6), borderRadius: BorderRadius.circular(16)),
        child: const Column(children: [
          Icon(Icons.event_busy_outlined, color: Brand.rose),
          SizedBox(height: 8),
          Text('Nenhum horário livre nesse dia.\nTente outro dia ou profissional.', textAlign: TextAlign.center),
        ]),
      );
    }
    return LayoutBuilder(builder: (context, c) {
      final columns = (c.maxWidth / 84).floor().clamp(3, 6);
      final width = (c.maxWidth - (columns - 1) * 10) / columns;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final s in slots)
            _SlotPill(time: s.time, width: width, selected: s.time == selected, onTap: () => onSelected(s)),
        ],
      );
    });
  }
}

class _SlotPill extends StatelessWidget {
  const _SlotPill({required this.time, required this.width, required this.selected, required this.onTap});

  final String time;
  final double width;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: time,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: width,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? Brand.gradient : null,
            color: selected ? null : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: selected ? null : Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1.5),
            boxShadow: selected ? [BoxShadow(color: Brand.rose.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))] : null,
          ),
          child: Text(
            time,
            style: TextStyle(fontWeight: FontWeight.w800, color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}

/// Seletor horizontal de dias.
class DayPicker extends StatelessWidget {
  const DayPicker({super.key, required this.days, required this.selected, required this.onSelected, this.dark = false});

  final List<DateTime> days;
  final DateTime? selected;
  final ValueChanged<DateTime> onSelected;

  /// Versão para usar sobre fundo escuro/gradiente.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = dateOnly(DateTime.now());
    return SizedBox(
      height: 82,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final d = days[i];
          final active = selected != null && dateOnly(selected!) == dateOnly(d);
          final isToday = dateOnly(d) == today;
          final fg = active ? Colors.white : (dark ? Colors.white : scheme.onSurface);
          return Semantics(
            button: true,
            selected: active,
            label: formatWeekday(d),
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => onSelected(d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 60,
                decoration: BoxDecoration(
                  gradient: active ? (dark ? null : Brand.gradient) : null,
                  color: active
                      ? (dark ? Colors.white : null)
                      : (dark ? Colors.white.withValues(alpha: 0.12) : scheme.surface),
                  borderRadius: BorderRadius.circular(18),
                  border: active || dark ? null : Border.all(color: scheme.outlineVariant, width: 1.5),
                  boxShadow: active && !dark
                      ? [BoxShadow(color: Brand.rose.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
                      : null,
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(isToday ? 'hoje' : formatWeekdayShort(d),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active && dark ? Brand.rose : fg.withValues(alpha: 0.8))),
                  const SizedBox(height: 2),
                  Text('${d.day}',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: active && dark ? Brand.night : fg)),
                ]),
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

  static (Color, Color) colors(AppointmentStatus s) => switch (s) {
        AppointmentStatus.scheduled => (const Color(0xFFE8F1FF), const Color(0xFF1D5BD8)),
        AppointmentStatus.confirmed => (const Color(0xFFEDE9FE), const Color(0xFF6D28D9)),
        AppointmentStatus.inProgress => (const Color(0xFFFFF4DB), const Color(0xFFB45309)),
        AppointmentStatus.done => (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
        AppointmentStatus.canceled => (const Color(0xFFF1F0F4), const Color(0xFF6B6880)),
        AppointmentStatus.noShow => (const Color(0xFFFFE4E6), const Color(0xFFBE123C)),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = colors(status);
    return Pill(status.label, color: bg, textColor: fg);
  }
}

/// Estado padrão de erro com botão de tentar novamente.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: EmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'Ops! Algo deu errado',
          message: message,
          action: OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Tentar novamente')),
        ),
      );
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.error_outline, color: Colors.white),
      const SizedBox(width: 10),
      Expanded(child: Text(error.toString())),
    ]),
  ));
}

void showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      const Icon(Icons.check_circle_outline, color: Colors.white),
      const SizedBox(width: 10),
      Expanded(child: Text(message)),
    ]),
  ));
}

/// Confirmação simples. Retorna true se o usuário confirmar.
Future<bool> confirmDialog(BuildContext context, String message, {String confirm = 'Confirmar', bool danger = false}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message, style: Theme.of(context).textTheme.titleMedium),
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

/// Espaço no rodapé de janelas inferiores: teclado aberto ou, sem ele, a barra de navegação do Android
/// (o app desenha atrás dela), para o botão principal nunca ficar coberto.
double sheetBottomInset(BuildContext context) {
  final insets = MediaQuery.viewInsetsOf(context).bottom;
  final nav = MediaQuery.viewPaddingOf(context).bottom;
  return insets > nav ? insets : nav;
}
