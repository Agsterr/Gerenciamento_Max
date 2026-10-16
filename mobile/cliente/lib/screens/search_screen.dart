import 'dart:async';

import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../booking_store.dart';
import 'salon_screen.dart';

/// Busca o salão pelo nome ou pelo link compartilhado (…/s/nome-do-salao).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.store, required this.api});

  final BookingStore store;
  final ApiClient api;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<SalonSummary> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  /// Aceita link completo, "/s/slug" ou o texto digitado.
  static String _normalize(String text) {
    final match = RegExp(r'/s/([a-z0-9-]+)').firstMatch(text);
    return match != null ? match.group(1)! : text.trim();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(_normalize(text)));
  }

  Future<void> _search(String q) async {
    if (q.length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await widget.api.get('/api/public/salons?q=${Uri.encodeQueryComponent(q)}') as List;
      if (!mounted) return;
      setState(() => _results = json.map((e) => SalonSummary.fromJson(e as Map<String, dynamic>)).toList());
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(SalonSummary s) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SalonScreen(slug: s.slug, store: widget.store, api: widget.api)),
      );

  @override
  Widget build(BuildContext context) {
    final recent = {for (final b in widget.store.bookings) b.slug: b.salonName};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _query,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (t) => _search(_normalize(t)),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Nome do salão ou link de agendamento',
          ),
        ),
        const SizedBox(height: 12),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        for (final s in _results)
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.content_cut)),
              title: Text(s.name),
              subtitle: s.address != null ? Text(s.address!) : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(s),
            ),
          ),
        if (!_loading && _results.isEmpty && _query.text.trim().length >= 2)
          const Padding(padding: EdgeInsets.all(16), child: Text('Nenhum salão encontrado.')),
        if (_query.text.isEmpty && recent.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48, horizontal: 16),
            child: Column(children: [
              Icon(Icons.content_cut, size: 48),
              SizedBox(height: 12),
              Text(
                'Digite o nome do seu salão ou cole o link de agendamento que ele enviou.',
                textAlign: TextAlign.center,
              ),
            ]),
          ),
        if (_query.text.isEmpty && recent.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Agendar de novo', style: Theme.of(context).textTheme.titleMedium),
          for (final e in recent.entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history),
              title: Text(e.value),
              onTap: () => _open(SalonSummary(name: e.value, slug: e.key)),
            ),
        ],
      ],
    );
  }
}
