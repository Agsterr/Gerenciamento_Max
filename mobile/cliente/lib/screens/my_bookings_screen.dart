import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../booking_store.dart';
import 'booking_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key, required this.store, required this.api});

  final BookingStore store;
  final ApiClient api;

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
        return MapEntry(b.token, Booking.fromJson(json as Map<String, dynamic>));
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
    final saved = widget.store.bookings;
    if (saved.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Seus agendamentos feitos neste aparelho aparecem aqui.', textAlign: TextAlign.center),
        ),
      );
    }
    final now = DateTime.now();
    final sorted = [...saved]..sort((a, b) {
        final da = _details[a.token]?.startAt, db = _details[b.token]?.startAt;
        if (da == null || db == null) return 0;
        return db.compareTo(da);
      });

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(),
          for (final s in sorted)
            Dismissible(
              key: ValueKey(s.token),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                child: const Icon(Icons.delete_outline),
              ),
              onDismissed: (_) => widget.store.remove(s.token),
              child: _tile(s, _details[s.token], now),
            ),
          const SizedBox(height: 8),
          Text('Deslize para a esquerda para remover do aparelho.', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _tile(SavedBooking saved, Booking? b, DateTime now) {
    if (b == null) {
      return Card(child: ListTile(title: Text(saved.salonName), subtitle: Text(_loading ? 'Carregando...' : 'Agendamento indisponível')));
    }
    final past = b.endAt.isBefore(now);
    return Card(
      child: ListTile(
        enabled: !past || b.status == AppointmentStatus.done,
        title: Text('${b.serviceName} · ${saved.salonName}'),
        subtitle: Text('${formatDate(b.startAt)} às ${formatTime(b.startAt)} com ${b.professionalName}'),
        trailing: StatusChip(b.status),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BookingScreen(slug: saved.slug, token: saved.token, api: widget.api)),
          );
          _load();
        },
      ),
    );
  }
}
