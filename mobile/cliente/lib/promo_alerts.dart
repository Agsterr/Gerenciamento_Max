import 'package:salao_core/salao_core.dart';

import 'booking_store.dart';

/// Grupo das notificações de promoção (payload "promo|slug/serviceId").
const promoGroup = 'promo';

/// Promoção de um salão que o cliente já usou.
class SalonPromotion {
  const SalonPromotion(this.salon, this.promotion, [this.offers = const []]);

  final SavedSalon salon;
  final PublicPromotion promotion;

  /// Serviços com o preço "de ... por ...".
  final List<(String, double, double)> offers;

  String get key => '${salon.slug}:${promotion.id}';
}

/// Busca as promoções dos salões salvos (os mais recentes) e avisa uma vez cada promoção nova.
///
/// [askPermission]: só com o app aberto (em segundo plano não dá para pedir); assim o aviso chega
/// depois mesmo com o app fechado.
Future<List<SalonPromotion>> checkPromotions(ApiClient api, BookingStore store,
    {int maxSalons = 10, bool askPermission = true}) async {
  final notifications = LocalReminders.instance;
  if (askPermission && notifications.ready && store.salons.isNotEmpty && !store.askedNotifications) {
    await store.markAskedNotifications();
    await notifications.requestPermission();
  }
  final found = <SalonPromotion>[];
  for (final salon in store.salons.take(maxSalons)) {
    try {
      final info = PublicSalon.fromJson(await api.get('/api/public/salons/${salon.slug}') as Map<String, dynamic>);
      found.addAll(info.promotions.map((p) => SalonPromotion(salon, p, p.offers(info.services))));
    } catch (_) {
      // salão fora do ar ou sem rede: segue com os outros
    }
  }
  final seen = store.seenPromotions;
  // só avisa o que o salão quer avisar e o cliente não desligou
  final fresh = found
      .where((p) => !seen.contains(p.key) && p.promotion.notifyCustomers && store.promoAlertsOn(p.salon.slug))
      .toList();
  if (fresh.isNotEmpty) {
    for (final p in fresh) {
      await notifications.showNow(
        key: 'promo:${p.key}',
        title: 'Promoção no ${p.salon.name}',
        body: p.offers.isEmpty
            ? '${p.promotion.headline} · até ${formatDate(p.promotion.endsOn)}'
            : '${p.offers.first.$1} de ${formatMoney(p.offers.first.$2)} por ${formatMoney(p.offers.first.$3)}'
                '${p.offers.length > 1 ? ' e mais ${p.offers.length - 1}' : ''} · até ${formatDate(p.promotion.endsOn)}',
        payload: '$promoGroup|${p.salon.slug}/${p.promotion.serviceIds.firstOrNull ?? ''}',
      );
    }
    await store.markPromotionsSeen(fresh.map((p) => p.key));
  }
  return found;
}

/// Conta ao salão que o cliente abriu a página dele (e se quer avisos de promoção).
/// Identifica pelo código de um agendamento salvo ou pelo nome + WhatsApp; sem nenhum dos dois, não manda.
///
/// Com push ligado manda também o código do celular (mesmo sem saber quem é), para o salão poder avisar.
/// [visit] false: só atualiza a escolha/celular, sem contar como visita.
Future<void> sendPresence(ApiClient api, BookingStore store, String slug, {bool visit = true}) async {
  final token = store.bookings.where((b) => b.slug == slug).firstOrNull?.token;
  final push = store.pushToken;
  if (token == null && !store.signedIn && push == null) return;
  try {
    await api.post('/api/public/salons/$slug/presence', {
      'token': ?token,
      if (token == null && store.signedIn) 'name': store.name,
      if (token == null && store.signedIn) 'phone': store.phone,
      'promoNotifications': store.promoAlertsOn(slug),
      'pushToken': ?push,
      if (!visit) 'visit': false,
    });
  } catch (_) {
    // informação para o salão; sem rede não atrapalha o cliente
  }
}
