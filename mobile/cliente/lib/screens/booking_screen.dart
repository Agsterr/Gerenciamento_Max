import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key, required this.slug, required this.token, required this.api, this.justBooked = false});

  final String slug;
  final String token;
  final ApiClient api;
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

  @override
  Widget build(BuildContext context) {
    final b = _booking;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Agendamento')),
      body: _error != null
          ? ErrorRetry(message: _error!, onRetry: _load)
          : b == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    if (widget.justBooked && b.status != AppointmentStatus.canceled) ...[
                      Icon(Icons.check_circle, size: 64, color: Colors.green.shade600),
                      const SizedBox(height: 8),
                      Text('Tudo certo, ${b.customerName.split(' ').first}!', textAlign: TextAlign.center, style: text.headlineSmall),
                      const SizedBox(height: 24),
                    ],
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Text(b.serviceName, style: text.titleLarge),
                            const SizedBox(height: 8),
                            Text(formatWeekday(b.startAt)),
                            Text(formatTime(b.startAt), style: text.displaySmall),
                            Text('com ${b.professionalName}'),
                            Text(formatMoney(b.price)),
                            const SizedBox(height: 8),
                            StatusChip(b.status),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (b.cancelable)
                      OutlinedButton.icon(
                        onPressed: _cancel,
                        icon: const Icon(Icons.event_busy),
                        label: const Text('Cancelar agendamento'),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'O cancelamento pelo app é possível até 2 horas antes. Depois disso, fale com o salão.',
                      style: text.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
    );
  }
}
