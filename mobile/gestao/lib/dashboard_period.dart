import 'package:intl/intl.dart';

enum PeriodKind { day, week, month, year, custom }

/// Período do painel de atendimentos: hoje, semana (segunda a domingo), mês, ano ou datas escolhidas.
/// [shift] anda para o período anterior/seguinte (mesmo tipo).
class Period {
  const Period(this.kind, this.from, this.to);

  factory Period.of(PeriodKind kind, DateTime reference) {
    final d = DateTime(reference.year, reference.month, reference.day);
    return switch (kind) {
      PeriodKind.day => Period(kind, d, d),
      PeriodKind.week => Period(kind, d.subtract(Duration(days: d.weekday - 1)), d.add(Duration(days: 7 - d.weekday))),
      PeriodKind.month => Period(kind, DateTime(d.year, d.month), DateTime(d.year, d.month + 1, 0)),
      PeriodKind.year => Period(kind, DateTime(d.year), DateTime(d.year, 12, 31)),
      PeriodKind.custom => Period(kind, d, d),
    };
  }

  final PeriodKind kind;
  final DateTime from;
  final DateTime to;

  int get days => to.difference(from).inDays + 1;

  Period shift(int direction) => switch (kind) {
        PeriodKind.day => Period(kind, from.add(Duration(days: direction)), from.add(Duration(days: direction))),
        PeriodKind.week => Period.of(kind, from.add(Duration(days: 7 * direction))),
        PeriodKind.month => Period.of(kind, DateTime(from.year, from.month + direction)),
        PeriodKind.year => Period.of(kind, DateTime(from.year + direction)),
        PeriodKind.custom => Period(
            kind, from.add(Duration(days: days * direction)), to.add(Duration(days: days * direction))),
      };

  /// Como a API agrupa o gráfico: dia a dia até ~2 meses; depois semanas; anos por mês.
  String get group {
    if (days <= 62) return 'DAY';
    if (days <= 200) return 'WEEK';
    return 'MONTH';
  }

  /// "22/10/2026", "19 – 25 out 2026", "Outubro de 2026", "2026".
  String get label {
    final short = DateFormat('d MMM', 'pt_BR');
    String s(DateTime d) => short.format(d).replaceAll('.', '');
    return switch (kind) {
      PeriodKind.day => DateFormat("d 'de' MMMM", 'pt_BR').format(from),
      PeriodKind.week => '${s(from)} – ${s(to)}',
      PeriodKind.month => toBeginningOfSentenceCase(DateFormat("MMMM 'de' y", 'pt_BR').format(from)),
      PeriodKind.year => '${from.year}',
      PeriodKind.custom => '${s(from)} – ${s(to)} ${to.year}',
    };
  }

  /// Texto da comparação: "vs. semana anterior".
  String get previousLabel => switch (kind) {
        PeriodKind.day => 'vs. dia anterior',
        PeriodKind.week => 'vs. semana anterior',
        PeriodKind.month => 'vs. mês anterior',
        PeriodKind.year => 'vs. ano anterior',
        PeriodKind.custom => 'vs. período anterior',
      };

  @override
  bool operator ==(Object other) => other is Period && other.kind == kind && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(kind, from, to);
}
