import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../booking_store.dart';
import 'booking_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key, required this.store, required this.api, required this.onBookNow});

  final BookingStore store;
  final ApiClient api;
  final VoidCallback onBookNow;

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  /// token -> agendamento (null = não encontrado, ex.: salão excluído)
  Map<String, Booking?> _details = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.store.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.store.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await Future.wait(widget.store.bookings.map((b) async {
      try {
        final json = await widget.api.get('/api/public/salons/${b.slug}/bookings/${b.token}');
        return MapEntry<String, Booking?>(b.token, Booking.fromJson(json as Map<String, dynamic>));
      } on ApiException catch (e) {
        if (e.status == 404) return MapEntry<String, Booking?>(b.token, null);
        rethrow;
      }
    }).toList()).catchError((Object e) {
      if (mounted) showError(context, e);
      return <MapEntry<String, Booking?>>[];
    });
    if (mounted) {
      setState(() {
        _details = Map.fromEntries(entries);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final saved = widget.store.bookings;
    final now = DateTime.now();
    final withDetails = [
      for (final s in saved)
        if (_details[s.token] != null) (s, _details[s.token]!),
    ];
    final upcoming = withDetails.where((e) => e.$2.endAt.isAfter(now) && e.$2.status != AppointmentStatus.canceled).toList()
      ..sort((a, b) => a.$2.startAt.compareTo(b.$2.startAt));
    final past = withDetails.where((e) => !upcoming.contains(e)).toList()..sort((a, b) => b.$2.startAt.compareTo(a.$2.startAt));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          GradientHeader(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 8),
              Text('Meus horários', style: text.headlineMedium?.copyWith(color: Colors.white)),
              const SizedBox(height: 4),
              Text(
                upcoming.isEmpty ? 'Nenhum horário marcado' : '${upcoming.length} próximo(s) agendamento(s)',
                style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
              ),
            ]),
          ),
          if (_loading && saved.isNotEmpty) const LinearProgressIndicator(),
          if (saved.isEmpty)
            EmptyState(
              icon: Icons.confirmation_number_outlined,
              title: 'Nada por aqui ainda',
              message: 'Quando você agendar, seus horários aparecem aqui para consultar ou cancelar.',
              action: SizedBox(width: 220, child: GradientButton(label: 'Agendar agora', icon: Icons.search_rounded, onPressed: widget.onBookNow)),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (upcoming.isNotEmpty) const SectionTitle('Próximos'),
                for (final e in upcoming) _item(e.$1, e.$2, highlight: true),
                if (past.isNotEmpty) const SectionTitle('Histórico'),
                for (final e in past) _item(e.$1, e.$2),
                const SizedBox(height: 8),
                Text('Deslize para a esquerda para remover do aparelho.',
                    textAlign: TextAlign.center, style: text.bodySmall?.copyWith(color: Brand.muted)),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _item(SavedBooking s, Booking b, {bool highlight = false}) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey(s.token),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(color: const Color(0xFFFFE4E6), borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFBE123C)),
        ),
        onDismissed: (_) => widget.store.remove(s.token),
        child: SoftCard(
          padding: const EdgeInsets.all(12),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => BookingScreen(slug: s.slug, token: s.token, api: widget.api, salonName: s.salonName)),
            );
            _load();
          },
          child: Row(children: [
            Container(
              width: 62,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                gradient: highlight ? Brand.gradient : null,
                color: highlight ? null : const Color(0xFFF6EEF3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(children: [
                Text(formatMonthShort(b.startAt).toUpperCase(),
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: highlight ? Colors.white : Brand.muted)),
                Text('${b.startAt.day}',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: highlight ? Colors.white : Brand.ink)),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.serviceName, style: text.titleSmall),
                Text('${formatTime(b.startAt)} · ${s.salonName}',
                    style: text.bodySmall?.copyWith(color: Brand.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                StatusChip(b.status),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: Brand.muted),
          ]),
        ),
      ),
    );
  }
}
