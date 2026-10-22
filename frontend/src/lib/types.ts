export type Role = "OWNER" | "STAFF" | "PLATFORM_ADMIN";

export type User = {
  id: number;
  name: string;
  email: string;
  role: Role;
  /** Nulo para o administrador da plataforma. */
  salonId: number | null;
  salonSlug: string | null;
};

// ---- Administração da plataforma ----

export type MobileApp = "gestao" | "cliente";

export type PlatformSalon = {
  id: number;
  name: string;
  slug: string;
  phone: string | null;
  address: string | null;
  createdAt: string | null;
  userCount: number;
  blocked: boolean;
  blockedReason: string | null;
  blockedAt: string | null;
  plan: Plan;
  planStatus: PlanStatus;
  trialEndsAt: string;
  paidUntil: string | null;
  /** Vê a assinatura da loja mesmo com a chave geral desligada (testes). */
  billingPreview: boolean;
  viaPlay: boolean;
};

export type PlatformUser = {
  id: number;
  name: string;
  email: string;
  role: Role;
  active: boolean;
  blocked: boolean;
  blockedReason: string | null;
  blockedAt: string | null;
};

export type AppRelease = {
  id: number;
  app: MobileApp;
  versionName: string;
  versionCode: number;
  fileName: string;
  fileSizeBytes: number;
  sha256: string;
  releaseNotes: string | null;
  forceUpdate: boolean;
  downloadUrl: string;
  createdAt: string;
};

/** Horário de um dia da semana (1 = segunda ... 7 = domingo); horas no formato "HH:mm" ou "HH:mm:ss". */
export type DayHours = {
  dayOfWeek: number;
  openTime: string;
  closeTime: string;
  breakStart: string | null;
  breakEnd: string | null;
};

export type Salon = {
  id: number;
  name: string;
  slug: string;
  phone: string | null;
  address: string | null;
  hours: DayHours[];
  workDays: string;
  slotMinutes: number;
  /** Fuso do salão (IANA). */
  timezone: string;
  reminderMode: ReminderMode;
  releaseSlotOnCancel: boolean;
  /** Dias antes do horário em que o cliente é lembrado (vazio = desligado). */
  reminderDays: number[];
};

export type ReminderMode = "OFF" | "ONE_DAY" | "TWO_DAYS" | "BOTH";

export type Professional = {
  id: number;
  name: string;
  phone: string | null;
  commissionPercent: number;
  active: boolean;
  /** Categorias que atende (Cabelo, Unhas...); vazio = todas. */
  categories: string[];
};

export type Service = {
  id: number;
  name: string;
  description: string | null;
  durationMinutes: number;
  price: number;
  cost: number;
  active: boolean;
  /** Grupo do serviço (Cabelo, Unhas...). */
  category: string | null;
  /** Quem faz o serviço; vazio = qualquer profissional. */
  professionalIds: number[];
  /** Pacote: serviços incluídos (vazio = serviço comum), % de desconto e soma sem desconto. */
  kitServiceIds: number[];
  kitDiscountPercent: number | null;
  kitFullPrice: number | null;
};

export type Promotion = {
  id: number;
  name: string;
  description: string | null;
  discountPercent: number;
  startsOn: string;
  endsOn: string;
  active: boolean;
  /** Vazio = todos os serviços (menos pacotes). */
  serviceIds: number[];
  serviceNames: string[];
  /** Avisa os clientes no celular. */
  notifyCustomers: boolean;
};

export type Customer = {
  id: number;
  name: string;
  phone: string;
  email: string | null;
  notes: string | null;
  createdAt: string;
  /** Última visita à página do salão pelo app do cliente. */
  lastSeenAt: string | null;
  /** false = desligou avisos de promoção; null = não escolheu (ligado). */
  promoNotifications: boolean | null;
};

export type Product = {
  id: number;
  name: string;
  costPrice: number;
  salePrice: number;
  stock: number;
  minStock: number;
  unit: string;
  active: boolean;
  lowStock: boolean;
  /** % que o salão quer ganhar em cima do custo (referência do preço). */
  markupPercent: number | null;
  /** Miniatura da primeira foto do produto. */
  photoUrl: string | null;
  /** Aparece na vitrine do cliente (se ativo e com preço de venda). */
  showcase: boolean;
};

export type MovementType = "IN" | "SALE" | "USE" | "LOSS";

export type Movement = {
  id: number;
  productId: number;
  productName: string;
  type: MovementType;
  quantity: number;
  unitCost: number;
  unitPrice: number | null;
  appointmentId: number | null;
  createdAt: string;
};

export type AppointmentStatus = "SCHEDULED" | "CONFIRMED" | "IN_PROGRESS" | "DONE" | "CANCELED" | "NO_SHOW";

export type Ref = { id: number; name: string };

export type Appointment = {
  id: number;
  startAt: string;
  endAt: string;
  status: AppointmentStatus;
  customer: Ref;
  customerPhone: string;
  professional: Ref;
  service: Ref;
  estimatedMinutes: number;
  realMinutes: number | null;
  price: number;
  commissionAmount: number;
  startedAt: string | null;
  finishedAt: string | null;
  notes: string | null;
  /** Anotações internas do atendimento (tinta usada, corte feito...). Nunca aparecem para o cliente. */
  serviceNotes: string | null;
  source: "ADMIN" | "ONLINE";
  /** Salão mandou o lembrete pelo WhatsApp. */
  reminderSentAt: string | null;
  /** O próprio cliente confirmou pelo link do lembrete. */
  customerConfirmedAt: string | null;
  /** Refação: cliente voltou para refazer e não pagou. */
  rework: boolean;
  discountAmount: number;
  promotionName: string | null;
};

export type Slot = { time: string; professionalIds: number[] };

export type Expense = {
  id: number;
  description: string;
  category: string;
  amount: number;
  date: string;
  /** Aluguel, água, luz... (se repetem todo mês). */
  fixed: boolean;
};

export type Ranking = {
  name: string;
  count: number;
  revenue: number;
  commission: number;
  avgRealMinutes: number | null;
};

export type Summary = {
  from: string;
  to: string;
  servicesRevenue: number;
  productSalesRevenue: number;
  totalRevenue: number;
  serviceMaterialCost: number;
  productsUsedCost: number;
  productsSoldCost: number;
  commissions: number;
  expenses: number;
  totalCosts: number;
  profit: number;
  appointmentsDone: number;
  appointmentsCanceled: number;
  appointmentsNoShow: number;
  onlineBookings: number;
  averageTicket: number;
  averageEstimatedMinutes: number | null;
  averageRealMinutes: number | null;
  byProfessional: Ranking[];
  byService: Ranking[];
  expensesByCategory: Record<string, number>;
  lowStock: { id: number; name: string; stock: number; minStock: number; unit: string }[];
  fixedExpenses: number;
  variableExpenses: number;
  fixedByCategory: Record<string, number>;
  variableByCategory: Record<string, number>;
  rework: {
    count: number;
    materialCost: number;
    productsCost: number;
    totalCost: number;
    items: { appointmentId: number; startAt: string; customer: string; service: string; professional: string; cost: number }[];
  };
  products: ProductReport[];
  servicesProfit: number;
  productsProfit: number;
  operatingProfit: number;
  promotions: { appointments: number; discounts: number; byPromotion: Ranking[]; kitsSold: number; kitsRevenue: number };
};

export type ProductReport = {
  id: number;
  name: string;
  unit: string;
  soldQuantity: number;
  salesRevenue: number;
  soldCost: number;
  salesProfit: number;
  usedQuantity: number;
  usedCost: number;
  lostQuantity: number;
  lostCost: number;
  purchasedQuantity: number;
  purchasedCost: number;
  stock: number;
  stockValue: number;
  costPrice: number;
  salePrice: number;
  markupPercent: number | null;
  lowStock: boolean;
};

export type PublicSalon = {
  name: string;
  slug: string;
  phone: string | null;
  address: string | null;
  workDays: string;
  hours: DayHours[];
  services: {
    id: number;
    name: string;
    description: string | null;
    durationMinutes: number;
    price: number;
    category: string | null;
    /** Vazio = qualquer profissional faz. */
    professionalIds: number[];
    kitItems: string[];
    kitFullPrice: number | null;
    /** Promoção que vale hoje ou a próxima (o preço final depende do dia do horário). */
    promoPrice: number | null;
    promotionId: number | null;
    promoName: string | null;
    promoPercent: number | null;
    promoStartsOn: string | null;
    promoEndsOn: string | null;
  }[];
  promotions: {
    id: number;
    name: string;
    description: string | null;
    discountPercent: number;
    startsOn: string;
    endsOn: string;
    serviceIds: number[];
    notifyCustomers: boolean;
  }[];
  professionals: Ref[];
  reminderDays: number[];
};

/** Produto da vitrine do salão (só para ver; a compra é no salão). */
export type PublicProduct = {
  id: number;
  name: string;
  price: number;
  available: boolean;
  thumbUrl: string | null;
  imageUrl: string | null;
};

export type Booking = {
  token: string;
  startAt: string;
  endAt: string;
  status: AppointmentStatus;
  serviceId: number;
  serviceName: string;
  professionalId: number;
  professionalName: string;
  price: number;
  customerName: string;
  /** Cliente ainda pode cancelar ou remarcar sozinho (até 2h antes). */
  cancelable: boolean;
  /** Falta o cliente confirmar presença (botão "Confirmar presença"). */
  confirmable: boolean;
  reminderDays: number[];
};

export type NotificationType = "BOOKED" | "CANCELED" | "RESCHEDULED" | "CONFIRMED" | "REMINDERS" | "STAFF_REMINDER";

export type AppNotification = {
  id: number;
  type: NotificationType;
  appointmentId: number | null;
  title: string;
  message: string;
  createdAt: string;
  read: boolean;
};

export type Inbox = { unread: number; items: AppNotification[] };

// ---- Lembretes ----

export type ReminderItem = {
  appointmentId: number;
  daysBefore: number;
  startAt: string;
  status: AppointmentStatus;
  customerName: string;
  customerPhone: string;
  serviceName: string;
  professionalName: string;
  customerConfirmed: boolean;
  reminderSentAt: string | null;
  confirmUrl: string;
  message: string;
  whatsappUrl: string;
};

export type Reminders = { mode: ReminderMode; days: number[]; items: ReminderItem[] };

/** Regra de lembrete do profissional: "N dias antes às HH:mm" ou "X minutos antes". */
export type StaffReminderRule = {
  id?: number;
  daysBefore: number | null;
  atTime: string | null;
  minutesBefore: number | null;
};

export type StaffReminderSettings = { professionalId: number | null; rules: StaffReminderRule[] };

// ---- Portfólio ----

export type Photo = {
  id: number;
  url: string;
  thumbUrl: string;
  caption: string | null;
  width: number;
  height: number;
  serviceId: number | null;
  serviceName: string | null;
  professionalId: number | null;
  professionalName: string | null;
  createdAt: string;
};

export type PricingHealth = "LOSS" | "LOW" | "HEALTHY" | "NO_PRICE";

export type PricingSettings = {
  cardFeePercent: number;
  targetMarginPercent: number;
  occupancyPercent: number;
  fixedMonthlyCost: number | null;
};

export type ServicePricing = {
  serviceId: number;
  name: string;
  plannedMinutes: number;
  realAverageMinutes: number | null;
  minutesUsed: number;
  currentPrice: number;
  materialCost: number;
  fixedCostShare: number;
  directCost: number;
  variablePercent: number;
  breakEvenPrice: number | null;
  suggestedPrice: number | null;
  currentProfit: number;
  currentMarginPercent: number | null;
  profitPerHour: number;
  health: PricingHealth;
};

export type Pricing = {
  basis: {
    monthlyFixedCost: number;
    fixedCostFromExpenses: boolean;
    activeProfessionals: number;
    sellableHoursPerMonth: number;
    fixedCostPerHour: number;
    averageCommissionPercent: number;
    settings: PricingSettings;
  };
  services: ServicePricing[];
};

// ---- Plano (teste grátis / pago) ----

export type Plan = "TRIAL" | "PAID";
export type PlanStatus = "TRIAL" | "ACTIVE" | "EXPIRED";

export type Usage = { used: number; max: number };

export type PlanInfo = {
  status: PlanStatus;
  plan: Plan;
  trialEndsAt: string;
  paidUntil: string | null;
  daysLeft: number | null;
  professionals: Usage;
  services: Usage;
  customers: Usage;
  contactWhatsapp: string;
  contactEmail: string;
  photos: Usage;
  billingAvailable: boolean;
  playProductId: string;
  managedByPlay: boolean;
};

/** Condições do teste grátis (página de cadastro) e configuração da plataforma. */
export type TrialTerms = {
  trialDays: number;
  maxProfessionals: number;
  maxServices: number;
  maxCustomers: number;
  contactWhatsapp: string;
  contactEmail: string;
  /** Fotos do portfólio no teste grátis. */
  maxPhotos: number;
  /** Só na configuração da plataforma: fotos no plano pago. */
  maxPhotosPaid?: number;
  /** Só na configuração da plataforma: chave "Cobrança na loja" e produto da Play. */
  billingEnabled?: boolean;
  playProductId?: string;
};

/** Fusos do Brasil (sem horário de verão). */
export const TIMEZONES: { value: string; label: string }[] = [
  { value: "America/Sao_Paulo", label: "Brasília (maioria dos estados)" },
  { value: "America/Manaus", label: "Amazonas, MT, MS, RO e RR (1h a menos)" },
  { value: "America/Rio_Branco", label: "Acre (2h a menos)" },
  { value: "America/Noronha", label: "Fernando de Noronha (1h a mais)" },
];
