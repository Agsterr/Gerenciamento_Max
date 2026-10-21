// Modelos espelhando os DTOs da API. Valores monetários chegam como número JSON.

double _num(Object? v) => (v as num?)?.toDouble() ?? 0;
DateTime _date(Object? v) => DateTime.parse(v as String);
List<int> _ints(Object? v) => v == null ? const [] : (v as List).cast<int>();

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
    this.reminderDays = const [],
  });

  factory PublicSalon.fromJson(Map<String, dynamic> j) => PublicSalon(
        name: j['name'] as String,
        slug: j['slug'] as String,
        phone: j['phone'] as String?,
        address: j['address'] as String?,
        workDays: (j['workDays'] as String).split(',').where((s) => s.isNotEmpty).map(int.parse).toSet(),
        services: (j['services'] as List).map((e) => PublicService.fromJson(e as Map<String, dynamic>)).toList(),
        professionals: (j['professionals'] as List).map((e) => Ref.fromJson(e as Map<String, dynamic>)).toList(),
        reminderDays: _ints(j['reminderDays']),
      );

  final String name;
  final String slug;
  final String? phone;
  final String? address;

  /// Dias antes do horário em que o app lembra o cliente de confirmar (vazio = salão desligou).
  final List<int> reminderDays;

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
    this.confirmable = false,
    this.reminderDays = const [],
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
        confirmable: j['confirmable'] as bool? ?? false,
        reminderDays: _ints(j['reminderDays']),
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

  /// Falta o cliente confirmar presença (botão "Confirmar presença").
  final bool confirmable;

  /// Dias antes do horário em que o app lembra de confirmar (ajuste do salão; vazio = desligado).
  final List<int> reminderDays;

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
    this.reminderMode = ReminderMode.oneDay,
    this.timezone = 'America/Sao_Paulo',
  });

  /// Fusos do Brasil (sem horário de verão): código -> nome.
  static const timezones = {
    'America/Sao_Paulo': 'Brasília (maioria dos estados)',
    'America/Manaus': 'Amazonas, MT, MS, RO e RR (1h a menos)',
    'America/Rio_Branco': 'Acre (2h a menos)',
    'America/Noronha': 'Fernando de Noronha (1h a mais)',
  };

  factory Salon.fromJson(Map<String, dynamic> j) => Salon(
        name: j['name'] as String,
        slug: j['slug'] as String,
        phone: j['phone'] as String?,
        address: j['address'] as String?,
        hours: (j['hours'] as List).map((e) => DayHours.fromJson(e as Map<String, dynamic>)).toList(),
        slotMinutes: j['slotMinutes'] as int,
        reminderMode: ReminderMode.parse(j['reminderMode'] as String?),
        timezone: j['timezone'] as String? ?? 'America/Sao_Paulo',
      );

  String name;
  String timezone;
  final String slug;
  String? phone;
  String? address;

  /// Somente os dias em que o salão abre, ordenados.
  List<DayHours> hours;
  int slotMinutes;
  ReminderMode reminderMode;

  Map<String, dynamic> toJson() => {
        'reminderMode': reminderMode.api,
        'name': name,
        'phone': phone,
        'address': address,
        'hours': [for (final h in hours) h.toJson()],
        'slotMinutes': slotMinutes,
        'timezone': timezone,
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
    this.customerConfirmed = false,
    this.reminderSent = false,
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
        customerConfirmed: j['customerConfirmedAt'] != null,
        reminderSent: j['reminderSentAt'] != null,
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

  /// O próprio cliente confirmou pelo lembrete (link ou app).
  final bool customerConfirmed;

  /// O salão mandou o lembrete pelo WhatsApp.
  final bool reminderSent;
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

  /// BOOKED, CANCELED, RESCHEDULED, CONFIRMED, REMINDERS ou STAFF_REMINDER.
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

// ---------- Plano (teste grátis / pago) ----------

class PlanInfo {
  const PlanInfo({
    required this.status,
    this.daysLeft,
    required this.professionals,
    required this.services,
    required this.customers,
    required this.contactWhatsapp,
    required this.contactEmail,
    this.photos = (0, 0),
    this.billingAvailable = false,
    this.playProductId = '',
    this.managedByPlay = false,
  });

  factory PlanInfo.fromJson(Map<String, dynamic> j) {
    (int, int) usage(Object? u) => ((u as Map)['used'] as int, u['max'] as int);
    return PlanInfo(
      status: j['status'] as String,
      daysLeft: j['daysLeft'] as int?,
      professionals: usage(j['professionals']),
      services: usage(j['services']),
      customers: usage(j['customers']),
      contactWhatsapp: j['contactWhatsapp'] as String? ?? '',
      contactEmail: j['contactEmail'] as String? ?? '',
      photos: j['photos'] == null ? (0, 0) : usage(j['photos']),
      billingAvailable: j['billingAvailable'] as bool? ?? false,
      playProductId: j['playProductId'] as String? ?? '',
      managedByPlay: j['managedByPlay'] as bool? ?? false,
    );
  }

  /// TRIAL, ACTIVE ou EXPIRED.
  final String status;
  final int? daysLeft;

  /// (usados, máximo) no teste grátis.
  final (int, int) professionals;
  final (int, int) services;
  final (int, int) customers;
  final String contactWhatsapp;
  final String contactEmail;

  /// Fotos do portfólio (usadas, máximo).
  final (int, int) photos;

  /// Assinatura pela loja liberada para este salão (chave "Cobrança na loja" ou teste).
  final bool billingAvailable;
  final String playProductId;

  /// A assinatura é cobrada e cancelada pela Google Play.
  final bool managedByPlay;

  bool get expired => status == 'EXPIRED';
  bool get trial => status == 'TRIAL';
}

// ---------- Lembretes ----------

/// Lembrete para o cliente confirmar o horário (ajuste do salão).
enum ReminderMode {
  off('OFF', 'Desligado'),
  oneDay('ONE_DAY', '1 dia antes'),
  twoDays('TWO_DAYS', '2 dias antes'),
  both('BOTH', '2 dias e 1 dia antes');

  const ReminderMode(this.api, this.label);

  final String api;
  final String label;

  static ReminderMode parse(String? value) => values.firstWhere((m) => m.api == value, orElse: () => oneDay);
}

/// Cliente de amanhã/depois de amanhã para lembrar pelo WhatsApp.
class ReminderItem {
  const ReminderItem({
    required this.appointmentId,
    required this.daysBefore,
    required this.startAt,
    required this.status,
    required this.customerName,
    required this.customerPhone,
    required this.serviceName,
    required this.professionalName,
    required this.customerConfirmed,
    required this.reminderSent,
    required this.message,
    required this.whatsappUrl,
  });

  factory ReminderItem.fromJson(Map<String, dynamic> j) => ReminderItem(
        appointmentId: j['appointmentId'] as int,
        daysBefore: j['daysBefore'] as int,
        startAt: _date(j['startAt']),
        status: AppointmentStatus.parse(j['status'] as String),
        customerName: j['customerName'] as String,
        customerPhone: j['customerPhone'] as String,
        serviceName: j['serviceName'] as String,
        professionalName: j['professionalName'] as String,
        customerConfirmed: j['customerConfirmed'] as bool,
        reminderSent: j['reminderSentAt'] != null,
        message: j['message'] as String,
        whatsappUrl: j['whatsappUrl'] as String,
      );

  final int appointmentId;
  final int daysBefore;
  final DateTime startAt;
  final AppointmentStatus status;
  final String customerName;
  final String customerPhone;
  final String serviceName;
  final String professionalName;
  final bool customerConfirmed;
  final bool reminderSent;
  final String message;
  final String whatsappUrl;
}

/// Regra de lembrete do profissional: "N dias antes às HH:mm" ou "X minutos antes".
class StaffReminderRule {
  const StaffReminderRule.daysBefore(int days, String time)
      : daysBefore = days,
        atTime = time,
        minutesBefore = null;

  const StaffReminderRule.minutesBefore(int minutes)
      : minutesBefore = minutes,
        daysBefore = null,
        atTime = null;

  factory StaffReminderRule.fromJson(Map<String, dynamic> j) => j['minutesBefore'] != null
      ? StaffReminderRule.minutesBefore(j['minutesBefore'] as int)
      : StaffReminderRule.daysBefore(j['daysBefore'] as int, (j['atTime'] as String).substring(0, 5));

  final int? daysBefore;

  /// "HH:mm"
  final String? atTime;
  final int? minutesBefore;

  bool get relative => minutesBefore != null;

  String get label {
    final m = minutesBefore;
    if (m != null) {
      if (m < 60) return '$m minutos antes';
      return m % 60 == 0 ? '${m ~/ 60} h antes' : '${m ~/ 60} h ${m % 60} min antes';
    }
    final day = switch (daysBefore) { 0 => 'No dia', 1 => '1 dia antes', _ => '$daysBefore dias antes' };
    return '$day, às $atTime';
  }

  Map<String, dynamic> toJson() => {'daysBefore': daysBefore, 'atTime': atTime, 'minutesBefore': minutesBefore};
}

class StaffReminderSettings {
  StaffReminderSettings({this.professionalId, required this.rules});

  factory StaffReminderSettings.fromJson(Map<String, dynamic> j) => StaffReminderSettings(
        professionalId: j['professionalId'] as int?,
        rules: (j['rules'] as List).map((e) => StaffReminderRule.fromJson(e as Map<String, dynamic>)).toList(),
      );

  /// Agenda acompanhada (nulo = todos os profissionais).
  int? professionalId;
  List<StaffReminderRule> rules;

  Map<String, dynamic> toJson() => {
        'professionalId': professionalId,
        'rules': [for (final r in rules) r.toJson()],
      };
}

/// Próximo lembrete de atendimento do usuário (para agendar a notificação no aparelho).
class UpcomingReminder {
  const UpcomingReminder({
    required this.key,
    required this.appointmentId,
    required this.remindAt,
    required this.title,
    required this.message,
  });

  factory UpcomingReminder.fromJson(Map<String, dynamic> j) => UpcomingReminder(
        key: j['key'] as String,
        appointmentId: j['appointmentId'] as int,
        remindAt: _date(j['remindAt']),
        title: j['title'] as String,
        message: j['message'] as String,
      );

  final String key;
  final int appointmentId;
  final DateTime remindAt;
  final String title;
  final String message;
}

// ---------- Portfólio ----------

class Photo {
  const Photo({
    required this.id,
    required this.url,
    required this.thumbUrl,
    this.caption,
    required this.width,
    required this.height,
    this.serviceId,
    this.serviceName,
    this.professionalId,
    this.professionalName,
  });

  factory Photo.fromJson(Map<String, dynamic> j) => Photo(
        id: j['id'] as int,
        url: j['url'] as String,
        thumbUrl: j['thumbUrl'] as String,
        caption: j['caption'] as String?,
        width: j['width'] as int,
        height: j['height'] as int,
        serviceId: j['serviceId'] as int?,
        serviceName: j['serviceName'] as String?,
        professionalId: j['professionalId'] as int?,
        professionalName: j['professionalName'] as String?,
      );

  final int id;
  final String url;
  final String thumbUrl;
  final String? caption;
  final int width;
  final int height;
  final int? serviceId;
  final String? serviceName;
  final int? professionalId;
  final String? professionalName;
}
