import 'dart:async';

import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../booking_store.dart';
import 'about_screen.dart';
import 'find_bookings_sheet.dart';
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
  void initState() {
    super.initState();
    widget.store.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.store.removeListener(_refresh);
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  /// Aceita link completo, "/s/slug" ou o texto digitado.
  static String _normalize(String text) {
    final match = RegExp(r'/s/([a-z0-9-]+)').firstMatch(text);
    return match != null ? match.group(1)! : text.trim();
  }

  void _onChanged(String text) {
    setState(() {});
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
    final text = Theme.of(context).textTheme;
    final saved = widget.store.salons;
    final typing = _query.text.trim().length >= 2;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        GradientHeader(
          bottomPadding: 24,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Text('Salão Max', style: text.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                tooltip: 'Sobre e privacidade',
                color: Colors.white,
                icon: const Icon(Icons.info_outline_rounded),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AboutScreen(store: widget.store))),
              ),
            ]),
            const SizedBox(height: 22),
            Text('${greeting()}!', style: text.titleMedium?.copyWith(color: Colors.white.withValues(alpha: 0.9))),
            const SizedBox(height: 4),
            Text('Seu horário de beleza\nem 1 minuto',
                style: text.headlineMedium?.copyWith(color: Colors.white, height: 1.15)),
            const SizedBox(height: 22),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 24, offset: const Offset(0, 10))],
              ),
              child: TextField(
                controller: _query,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (t) => _search(_normalize(t)),
                decoration: InputDecoration(
                  hintText: 'Nome do salão ou link',
                  labelText: 'Buscar salão',
                  floatingLabelBehavior: FloatingLabelBehavior.never,
                  prefixIcon: const Icon(Icons.search_rounded, color: Brand.rose),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpar',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _query.clear();
                            _onChanged('');
                          }),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                ),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (_loading) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            if (typing) ...[
              SectionTitle(_results.isEmpty && !_loading ? 'Nenhum salão encontrado' : 'Resultados'),
              for (final s in _results) Padding(padding: const EdgeInsets.only(bottom: 12), child: _SalonCard(salon: s, onTap: () => _open(s))),
            ] else ...[
              if (saved.isNotEmpty) ...[
                const SectionTitle('Meus salões'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('Toque no salão para ver seus horários.', style: text.bodySmall?.copyWith(color: Brand.muted)),
                ),
                for (final e in saved)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SalonCard(
                      salon: SalonSummary(name: e.name, slug: e.slug),
                      recent: true,
                      onTap: () => showFindBookingsSheet(context, api: widget.api, store: widget.store, slug: e.slug, salonName: e.name),
                      onBook: () => _open(SalonSummary(name: e.name, slug: e.slug)),
                    ),
                  ),
              ],
              const SectionTitle('Por que agendar pelo app'),
              const _Benefit(icon: Icons.bolt_rounded, title: 'Rápido e sem cadastro', text: 'Só seu nome e WhatsApp. Pronto.'),
              const _Benefit(icon: Icons.event_available_rounded, title: 'Horários em tempo real', text: 'Veja só o que está livre de verdade.'),
              const _Benefit(icon: Icons.notifications_active_outlined, title: 'Tudo na palma da mão', text: 'Consulte e cancele quando precisar.'),
            ],
          ]),
        ),
      ],
    );
  }
}

class _SalonCard extends StatelessWidget {
  const _SalonCard({required this.salon, required this.onTap, this.onBook, this.recent = false});

  final SalonSummary salon;
  final VoidCallback onTap;

  /// Em "Meus salões": atalho para agendar de novo (o toque no cartão abre os horários).
  final VoidCallback? onBook;
  final bool recent;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SoftCard(
      onTap: onTap,
      child: Row(children: [
        InitialsAvatar(salon.name, size: 52),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(salon.name, style: text.titleMedium),
            const SizedBox(height: 2),
            Text(recent ? 'Ver meus horários' : (salon.address ?? 'Agendamento online'),
                style: text.bodySmall?.copyWith(color: Brand.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]),
        ),
        if (onBook != null)
          TextButton(onPressed: onBook, child: const Text('Agendar'))
        else
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFFFFEAF2), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.arrow_forward_rounded, color: Brand.rose, size: 20),
          ),
      ]),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(gradient: Brand.gradient, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: t.titleSmall),
              Text(text, style: t.bodySmall?.copyWith(color: Brand.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}
