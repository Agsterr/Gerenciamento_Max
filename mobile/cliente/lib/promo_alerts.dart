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
  final fresh = found.where((p) => !seen.contains(p.key)).toList();
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
