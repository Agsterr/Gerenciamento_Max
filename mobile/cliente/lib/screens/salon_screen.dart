import 'package:flutter/material.dart';
import 'package:salao_core/salao_core.dart';

import '../booking_store.dart';
import 'booking_screen.dart';
import 'find_bookings_sheet.dart';
import '../promo_alerts.dart';
import 'search_screen.dart' show PromoBanner;

/// Agendamento: serviço → profissional → dia/horário → nome e WhatsApp.
class SalonScreen extends StatefulWidget {
  const SalonScreen({super.key, required this.slug, required this.store, required this.api, this.initialServiceId});

  final String slug;

  /// Veio de uma promoção: já abre com o serviço escolhido e no primeiro dia com horário livre.
  final int? initialServiceId;
  final BookingStore store;
  final ApiClient api;

  @override
  State<SalonScreen> createState() => _SalonScreenState();
}

class _SalonScreenState extends State<SalonScreen> {
  PublicSalon? _salon;
  String? _error;

  /// Portfólio do salão (galeria); vazio enquanto carrega ou se o salão não tem fotos.
  List<Photo> _photos = const [];

  /// Vitrine de produtos do salão (vazia se não tiver).
  List<PublicProduct> _products = const [];

  PublicService? _service;

  /// Filtro das fotos por categoria (nulo = todas).
  String? _photoCategory;
  int? _professionalId;
  DateTime? _day;
  List<Slot>? _slots;
  String? _time;

  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  late final _name = TextEditingController(text: widget.store.name);
  late final _phone = TextEditingController(text: widget.store.phone);
  bool _remember = true;
  bool _busy = false;
  bool _collapsed = false;

  String get _base => '/api/public/salons/${widget.slug}';

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final collapsed = _scroll.hasClients && _scroll.offset > 120;
      if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    });
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final salon = PublicSalon.fromJson(await widget.api.get(_base) as Map<String, dynamic>);
      setState(() {
        _salon = salon;
        _day = _days(salon).firstOrNull;
      });
      _loadPhotos();
      _loadProducts();
      widget.store.rememberSalon(widget.slug, salon.name);
      sendPresence(widget.api, widget.store, widget.slug);
      final initial = salon.services.where((s) => s.id == widget.initialServiceId).firstOrNull;
      if (initial != null) _openService(salon, initial);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  /// Vitrine é opcional: sem rede ou sem produtos, a tela segue só com o agendamento.
  Future<void> _loadProducts() async {
    try {
      final json = await widget.api.get('$_base/products');
      if (json is List && mounted) {
        setState(() => _products = json.map((e) => PublicProduct.fromJson(e as Map<String, dynamic>)).toList());
      }
    } catch (_) {}
  }

  /// Galeria é opcional: sem rede ou sem fotos, a tela segue só com o agendamento.
  Future<void> _loadPhotos() async {
    try {
      final json = await widget.api.get('$_base/portfolio');
      if (json is List && mounted) {
        setState(() => _photos = json.map((e) => Photo.fromJson(e as Map<String, dynamic>)).toList());
      }
    } catch (_) {}
  }

  /// Próximos 14 dias de funcionamento.
  List<DateTime> _days(PublicSalon salon) {
    final today = dateOnly(DateTime.now());
    return [for (var i = 0; i < 28; i++) today.add(Duration(days: i))]
        .where((d) => salon.workDays.contains(d.weekday))
        .take(14)
        .toList();
  }

  /// Seleciona o serviço e procura o primeiro dia (dentro da promoção, se houver) com horário livre
  /// que caiba no expediente — o servidor já soma a duração do serviço (ou do pacote) e respeita as pausas.
  Future<void> _openService(PublicSalon salon, PublicService service) async {
    setState(() {
      _service = service;
      _slots = null;
    });
    final days = _days(salon).where((d) {
      final start = service.promoStartsOn, end = service.promoEndsOn;
      return start == null || end == null || (!d.isBefore(start) && !d.isAfter(end));
    }).toList();
    for (final d in days.isEmpty ? _days(salon) : days) {
      try {
        final json = await widget.api.get('$_base/availability?serviceId=${service.id}&date=${isoDate(d)}') as List;
        if (!mounted) return;
        if (json.isNotEmpty) {
          setState(() {
            _day = d;
            _slots = json.map((e) => Slot.fromJson(e as Map<String, dynamic>)).toList();
          });
          _scrollToEnd();
          return;
        }
      } catch (_) {
        break;
      }
    }
    if (mounted) _loadSlots();
  }

  Future<void> _loadSlots() async {
    if (_service == null || _day == null) return;
    setState(() {
      _slots = null;
      _time = null;
    });
    try {
      final pro = _professionalId != null ? '&professionalId=$_professionalId' : '';
      final json = await widget.api.get('$_base/availability?serviceId=${_service!.id}&date=${isoDate(_day!)}$pro') as List;
      if (mounted) setState(() => _slots = json.map((e) => Slot.fromJson(e as Map<String, dynamic>)).toList());
    } catch (e) {
      if (mounted) {
        setState(() => _slots = []);
        showError(context, e);
      }
    }
  }

  void _scrollToEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
        }
      });

  Future<void> _book() async {
    if (!_form.currentState!.validate()) {
      _scrollToEnd();
      return;
    }
    setState(() => _busy = true);
    try {
      final json = await widget.api.post('$_base/bookings', {
        'serviceId': _service!.id,
        'professionalId': _professionalId,
        'startAt': '${isoDate(_day!)}T$_time:00',
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
      }) as Map<String, dynamic>;
      final booking = Booking.fromJson(json);
      await widget.store.add(SavedBooking(slug: widget.slug, token: booking.token, salonName: _salon!.name));
      if (_remember) {
        await widget.store.rememberCustomer(_name.text.trim(), _phone.text.trim());
      } else {
        await widget.store.forgetCustomer();
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BookingScreen(
              slug: widget.slug, token: booking.token, api: widget.api, salonName: _salon!.name, justBooked: true),
        ),
      );
    } catch (e) {
      if (mounted) {
        showError(context, e);
        _loadSlots();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Produtos à venda no salão: foto, nome e preço (a compra é no salão ou pelo WhatsApp).
  Widget _productsShowcase(PublicSalon salon) {
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Produtos à venda no salão'),
      Text('Veja os preços e peça no salão${salon.phone != null ? ' ou pelo WhatsApp' : ''}.',
          style: text.bodySmall?.copyWith(color: Brand.muted)),
      const SizedBox(height: 10),
      SizedBox(
        height: 200,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _products.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) => _ProductCard(
            product: _products[i],
            onWhatsApp: salon.phone == null || !_products[i].available
                ? null
                : () => openWhatsApp(salon.phone!,
                    text: 'Olá! Quero o produto ${_products[i].name} (${formatMoney(_products[i].price)}).'),
          ),
        ),
      ),
    ]);
  }

  /// O cliente escolhe se quer avisos de promoção deste salão (o salão vê a escolha).
  Widget _promoAlertsTile() {
    final store = widget.store;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: SwitchListTile(
          secondary: const Icon(Icons.local_offer_outlined, color: Brand.rose),
          title: const Text('Avisos de promoção deste salão'),
          subtitle: Text(store.promoAlertsOff ? 'Desligados para todos os salões (em Sobre)' : 'Notificação quando sair promoção'),
          value: store.promoAlertsOn(widget.slug),
          onChanged: store.promoAlertsOff
              ? null
              : (v) async {
                  await store.setPromoAlertsFor(widget.slug, v);
                  if (mounted) setState(() {});
                  await sendPresence(widget.api, store, widget.slug);
                },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final salon = _salon;
    if (_error != null) return Scaffold(appBar: AppBar(), body: ErrorRetry(message: _error!, onRetry: _load));
    if (salon == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          _header(salon),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 140),
            sliver: SliverList.list(children: [..._steps(salon), if (_products.isNotEmpty) _productsShowcase(salon), _promoAlertsTile()]),
          ),
        ],
      ),
      bottomNavigationBar: _service == null ? null : _bottomBar(),
    );
  }

  Widget _header(PublicSalon salon) {
    final text = Theme.of(context).textTheme;
    return SliverAppBar(
      pinned: true,
      expandedHeight: 200,
      backgroundColor: Brand.rose,
      foregroundColor: Colors.white,
      actions: [
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          onPressed: () => showFindBookingsSheet(context, api: widget.api, store: widget.store, slug: widget.slug, salonName: salon.name),
          icon: const Icon(Icons.manage_search_rounded),
          label: const Text('Já agendou?'),
        ),
      ],
      title: AnimatedOpacity(
        opacity: _collapsed ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: Text(salon.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: const BoxDecoration(
            gradient: Brand.gradient,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          alignment: Alignment.bottomLeft,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: InitialsAvatar(salon.name, size: 60),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(salon.name,
                      style: text.headlineSmall?.copyWith(color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (salon.address != null)
                    Row(children: [
                      const Icon(Icons.place_outlined, size: 16, color: Colors.white70),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(salon.address!,
                            style: text.bodySmall?.copyWith(color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ]),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            Wrap(spacing: 8, children: [
              Pill('${salon.services.length} serviços', icon: Icons.auto_awesome, color: Colors.white.withValues(alpha: 0.2), textColor: Colors.white),
              Pill('${salon.professionals.length} profissionais',
                  icon: Icons.people_alt_outlined, color: Colors.white.withValues(alpha: 0.2), textColor: Colors.white),
            ]),
          ]),
        ),
      ),
    );
  }

  List<Widget> _steps(PublicSalon salon) {
    final text = Theme.of(context).textTheme;
    final groups = groupByCategory(salon.services, (s) => s.category);
    final categoryOf = {for (final s in salon.services) s.id: s.category ?? 'Outros'};
    final shown = _photoCategory == null ? _photos : _photos.where((p) => categoryOf[p.serviceId] == _photoCategory).toList();
    return [
      for (final p in salon.promotions)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: PromoBanner(
            promotion: p,
            offers: p.offers(salon.services),
          ),
        ),
      if (_photos.isNotEmpty) ...[
        const SectionTitle('Nossos trabalhos'),
        if (groups.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final c in [null, ...groups.keys])
                Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 8),
                  child: ChoiceChip(
                    label: Text(c ?? 'Todas'),
                    selected: _photoCategory == c,
                    onSelected: (_) => setState(() => _photoCategory = c),
                  ),
                ),
            ]),
          ),
        if (shown.isEmpty) const Text('Ainda não há fotos desta categoria.') else PhotoGrid(photos: shown, maxItems: 6, showServiceName: true),
        if (shown.length > 6)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _AllPhotos(name: salon.name, photos: shown))),
              icon: const Icon(Icons.photo_library_outlined),
              label: Text('Ver todas as ${shown.length} fotos'),
            ),
          ),
      ],
      const SectionTitle('1. Escolha o serviço'),
      if (salon.services.isEmpty) const Text('Nenhum serviço disponível no momento.'),
      for (final group in groups.entries) ...[
        if (groups.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Text(group.key, style: text.titleSmall?.copyWith(color: Brand.muted)),
          ),
        for (final s in group.value)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SoftCard(
            border: Border.all(color: _service?.id == s.id ? Brand.rose : Colors.transparent, width: 2),
            onTap: () {
              setState(() {
                _service = s;
                if (_professionalId != null && !s.doneBy(_professionalId!)) _professionalId = null;
              });
              _loadSlots();
            },
            child: Row(children: [
              ServiceIcon(s.name, selected: _service?.id == s.id),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.name, style: text.titleMedium),
                  if (s.kitItems.isNotEmpty)
                    Text('Inclui ${s.kitItems.join(' + ')}', style: text.bodySmall?.copyWith(color: Brand.muted)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    Pill('${s.durationMinutes} min', icon: Icons.schedule_rounded),
                    if (s.promoName != null)
                      Pill(
                        '-${formatQuantity(s.promoPercent ?? 0)}% ${s.promoPriceOn() != null ? 'hoje' : 'a partir de ${formatDate(s.promoStartsOn!).substring(0, 5)}'}',
                        icon: Icons.local_offer_rounded,
                        color: const Color(0xFFFFF1C7),
                        textColor: const Color(0xFFB45309),
                      ),
                  ]),
                  if (_photos.any((p) => p.serviceId == s.id)) _ServicePhotos(photos: [for (final p in _photos) if (p.serviceId == s.id) p]),
                ]),
              ),
              _Price(price: s.price, promo: s.promoPriceOn(), full: s.kitFullPrice),
            ]),
          ),
        ),
      ],
      if (_service != null && salon.professionals.isEmpty)
        const _NoProfessionalCard()
      else if (_service != null) ...[
        const SectionTitle('2. Com quem?'),
        SizedBox(
          height: 104,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            _ProfessionalOption(
              name: 'Qualquer um',
              icon: Icons.shuffle_rounded,
              selected: _professionalId == null,
              onTap: () {
                setState(() => _professionalId = null);
                _loadSlots();
              },
            ),
            for (final p in salon.professionals.where((p) => _service!.doneBy(p.id)))
              _ProfessionalOption(
                name: p.name,
                selected: _professionalId == p.id,
                onTap: () {
                  setState(() => _professionalId = p.id);
                  _loadSlots();
                },
              ),
          ]),
        ),
        const SectionTitle('3. Quando?'),
        DayPicker(
          days: _days(salon),
          selected: _day,
          onSelected: (d) {
            setState(() => _day = d);
            _loadSlots();
          },
        ),
        const SizedBox(height: 16),
        if (_slots == null)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else
          SlotGrid(
            slots: _slots!,
            selected: _time,
            onSelected: (s) {
              setState(() => _time = s.time);
              _scrollToEnd();
            },
          ),
      ],
      if (_time != null) ...[
        const SectionTitle('4. Seus dados'),
        SoftCard(
          child: Form(
            key: _form,
            child: Column(children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nome', prefixIcon: Icon(Icons.person_outline_rounded)),
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                validator: (v) => (v ?? '').trim().isEmpty ? 'Informe seu nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(
                    labelText: 'WhatsApp', hintText: '(11) 99999-9999', prefixIcon: Icon(Icons.phone_iphone_rounded)),
                keyboardType: TextInputType.phone,
                autofillHints: const [AutofillHints.telephoneNumber],
                validator: (v) => (v ?? '').replaceAll(RegExp(r'\D'), '').length < 10 ? 'Telefone com DDD' : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _remember,
                onChanged: (v) => setState(() => _remember = v),
                title: const Text('Lembrar meus dados neste aparelho'),
              ),
              Row(children: [
                const Icon(Icons.lock_outline_rounded, size: 16, color: Brand.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Seus dados vão apenas para ${salon.name}, para confirmar o horário.',
                      style: text.bodySmall?.copyWith(color: Brand.muted)),
                ),
              ]),
            ]),
          ),
        ),
      ],
    ];
  }

  Widget _bottomBar() {
    final text = Theme.of(context).textTheme;
    final summary = _time == null
        ? 'Escolha um horário'
        : '${formatWeekdayShort(_day!)}, ${_day!.day} de ${formatMonthShort(_day!)} · $_time';
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: Row(children: [
            Expanded(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_service!.name, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(summary, style: text.bodySmall?.copyWith(color: Brand.muted)),
                _Price(price: _service!.price, promo: _service!.promoPriceOn(_day ?? DateTime.now())),
              ]),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 170,
              child: GradientButton(
                label: 'Agendar',
                icon: Icons.check_rounded,
                loading: _busy,
                onPressed: _time == null ? null : _book,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ProfessionalOption extends StatelessWidget {
  const _ProfessionalOption({required this.name, required this.selected, required this.onTap, this.icon});

  final String name;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 84,
          margin: const EdgeInsets.only(right: 10),
          child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: selected ? Brand.gradient : null),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: InitialsAvatar(name, size: 58, icon: icon),
              ),
            ),
            const SizedBox(height: 6),
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: selected ? Brand.rose : null)),
          ]),
        ),
      ),
    );
  }
}

/// Todas as fotos do portfólio do salão.
class _AllPhotos extends StatelessWidget {
  const _AllPhotos({required this.name, required this.photos});

  final String name;
  final List<Photo> photos;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: SingleChildScrollView(padding: const EdgeInsets.all(12), child: PhotoGrid(photos: photos)),
    );
  }
}

/// Preço do serviço: promoção mostra o preço normal riscado; pacote mostra a soma riscada.
class _Price extends StatelessWidget {
  const _Price({required this.price, this.promo, this.full});

  final double price;
  final double? promo;
  final double? full;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final old = promo != null ? price : (full != null && full! > price ? full : null);
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      if (old != null)
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'De '),
            TextSpan(text: formatMoney(old), style: const TextStyle(decoration: TextDecoration.lineThrough)),
          ]),
          style: text.bodySmall?.copyWith(color: Brand.muted),
        ),
      Text.rich(
        TextSpan(children: [
          if (old != null) TextSpan(text: 'por ', style: text.bodySmall?.copyWith(color: Brand.muted)),
          TextSpan(text: formatMoney(promo ?? price)),
        ]),
        style: text.titleMedium?.copyWith(color: Brand.rose, fontWeight: FontWeight.w800),
      ),
    ]);
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, this.onWhatsApp});

  final PublicProduct product;
  final VoidCallback? onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final image = product.thumbUrl;
    return SizedBox(
      width: 140,
      child: SoftCard(
        padding: EdgeInsets.zero,
        onTap: product.imageUrl == null
            ? null
            : () => showDialog<void>(
                  context: context,
                  builder: (context) => Dialog(
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(product.imageUrl!, fit: BoxFit.contain),
                  ),
                ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 100,
            child: Stack(fit: StackFit.expand, children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: image == null
                    ? Container(color: const Color(0xFFF6EEF3), child: const Icon(Icons.inventory_2_outlined, color: Brand.muted, size: 32))
                    : Image.network(image, fit: BoxFit.cover, errorBuilder: (_, _, _) => Container(color: const Color(0xFFF6EEF3))),
              ),
              if (!product.available)
                const Positioned(left: 6, top: 6, child: Pill('Esgotado', color: Color(0xCC1F2937), textColor: Colors.white)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product.name, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(formatMoney(product.price), style: text.titleSmall?.copyWith(color: Brand.rose, fontWeight: FontWeight.w800)),
            ]),
          ),
          if (onWhatsApp != null)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Brand.whatsapp, padding: EdgeInsets.zero, minimumSize: const Size(0, 28)),
              onPressed: onWhatsApp,
              child: const Text('Pedir pelo WhatsApp', style: TextStyle(fontSize: 12)),
            ),
        ]),
      ),
    );
  }
}

/// Miniaturas das fotos do próprio serviço, dentro do cartão dele (tocar abre em tela cheia).
class _ServicePhotos extends StatelessWidget {
  const _ServicePhotos({required this.photos});

  final List<Photo> photos;

  @override
  Widget build(BuildContext context) {
    final shown = photos.take(3).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        for (final (i, p) in shown.indexed)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: SizedBox(width: 54, height: 54, child: PhotoThumb(photo: p, onTap: () => PhotoViewer.open(context, photos, i))),
          ),
        if (photos.length > 3)
          Text('+${photos.length - 3}', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Brand.muted)),
      ]),
    );
  }
}

/// Salão sem profissional ativo: não existe horário livre para mostrar.
class _NoProfessionalCard extends StatelessWidget {
  const _NoProfessionalCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SoftCard(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded, color: Brand.rose),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Agendamento online indisponível', style: text.titleSmall),
              const SizedBox(height: 4),
              Text('Este salão ainda não tem um profissional disponível para atender. Fale direto com o salão para marcar o horário.',
                  style: text.bodyMedium?.copyWith(color: Brand.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}
