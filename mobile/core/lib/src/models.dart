// Modelos espelhando os DTOs da API. Valores monetários chegam como número JSON.

double _num(Object? v) => (v as num?)?.toDouble() ?? 0;
DateTime _date(Object? v) => DateTime.parse(v as String);

enum AppointmentStatus {
  scheduled('SCHEDULED', 'Agendado'),
  confirmed('CONFIRMED', 'Confirmado'),
  inProgress('IN_PROGRESS', 'Em atendimento'),
  done('DONE', 'Finalizado'),
  canceled('CANCELED', 'Cancelado'),
  noShow('NO_SHOW', 'Faltou');

  const AppointmentStatus(this.api, this.label);

  final String api;
  final String label;

  bool get isOpen => this == scheduled || this == confirmed;

  static AppointmentStatus parse(String value) => values.firstWhere((s) => s.api == value);
}

class Ref {
  const Ref(this.id, this.name);

  factory Ref.fromJson(Map<String, dynamic> j) => Ref(j['id'] as int, j['name'] as String);

  final int id;
  final String name;
}

class Slot {
  const Slot(this.time, this.professionalIds);

  factory Slot.fromJson(Map<String, dynamic> j) =>
      Slot((j['time'] as String).substring(0, 5), (j['professionalIds'] as List).cast<int>());

  /// "HH:mm"
  final String time;
  final List<int> professionalIds;
}

// ---------- Público (app do cliente) ----------

class SalonSummary {
  const SalonSummary({required this.name, required this.slug, this.address});

  factory SalonSummary.fromJson(Map<String, dynamic> j) =>
      SalonSummary(name: j['name'] as String, slug: j['slug'] as String, address: j['address'] as String?);

  final String name;
  final String slug;
  final String? address;
}

class PublicService {
  const PublicService({required this.id, required this.name, this.description, required this.durationMinutes, required this.price});

  factory PublicService.fromJson(Map<String, dynamic> j) => PublicService(
        id: j['id'] as int,
        name: j['name'] as String,
        description: j['description'] as String?,
        durationMinutes: j['durationMinutes'] as int,
        price: _num(j['price']),
      );

  final int id;
  final String name;
  final String? description;
  final int durationMinutes;
  final double price;
}

class PublicSalon {
  const PublicSalon({
    required this.name,
    required this.slug,
    this.phone,
    this.address,
    required this.workDays,
    required this.services,
    required this.professionals,
  });

  factory PublicSalon.fromJson(Map<String, dynamic> j) => PublicSalon(
        name: j['name'] as String,
        slug: j['slug'] as String,
        phone: j['phone'] as String?,
        address: j['address'] as String?,
        workDays: (j['workDays'] as String).split(',').where((s) => s.isNotEmpty).map(int.parse).toSet(),
        services: (j['services'] as List).map((e) => PublicService.fromJson(e as Map<String, dynamic>)).toList(),
        professionals: (j['professionals'] as List).map((e) => Ref.fromJson(e as Map<String, dynamic>)).toList(),
      );

  final String name;
  final String slug;
  final String? phone;
  final String? address;

  /// Dias ISO (1 = segunda ... 7 = domingo) — igual a [DateTime.weekday].
  final Set<int> workDays;
  final List<PublicService> services;
  final List<Ref> professionals;
}

class Booking {
  const Booking({
    required this.token,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.serviceId,
    required this.serviceName,
    required this.professionalId,
    required this.professionalName,
    required this.price,
    required this.customerName,
    required this.cancelable,
  });

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        token: j['token'] as String,
        startAt: _date(j['startAt']),
        endAt: _date(j['endAt']),
        status: AppointmentStatus.parse(j['status'] as String),
        serviceId: j['serviceId'] as int? ?? 0,
        serviceName: j['serviceName'] as String,
        professionalId: j['professionalId'] as int? ?? 0,
        professionalName: j['professionalName'] as String,
        price: _num(j['price']),
        customerName: j['customerName'] as String,
        cancelable: j['cancelable'] as bool,
      );

  final String token;
  final DateTime startAt;
  final DateTime endAt;
  final AppointmentStatus status;
  final int serviceId;
  final String serviceName;
  final int professionalId;
  final String professionalName;
  final double price;
  final String customerName;

  /// Cliente ainda pode cancelar ou remarcar sozinho (até 2h antes).
  final bool cancelable;

  /// Assinatura do que importa para o cliente: muda se o salão remarcar, trocar o profissional ou cancelar.
  String get signature => '${startAt.toIso8601String()}|$professionalId|${status.name}';
}

// ---------- Painel (app do salão) ----------

enum Role { owner, staff }

class User {
  const User({required this.id, required this.name, required this.email, required this.role, required this.salonSlug});

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'] as int,
        name: j['name'] as String,
        email: j['email'] as String,
        role: j['role'] == 'OWNER' ? Role.owner : Role.staff,
        salonSlug: j['salonSlug'] as String,
      );

  final int id;
  final String name;
  final String email;
  final Role role;
  final String salonSlug;

  bool get isOwner => role == Role.owner;
}

/// Horário de um dia da semana (1 = segunda ... 7 = domingo), horas "HH:mm".
class DayHours {
  DayHours({required this.dayOfWeek, required this.openTime, required this.closeTime, this.breakStart, this.breakEnd});

  factory DayHours.fromJson(Map<String, dynamic> j) => DayHours(
        dayOfWeek: j['dayOfWeek'] as int,
        openTime: _hhmm(j['openTime'])!,
        closeTime: _hhmm(j['closeTime'])!,
        breakStart: _hhmm(j['breakStart']),
        breakEnd: _hhmm(j['breakEnd']),
      );

  final int dayOfWeek;
  String openTime;
  String closeTime;
  String? breakStart;
  String? breakEnd;

  bool get hasBreak => breakStart != null && breakEnd != null;

  DayHours copyFor(int day) =>
      DayHours(dayOfWeek: day, openTime: openTime, closeTime: closeTime, breakStart: breakStart, breakEnd: breakEnd);

  Map<String, dynamic> toJson() => {
        'dayOfWeek': dayOfWeek,
        'openTime': openTime,
        'closeTime': closeTime,
        'breakStart': breakStart,
        'breakEnd': breakEnd,
      };

  static String? _hhmm(Object? v) => v == null ? null : (v as String).substring(0, 5);
}

class Salon {
  Salon({
    required this.name,
    required this.slug,
    this.phone,
    this.address,
    required this.hours,
    required this.slotMinutes,
  });

  factory Salon.fromJson(Map<String, dynamic> j) => Salon(
        name: j['name'] as String,
        slug: j['slug'] as String,
        phone: j['phone'] as String?,
        address: j['address'] as String?,
        hours: (j['hours'] as List).map((e) => DayHours.fromJson(e as Map<String, dynamic>)).toList(),
        slotMinutes: j['slotMinutes'] as int,
      );

  String name;
  final String slug;
  String? phone;
  String? address;

  /// Somente os dias em que o salão abre, ordenados.
  List<DayHours> hours;
  int slotMinutes;

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'address': address,
        'hours': [for (final h in hours) h.toJson()],
        'slotMinutes': slotMinutes,
      };
}

class Professional {
  const Professional({required this.id, required this.name, this.phone, required this.commissionPercent, required this.active});

  factory Professional.fromJson(Map<String, dynamic> j) => Professional(
        id: j['id'] as int,
        name: j['name'] as String,
        phone: j['phone'] as String?,
        commissionPercent: _num(j['commissionPercent']),
        active: j['active'] as bool,
      );

  final int id;
  final String name;
  final String? phone;
  final double commissionPercent;
  final bool active;
}

class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.name,
    this.description,
    required this.durationMinutes,
    required this.price,
    required this.cost,
    required this.active,
  });

  factory ServiceItem.fromJson(Map<String, dynamic> j) => ServiceItem(
        id: j['id'] as int,
        name: j['name'] as String,
        description: j['description'] as String?,
        durationMinutes: j['durationMinutes'] as int,
        price: _num(j['price']),
        cost: _num(j['cost']),
        active: j['active'] as bool,
      );

  final int id;
  final String name;
  final String? description;
  final int durationMinutes;
  final double price;
  final double cost;
  final bool active;
}

class Customer {
  const Customer({required this.id, required this.name, required this.phone, this.email, this.notes});

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: j['id'] as int,
        name: j['name'] as String,
        phone: j['phone'] as String,
        email: j['email'] as String?,
        notes: j['notes'] as String?,
      );

  final int id;
  final String name;
  final String phone;
  final String? email;
  final String? notes;
}

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.costPrice,
    required this.salePrice,
    required this.stock,
    required this.minStock,
    required this.unit,
    required this.active,
    required this.lowStock,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as int,
        name: j['name'] as String,
        costPrice: _num(j['costPrice']),
        salePrice: _num(j['salePrice']),
        stock: _num(j['stock']),
        minStock: _num(j['minStock']),
        unit: j['unit'] as String,
        active: j['active'] as bool,
        lowStock: j['lowStock'] as bool,
      );

  final int id;
  final String name;
  final double costPrice;
  final double salePrice;
  final double stock;
  final double minStock;
  final String unit;
  final bool active;
  final bool lowStock;
}

class Appointment {
  const Appointment({
    required this.id,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.customer,
    required this.customerPhone,
    required this.professional,
    required this.service,
    required this.estimatedMinutes,
    this.realMinutes,
    required this.price,
    this.notes,
    this.serviceNotes,
    required this.online,
  });

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
        id: j['id'] as int,
        startAt: _date(j['startAt']),
        endAt: _date(j['endAt']),
        status: AppointmentStatus.parse(j['status'] as String),
        customer: Ref.fromJson(j['customer'] as Map<String, dynamic>),
        customerPhone: j['customerPhone'] as String,
        professional: Ref.fromJson(j['professional'] as Map<String, dynamic>),
        service: Ref.fromJson(j['service'] as Map<String, dynamic>),
        estimatedMinutes: j['estimatedMinutes'] as int,
        realMinutes: j['realMinutes'] as int?,
        price: _num(j['price']),
        notes: j['notes'] as String?,
        serviceNotes: j['serviceNotes'] as String?,
        online: j['source'] == 'ONLINE',
      );

  final int id;
  final DateTime startAt;
  final DateTime endAt;
  final AppointmentStatus status;
  final Ref customer;
  final String customerPhone;
  final Ref professional;
  final Ref service;
  final int estimatedMinutes;
  final int? realMinutes;
  final double price;
  final String? notes;

  /// Anotações internas do atendimento (tinta usada, corte feito...). Só a equipe vê.
  final String? serviceNotes;
  final bool online;
}

class Expense {
  const Expense({required this.id, required this.description, required this.category, required this.amount, required this.date});

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as int,
        description: j['description'] as String,
        category: j['category'] as String,
        amount: _num(j['amount']),
        date: _date(j['date']),
      );

  final int id;
  final String description;
  final String category;
  final double amount;
  final DateTime date;
}

class Ranking {
  const Ranking(this.name, this.count, this.revenue, this.commission, this.avgRealMinutes);

  factory Ranking.fromJson(Map<String, dynamic> j) => Ranking(
        j['name'] as String,
        j['count'] as int,
        _num(j['revenue']),
        _num(j['commission']),
        (j['avgRealMinutes'] as num?)?.toDouble(),
      );

  final String name;
  final int count;
  final double revenue;
  final double commission;
  final double? avgRealMinutes;
}

class Summary {
  Summary(this.json)
      : byProfessional = (json['byProfessional'] as List).map((e) => Ranking.fromJson(e as Map<String, dynamic>)).toList(),
        byService = (json['byService'] as List).map((e) => Ranking.fromJson(e as Map<String, dynamic>)).toList(),
        lowStock = (json['lowStock'] as List).cast<Map<String, dynamic>>();

  final Map<String, dynamic> json;
  final List<Ranking> byProfessional;
  final List<Ranking> byService;
  final List<Map<String, dynamic>> lowStock;

  double money(String key) => _num(json[key]);
  int count(String key) => json[key] as int;
  double? minutes(String key) => (json[key] as num?)?.toDouble();
}

// ---------- Precificação ----------

enum PricingHealth {
  loss('LOSS', 'Prejuízo'),
  low('LOW', 'Margem baixa'),
  healthy('HEALTHY', 'Saudável'),
  noPrice('NO_PRICE', 'Sem preço');

  const PricingHealth(this.api, this.label);

  final String api;
  final String label;

  static PricingHealth parse(String v) => values.firstWhere((h) => h.api == v);
}

class ServicePricing {
  ServicePricing.fromJson(Map<String, dynamic> j)
      : serviceId = j['serviceId'] as int,
        name = j['name'] as String,
        plannedMinutes = j['plannedMinutes'] as int,
        realAverageMinutes = j['realAverageMinutes'] as int?,
        currentPrice = _num(j['currentPrice']),
        materialCost = _num(j['materialCost']),
        fixedCostShare = _num(j['fixedCostShare']),
        directCost = _num(j['directCost']),
        variablePercent = _num(j['variablePercent']),
        breakEvenPrice = (j['breakEvenPrice'] as num?)?.toDouble(),
        suggestedPrice = (j['suggestedPrice'] as num?)?.toDouble(),
        currentProfit = _num(j['currentProfit']),
        currentMarginPercent = (j['currentMarginPercent'] as num?)?.toDouble(),
        profitPerHour = _num(j['profitPerHour']),
        health = PricingHealth.parse(j['health'] as String);

  final int serviceId;
  final String name;
  final int plannedMinutes;
  final int? realAverageMinutes;
  final double currentPrice;
  final double materialCost;
  final double fixedCostShare;
  final double directCost;
  final double variablePercent;
  final double? breakEvenPrice;
  final double? suggestedPrice;
  final double currentProfit;
  final double? currentMarginPercent;
  final double profitPerHour;
  final PricingHealth health;

  /// Lucro e margem (%) para um preço qualquer — mesma conta do backend.
  ({double profit, double margin}) simulate(double price) {
    final profit = price - directCost - price * variablePercent / 100;
    return (profit: profit, margin: price > 0 ? profit / price * 100 : 0);
  }
}

class Pricing {
  Pricing.fromJson(Map<String, dynamic> j)
      : basis = j['basis'] as Map<String, dynamic>,
        services = (j['services'] as List).map((e) => ServicePricing.fromJson(e as Map<String, dynamic>)).toList();

  final Map<String, dynamic> basis;
  final List<ServicePricing> services;

  Map<String, dynamic> get settings => basis['settings'] as Map<String, dynamic>;
  double money(String key) => _num(basis[key]);
}

// ---------- Notificações do salão ----------

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.read,
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as int,
        type: j['type'] as String,
        title: j['title'] as String,
        message: j['message'] as String,
        createdAt: _date(j['createdAt']),
        read: j['read'] as bool,
      );

  final int id;

  /// BOOKED, CANCELED ou RESCHEDULED.
  final String type;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool read;
}

class Inbox {
  const Inbox(this.unread, this.items);

  factory Inbox.fromJson(Map<String, dynamic> j) => Inbox(
        j['unread'] as int,
        (j['items'] as List).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList(),
      );

  final int unread;
  final List<AppNotification> items;
}
