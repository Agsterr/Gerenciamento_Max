/// Loja dos vendedores (representantes): modelos do que o servidor manda. Valores em centavos.
library;

import 'package:salao_core/salao_core.dart';

int _i(Object? v) => (v as num?)?.toInt() ?? 0;

class ShopProduct {
  ShopProduct.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        name = j['name'] as String? ?? '',
        description = j['description'] as String?,
        kind = j['kind'] as String? ?? 'PRODUCT',
        category = j['category'] as String?,
        costCents = _i(j['costCents']),
        suggestedCents = _i(j['suggestedCents']),
        priceCents = _i(j['priceCents']),
        gainCents = _i(j['gainCents']),
        onPromo = j['onPromo'] as bool? ?? false,
        tags = [for (final t in (j['tags'] as List? ?? const [])) t as String],
        imageUrl = j['imageUrl'] as String?,
        thumbUrl = j['thumbUrl'] as String?,
        hidden = j['hidden'] as bool? ?? false,
        showcase = j['showcase'] as bool? ?? false,
        vendorId = _i(j['vendorId']);

  final int id;
  final String name;
  final String? description;
  final String kind;
  final String? category;
  final int costCents;
  final int suggestedCents;

  /// O que o salão paga (promoção, se houver).
  final int priceCents;

  /// O que sobra para o salão se vender pelo preço sugerido.
  final int gainCents;
  final bool onPromo;
  final List<String> tags;
  final String? imageUrl;
  final String? thumbUrl;
  bool hidden;
  bool showcase;
  final int vendorId;
}

class ShopVendor {
  ShopVendor.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        name = j['name'] as String? ?? '',
        paused = j['paused'] as bool? ?? false,
        products = [for (final p in (j['products'] as List? ?? const [])) ShopProduct.fromJson(p as Map<String, dynamic>)],
        categories = [for (final c in (j['categories'] as List? ?? const [])) c as String];

  final int id;
  final String name;
  final bool paused;
  final List<ShopProduct> products;
  final List<String> categories;
}

class ShopInvite {
  ShopInvite.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        representativeName = j['representativeName'] as String? ?? '',
        status = j['status'] as String? ?? 'PENDING',
        replacesCurrent = j['replacesCurrent'] as bool? ?? false;

  final int id;
  final String representativeName;
  final String status;
  final bool replacesCurrent;
}

class ShopOrderItem {
  ShopOrderItem.fromJson(Map<String, dynamic> j)
      : name = j['name'] as String? ?? '',
        quantity = _i(j['quantity']),
        unitCents = _i(j['unitCents']);

  final String name;
  final int quantity;
  final int unitCents;
}

class ShopOrder {
  ShopOrder.fromJson(Map<String, dynamic> j)
      : id = _i(j['id']),
        origin = j['origin'] as String? ?? 'SALON',
        status = j['status'] as String? ?? 'PENDING',
        totalCents = _i(j['totalCents']),
        paidCents = _i(j['paidCents']),
        balanceCents = _i(j['balanceCents']),
        commissionCents = _i(j['commissionCents']),
        commissionSettled = j['commissionSettled'] as bool? ?? false,
        createdAt = DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        contactName = j['contactName'] as String? ?? '',
        vendorId = _i(j['vendorId']),
        vendorName = j['vendorName'] as String? ?? '',
        items = [for (final i in (j['items'] as List? ?? const [])) ShopOrderItem.fromJson(i as Map<String, dynamic>)];

  final int id;
  final String origin;
  final String status;
  final int totalCents;
  final int paidCents;
  final int balanceCents;
  final int commissionCents;
  final bool commissionSettled;
  final DateTime createdAt;
  final String contactName;
  final int vendorId;
  final String vendorName;
  final List<ShopOrderItem> items;
}

/// Rótulos das situações do pedido.
const shopStatusLabel = {
  'PENDING': 'Pendente',
  'PREPARING': 'Em preparação',
  'SHIPPED': 'Enviado',
  'DELIVERED': 'Entregue',
  'CANCELED': 'Cancelado',
};

const shopTagLabel = {'PROMOCAO': 'Promoção', 'NOVO': 'Novo', 'EQUIPAMENTO': 'Equipamento'};

/// Centavos para texto em reais (ex.: 123450 vira "R$ 1.234,50").
String cents(int value) => formatMoney(value / 100);
