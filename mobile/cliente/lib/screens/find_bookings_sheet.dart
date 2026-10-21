import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../booking_store.dart';
import '../customer_sync.dart';
import 'booking_screen.dart';

/// "Já agendou?": encontra os agendamentos no salão pelo mesmo nome e WhatsApp usados ao agendar
/// (pelo site, por outro celular ou depois de reinstalar o app) e guarda neste aparelho.
///
/// Sem [slug] é o "Entrar" do app: busca em todos os salões e deixa o cliente conectado.
Future<void> showFindBookingsSheet(BuildContext context,
    {required ApiClient api, required BookingStore store, String? slug, String? salonName}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _FindBookingsSheet(api: api, store: store, slug: slug, salonName: salonName),
  );
}

class _FindBookingsSheet extends StatefulWidget {
  const _FindBookingsSheet({required this.api, required this.store, required this.slug, required this.salonName});

  final ApiClient api;
  final BookingStore store;
  final String? slug;
  final String? salonName;

  @override
  State<_FindBookingsSheet> createState() => _FindBookingsSheetState();
}

class _FindBookingsSheetState extends State<_FindBookingsSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.store.name);
  late final _phone = TextEditingController(text: widget.store.phone);
  List<Booking>? _found;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Salão escolhido na lista "Meus salões" e cliente já identificada: mostra os horários direto.
    if (widget.slug != null && widget.store.signedIn) WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    if (widget.slug == null) return _signIn();
    try {
      final json = await widget.api.post('/api/public/salons/${widget.slug}/my-bookings',
          {'name': _name.text.trim(), 'phone': _phone.text.trim()}) as List;
      final found = json.map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
      await widget.store.addAll([
        for (final b in found) SavedBooking(slug: widget.slug!, token: b.token, salonName: widget.salonName!, seen: b.signature),
      ]);
      if (found.isNotEmpty) await widget.store.rememberCustomer(_name.text.trim(), _phone.text.trim());
      if (mounted) setState(() => _found = found);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() async {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    try {
      final count = await syncCustomerBookings(widget.api, widget.store, name: name, phone: phone);
      await widget.store.rememberCustomer(name, phone);
      if (!mounted) return;
      Navigator.pop(context);
      showMessage(
          context,
          count == 0
              ? 'Pronto! Ainda não achamos horários com esse nome e WhatsApp; os próximos aparecem aqui.'
              : '$count horário(s) encontrado(s).');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final found = _found;
    final signIn = widget.slug == null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + sheetBottomInset(context)),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(signIn ? 'Entrar' : 'Meus horários em ${widget.salonName}', style: text.titleLarge),
            const SizedBox(height: 4),
            Text(
                signIn
                    ? 'Sem senha: use o mesmo nome e WhatsApp dos seus agendamentos. Mostramos seus horários em todos os salões.'
                    : 'Digite o nome e o WhatsApp que você usou ao agendar.',
                style: text.bodyMedium?.copyWith(color: Brand.muted)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(labelText: 'Nome', prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Informe seu nome' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: const InputDecoration(labelText: 'WhatsApp', hintText: '(11) 99999-9999', prefixIcon: Icon(Icons.phone_outlined)),
              validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length < 10 ? 'Informe o WhatsApp com DDD' : null,
            ),
            const SizedBox(height: 16),
            GradientButton(
                label: signIn ? 'Entrar' : 'Buscar meus horários',
                icon: signIn ? Icons.login_rounded : Icons.search_rounded,
                loading: _busy,
                onPressed: _search),
            if (found != null && found.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text('Nenhum agendamento com esse nome e WhatsApp. Confira se digitou igual ao do agendamento.',
                    textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: Brand.muted)),
              ),
            if (found != null && found.isNotEmpty) ...[
              const SizedBox(height: 8),
              SectionTitle('${found.length} encontrado(s) · salvos em Meus horários'),
              for (final b in found)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SoftCard(
                    padding: const EdgeInsets.all(12),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingScreen(slug: widget.slug!, token: b.token, api: widget.api, salonName: widget.salonName),
                      ),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(b.serviceName, style: text.titleSmall),
                          Text('${formatShortDateTime(b.startAt)} · ${b.professionalName}',
                              style: text.bodySmall?.copyWith(color: Brand.muted)),
                        ]),
                      ),
                      StatusChip(b.status),
                    ]),
                  ),
                ),
            ],
          ]),
        ),
      ),
    );
  }
}
