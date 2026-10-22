const money = new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" });

export const formatMoney = (value: number | null | undefined) => money.format(value ?? 0);

/** "2026-10-20T14:30:00" -> "14:30" */
export const formatTime = (iso: string) => iso.slice(11, 16);

/** "2026-10-20" -> "20/10/2026" */
export const formatDate = (iso: string) => iso.slice(0, 10).split("-").reverse().join("/");

export const formatDateTime = (iso: string) => `${formatDate(iso)} ${formatTime(iso)}`;

/** Data local no formato ISO (yyyy-mm-dd), sem conversão para UTC. */
export function isoDate(d = new Date()) {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

export function addDays(iso: string, days: number) {
  const d = new Date(iso + "T12:00:00");
  d.setDate(d.getDate() + days);
  return isoDate(d);
}

export function weekdayLabel(iso: string) {
  const label = new Date(iso + "T12:00:00").toLocaleDateString("pt-BR", { weekday: "long", day: "2-digit", month: "long" });
  return label.charAt(0).toUpperCase() + label.slice(1);
}

/** Próximos dias em que o salão abre ("1,2,..." com 1 = segunda), a partir de hoje. */
export function bookableDays(workDays: string, count = 14) {
  const work = workDays.split(",");
  const today = isoDate();
  return Array.from({ length: count * 2 }, (_, i) => addDays(today, i))
    .filter((d) => work.includes(String(((new Date(d + "T12:00:00").getDay() + 6) % 7) + 1)))
    .slice(0, count);
}

/** "2026-10-20T14:30:00" -> "Ter., 20/10 às 14:30" */
export function shortDateTime(iso: string) {
  const day = new Date(iso.slice(0, 10) + "T12:00:00").toLocaleDateString("pt-BR", { weekday: "short", day: "2-digit", month: "2-digit" });
  return `${day.charAt(0).toUpperCase()}${day.slice(1)} às ${formatTime(iso)}`;
}

/** Link do WhatsApp com mensagem pronta (telefone salvo só com dígitos, DDD incluso). */
export const whatsappLink = (phone: string, text?: string) =>
  `https://wa.me/55${phone.replace(/\D/g, "")}` + (text ? `?text=${encodeURIComponent(text)}` : "");

export const formatPhone = (phone: string) => {
  const d = phone.replace(/\D/g, "");
  if (d.length === 11) return `(${d.slice(0, 2)}) ${d.slice(2, 7)}-${d.slice(7)}`;
  if (d.length === 10) return `(${d.slice(0, 2)}) ${d.slice(2, 6)}-${d.slice(6)}`;
  return phone;
};

/** Situação como o cliente entende: aguardando o salão, confirmado pelo salão, cancelado... */
export function customerStatusLabel(status: string, salonConfirmed: boolean): string {
  if (status === "SCHEDULED" || status === "CONFIRMED") return salonConfirmed ? "Confirmado pelo salão" : "Aguardando confirmação do salão";
  return STATUS_LABEL[status] ?? status;
}

export const STATUS_LABEL: Record<string, string> = {
  SCHEDULED: "Agendado",
  CONFIRMED: "Confirmado",
  IN_PROGRESS: "Em atendimento",
  DONE: "Finalizado",
  CANCELED: "Cancelado",
  NO_SHOW: "Faltou",
};

export const STATUS_COLOR: Record<string, string> = {
  SCHEDULED: "bg-sky-100 text-sky-800",
  CONFIRMED: "bg-indigo-100 text-indigo-800",
  IN_PROGRESS: "bg-amber-100 text-amber-800",
  DONE: "bg-emerald-100 text-emerald-800",
  CANCELED: "bg-zinc-200 text-zinc-600",
  NO_SHOW: "bg-rose-100 text-rose-800",
};

export const WEEKDAYS = [
  { value: "1", label: "Seg" },
  { value: "2", label: "Ter" },
  { value: "3", label: "Qua" },
  { value: "4", label: "Qui" },
  { value: "5", label: "Sex" },
  { value: "6", label: "Sáb" },
  { value: "7", label: "Dom" },
];

export const REMINDER_MODES: { value: import("./types").ReminderMode; label: string }[] = [
  { value: "OFF", label: "Desligado" },
  { value: "ONE_DAY", label: "1 dia antes" },
  { value: "TWO_DAYS", label: "2 dias antes" },
  { value: "BOTH", label: "2 dias e 1 dia antes" },
];

/** Agrupa serviços por categoria na ordem em que aparecem; sem categoria vai para o fim, como "Outros". */
export function groupByCategory<T extends { category: string | null }>(items: T[]): [string, T[]][] {
  const groups = new Map<string, T[]>();
  for (const item of items) {
    const key = item.category?.trim() || "Outros";
    groups.set(key, [...(groups.get(key) ?? []), item]);
  }
  const others = groups.get("Outros");
  groups.delete("Outros");
  return [...groups.entries(), ...(others ? ([["Outros", others]] as [string, T[]][]) : [])];
}

type Promo = { promoPrice: number | null; promoStartsOn: string | null; promoEndsOn: string | null };

/** Preço promocional que vale no dia (data "YYYY-MM-DD"); sem dia, o de hoje. Nulo = preço normal. */
export function promoPriceOn(s: Promo, day?: string | null): number | null {
  if (s.promoPrice == null || !s.promoStartsOn || !s.promoEndsOn) return null;
  const d = day ?? new Date().toLocaleDateString("sv-SE");
  return d >= s.promoStartsOn && d <= s.promoEndsOn ? s.promoPrice : null;
}
