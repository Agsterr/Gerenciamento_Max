import 'package:flutter/foundation.dart';
import 'package:salao_core/salao_core.dart';

import '../session.dart';

/// Se o salão tem vendedor (ou um convite esperando resposta). Sem isso, nada da loja aparece no app — quem instalou
/// direto da Play, sem link de vendedor, vê o app como sempre foi. Guardado no aparelho para o menu não "piscar".
class ShopAccess extends ChangeNotifier {
  ShopAccess(this.session);

  final Session session;

  bool hasVendor = false;
  int pendingInvites = 0;

  bool get visible => hasVendor || pendingInvites > 0;

  String get _key => 'shop:${session.user.salonSlug}:access';

  Future<void> load() async {
    if (!session.user.isOwner) return; // a loja é só do dono
    final cached = await LocalCache.read(_key);
    if (cached is Map) {
      hasVendor = cached['hasVendor'] == true;
      pendingInvites = (cached['invites'] as num?)?.toInt() ?? 0;
      notifyListeners();
    }
    await refresh();
  }

  Future<void> refresh() async {
    if (!session.user.isOwner) return;
    try {
      final catalog = await session.api.get('/api/shop/catalog') as Map<String, dynamic>;
      final invites = await session.api.get('/api/shop/invites') as List;
      hasVendor = catalog['available'] == true;
      pendingInvites = invites.where((i) => (i as Map)['status'] == 'PENDING').length;
      await LocalCache.write(_key, {'hasVendor': hasVendor, 'invites': pendingInvites});
      await LocalCache.write('shop:${session.user.salonSlug}:catalog', catalog);
      await LocalCache.write('shop:${session.user.salonSlug}:invites', invites);
      notifyListeners();
    } catch (_) {
      // sem rede: fica com o que estava guardado
    }
  }
}
