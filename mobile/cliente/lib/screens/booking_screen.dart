import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import 'reschedule_sheet.dart';

/// Comprovante do agendamento (estilo "ingresso").
class BookingScreen extends StatefulWidget {
  const BookingScreen({
    super.key,
    required this.slug,
    required this.token,
    required this.api,
    this.salonName,
    this.justBooked = false,
  });

  final String slug;
  final String token;
  final ApiClient api;
  final String? salonName;
  final bool justBooked;

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  Booking? _booking;
  String? _error;

  String get _path => '/api/public/salons/${widget.slug}/bookings/${widget.token}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final b = Booking.fromJson(await widget.api.get(_path) as Map<String, dynamic>);
      if (mounted) setState(() => _booking = b);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _cancel() async {
    if (!await confirmDialog(context, 'Cancelar este agendamento?', confirm: 'Cancelar horário', danger: true)) return;
    try {
      final b = Booking.fromJson(await widget.api.post('$_path/cancel') as Map<String, dynamic>);
      if (mounted) setState(() => _booking = b);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _confirm() async {
    try {
      final b = Booking.fromJson(await widget.api.post('$_path/confirm') as Map<String, dynamic>);
      if (mounted) {
        setState(() => _booking = b);
        showMessage(context, 'Presença confirmada. O salão já foi avisado!');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _reschedule() async {
    final updated = await showRescheduleSheet(context, api: widget.api, slug: widget.slug, booking: _booking!);
    if (updated != null && mounted) {
      setState(() => _booking = updated);
      showMessage(context, 'Remarcado para ${formatShortDateTime(updated.startAt)}. O salão já foi avisado.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    if (_error != null) return Scaffold(appBar: AppBar(), body: ErrorRetry(message: _error!, onRetry: _load));
    if (b == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final text = Theme.of(context).textTheme;
    final canceled = b.status == AppointmentStatus.canceled;
    final title = canceled
        ? 'Agendamento cancelado'
        : (widget.justBooked ? 'Tudo certo, ${b.customerName.split(' ').first}!' : 'Seu agendamento');

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(children: [
            GradientHeader(
              gradient: canceled ? const LinearGradient(colors: [Color(0xFF8E8AA3), Color(0xFF5B5670)]) : Brand.gradient,
              bottomPadding: 120,
              child: Column(children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Voltar',
                    color: Colors.white,
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ),
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                  child: Icon(canceled ? Icons.event_busy_rounded : Icons.check_rounded, color: Colors.white, size: 48),
                ),
                const SizedBox(height: 14),
                Text(title, textAlign: TextAlign.center, style: text.headlineSmall?.copyWith(color: Colors.white)),
                const SizedBox(height: 4),
                Text(canceled ? 'Esperamos ver você em breve.' : 'Seu horário está reservado.',
                    style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
              ]),
            ),
          ]),
          Transform.translate(
            offset: const Offset(0, -96),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(children: [
                _Ticket(booking: b, salonName: widget.salonName, code: widget.token),
                const SizedBox(height: 20),
                if (b.confirmable) ...[
                  GradientButton(label: 'Confirmar presença', icon: Icons.check_circle_outline_rounded, onPressed: _confirm),
                  const SizedBox(height: 10),
                ] else if (b.status == AppointmentStatus.confirmed) ...[
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.verified_rounded, color: Brand.success),
                    const SizedBox(width: 6),
                    Text('Presença confirmada', style: text.titleSmall?.copyWith(color: Brand.success)),
                  ]),
                  const SizedBox(height: 14),
                ],
                if (b.cancelable) ...[
                  b.confirmable
                      ? SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _reschedule,
                            icon: const Icon(Icons.event_repeat_rounded),
                            label: const Text('Remarcar horário'),
                          ),
                        )
                      : GradientButton(label: 'Remarcar horário', icon: Icons.event_repeat_rounded, onPressed: _reschedule),
                  const SizedBox(height: 10),
                ],
                if (b.cancelable)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                      onPressed: _cancel,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Cancelar agendamento'),
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  'Remarcar ou cancelar pelo app até 2 horas antes. Depois disso, fale com o salão.',
                  style: text.bodySmall?.copyWith(color: Brand.muted),
                  textAlign: TextAlign.center,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ticket extends StatelessWidget {
  const _Ticket({required this.booking, required this.code, this.salonName});

  final Booking booking;
  final String code;
  final String? salonName;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Brand.violet.withValues(alpha: 0.18), blurRadius: 40, offset: const Offset(0, 16))],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(22),
          child: Column(children: [
            if (salonName != null)
              Text(salonName!.toUpperCase(),
                  style: text.labelMedium?.copyWith(color: Brand.rose, letterSpacing: 1.4, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(b.serviceName, style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            Row(children: [
              Container(
                width: 74,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(gradient: Brand.gradient, borderRadius: BorderRadius.circular(18)),
                child: Column(children: [
                  Text(formatMonthShort(b.startAt).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                  Text('${b.startAt.day}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28)),
                ]),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(formatWeekday(b.startAt), style: text.bodyMedium?.copyWith(color: Brand.muted)),
                  Text('${formatTime(b.startAt)} – ${formatTime(b.endAt)}', style: text.headlineSmall),
                ]),
              ),
            ]),
          ]),
        ),
        const _DashedDivider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 22),
          child: Row(children: [
            InitialsAvatar(b.professionalName, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Profissional', style: text.bodySmall?.copyWith(color: Brand.muted)),
                Text(b.professionalName, style: text.titleSmall),
              ]),
            ),
            Text(formatMoney(b.price), style: text.titleMedium?.copyWith(color: Brand.rose, fontWeight: FontWeight.w800)),
          ]),
        ),
        Padding(padding: const EdgeInsets.only(bottom: 14), child: Center(child: BookingStatusChip(b))),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF1F6),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Text('Código ${code.substring(0, 6).toUpperCase()}',
              textAlign: TextAlign.center, style: text.labelLarge?.copyWith(color: Brand.rose, letterSpacing: 2)),
        ),
      ]),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return SizedBox(
      height: 24,
      child: Stack(alignment: Alignment.center, children: [
        LayoutBuilder(builder: (context, c) {
          final count = (c.maxWidth / 12).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(count, (_) => Container(width: 6, height: 2, color: Brand.line)),
          );
        }),
        Positioned(left: -12, child: CircleAvatar(radius: 12, backgroundColor: bg)),
        Positioned(right: -12, child: CircleAvatar(radius: 12, backgroundColor: bg)),
      ]),
    );
  }
}
