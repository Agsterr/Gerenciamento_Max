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
};

export type Professional = {
  id: number;
  name: string;
  phone: string | null;
  commissionPercent: number;
  active: boolean;
};

export type Service = {
  id: number;
  name: string;
  description: string | null;
  durationMinutes: number;
  price: number;
  cost: number;
  active: boolean;
};

export type Customer = {
  id: number;
  name: string;
  phone: string;
  email: string | null;
  notes: string | null;
  createdAt: string;
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
  source: "ADMIN" | "ONLINE";
};

export type Slot = { time: string; professionalIds: number[] };

export type Expense = {
  id: number;
  description: string;
  category: string;
  amount: number;
  date: string;
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
};

export type PublicSalon = {
  name: string;
  slug: string;
  phone: string | null;
  address: string | null;
  workDays: string;
  hours: DayHours[];
  services: { id: number; name: string; description: string | null; durationMinutes: number; price: number }[];
  professionals: Ref[];
};

export type Booking = {
  token: string;
  startAt: string;
  endAt: string;
  status: AppointmentStatus;
  serviceName: string;
  professionalName: string;
  price: number;
  customerName: string;
  cancelable: boolean;
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
