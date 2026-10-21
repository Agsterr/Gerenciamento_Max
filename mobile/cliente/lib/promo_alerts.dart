import 'package:salao_core/salao_core.dart';

import 'booking_store.dart';

/// Promoção de um salão que o cliente já usou.
class SalonPromotion {
  const SalonPromotion(this.salon, this.promotion);

  final SavedSalon salon;
  final PublicPromotion promotion;

  String get key => '${salon.slug}:${promotion.id}';
}

/// Busca as promoções dos salões salvos (os mais recentes) e avisa uma vez cada promoção nova.
Future<List<SalonPromotion>> checkPromotions(ApiClient api, BookingStore store, {int maxSalons = 10}) async {
  final found = <SalonPromotion>[];
  for (final salon in store.salons.take(maxSalons)) {
    try {
      final info = PublicSalon.fromJson(await api.get('/api/public/salons/${salon.slug}') as Map<String, dynamic>);
      found.addAll(info.promotions.map((p) => SalonPromotion(salon, p)));
    } catch (_) {
      // salão fora do ar ou sem rede: segue com os outros
    }
  }
  final seen = store.seenPromotions;
  final fresh = found.where((p) => !seen.contains(p.key)).toList();
  if (fresh.isNotEmpty) {
    final notifications = LocalReminders.instance;
    if (notifications.ready && !store.askedNotifications) {
      await store.markAskedNotifications();
      await notifications.requestPermission();
    }
    for (final p in fresh) {
      await notifications.showNow(
        key: 'promo:${p.key}',
        title: 'Promoção no ${p.salon.name}',
        body: '${p.promotion.headline} · até ${formatDate(p.promotion.endsOn)}',
        payload: 'promo|${p.salon.slug}',
      );
    }
    await store.markPromotionsSeen(fresh.map((p) => p.key));
  }
  return found;
}
