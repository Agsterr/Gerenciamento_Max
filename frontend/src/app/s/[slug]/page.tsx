"use client";

import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import { useEffect, useMemo, useState } from "react";
import { SlotPicker } from "@/components/agenda/SlotPicker";
import { Gallery } from "@/components/Gallery";
import { AppPromo } from "@/components/InstallApp";
import { Icon, serviceIcon } from "@/components/Icon";
import { ErrorMessage, Field } from "@/components/ui";
import { api } from "@/lib/api";
import { bookableDays, formatDate, formatMoney, groupByCategory, promoPriceOn } from "@/lib/format";
import type { Booking, Photo, PublicSalon, Slot } from "@/lib/types";
import { useApi } from "@/lib/useApi";

/** Versão do cliente: escolhe serviço → profissional → dia/horário → nome e telefone. */
export default function PublicBookingPage() {
  const { slug } = useParams<{ slug: string }>();
  const router = useRouter();
  const base = `/api/public/salons/${slug}`;
  const { data: salon, error: salonError } = useApi<PublicSalon>(base);
  const { data: photos } = useApi<Photo[]>(`${base}/portfolio`);
  const [photoFilter, setPhotoFilter] = useState<number | null>(null);
  const [allPhotos, setAllPhotos] = useState(false);

  const [serviceId, setServiceId] = useState<number | null>(null);
  const [professionalId, setProfessionalId] = useState<number | null>(null);
  const [photoCategory, setPhotoCategory] = useState<string | null>(null);
  const [date, setDate] = useState<string | null>(null);
  const [time, setTime] = useState<string | null>(null);
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [error, setError] = useState<string>();
  const [busy, setBusy] = useState(false);

  const days = useMemo(
    () => (salon ? bookableDays(salon.workDays) : []),
    [salon],
  );

  useEffect(() => {
    if (!date && days.length) setDate(days[0]);
  }, [days, date]);
  useEffect(() => setTime(null), [serviceId, professionalId, date]);

  const slotsPath =
    serviceId && date
      ? `${base}/availability?serviceId=${serviceId}&date=${date}` +
        (professionalId ? `&professionalId=${professionalId}` : "")
      : null;
  const { data: slots, loading } = useApi<Slot[]>(slotsPath);

  if (salonError) return <Centered>Salão não encontrado.</Centered>;
  if (!salon) return <Centered>Carregando...</Centered>;

  const service = salon.services.find((s) => s.id === serviceId);
  const servicePhotos = photos?.filter((p) => p.serviceId === serviceId) ?? [];
  const categoryOf = (id: number | null) =>
    salon.services.find((s) => s.id === id)?.category ?? "Outros";
  const groups = groupByCategory(salon.services);
  const categories = groups.map(([name]) => name);
  const photoServices = salon.services.filter(
    (s) =>
      photos?.some((p) => p.serviceId === s.id) &&
      (photoCategory === null || categoryOf(s.id) === photoCategory),
  );
  const shownPhotos =
    photos?.filter(
      (p) =>
        (photoFilter === null || p.serviceId === photoFilter) &&
        (photoCategory === null || categoryOf(p.serviceId) === photoCategory),
    ) ?? [];

  async function book(e: React.FormEvent) {
    e.preventDefault();
    if (!serviceId || !date || !time) return;
    setBusy(true);
    setError(undefined);
    try {
      const res = await api.post<Booking>(`${base}/bookings`, {
        serviceId,
        professionalId,
        startAt: `${date}T${time}:00`,
        name,
        phone,
      });
      router.push(`/s/${slug}/agendamento/${res.token}`);
    } catch (err) {
      setError((err as Error).message);
      setBusy(false);
    }
  }

  const initials = salon.name
    .split(/\s+/)
    .filter(Boolean)
    .map((w, i, a) => (i === 0 || i === a.length - 1 ? w[0] : ""))
    .join("")
    .toUpperCase();

  return (
    <main className="min-h-screen pb-40">
      <header className="bg-brand relative overflow-hidden rounded-b-[2rem] px-4 pb-8 pt-8 text-white">
        <div className="pointer-events-none absolute -right-16 -top-16 h-56 w-56 rounded-full bg-white/20 blur-2xl" />
        <div className="relative mx-auto flex max-w-xl items-center gap-4">
          <div className="flex h-16 w-16 shrink-0 items-center justify-center rounded-full bg-white text-xl font-extrabold text-brand-rose ring-4 ring-white/30">
            {initials}
          </div>
          <div className="min-w-0">
            <h1 className="truncate text-2xl font-extrabold">{salon.name}</h1>
            {salon.address && (
              <p className="flex items-center gap-1 truncate text-sm text-white/80">
                <Icon name="pin" className="h-4 w-4 shrink-0" /> {salon.address}
              </p>
            )}
            <p className="mt-1 text-sm font-semibold text-white/90">
              Agende seu horário online
            </p>
          </div>
        </div>
        <div className="relative mx-auto mt-5 max-w-xl">
          <Link
            href={`/s/${slug}/meus-horarios`}
            className="inline-flex items-center gap-2 rounded-full bg-white/20 px-4 py-2 text-sm font-bold text-white ring-1 ring-white/40 backdrop-blur transition hover:bg-white/30"
          >
            <Icon name="search" className="h-4 w-4" /> Já agendou? Ver ou
            remarcar meus horários
          </Link>
        </div>
      </header>

      <div className="mx-auto max-w-xl px-4">
        {salon.promotions.length > 0 && (
          <section className="mt-6 space-y-2">
            {salon.promotions.map((p) => (
              <div key={p.id} className="flex items-start gap-3 rounded-2xl bg-gradient-to-r from-amber-100 to-rose-100 p-4">
                <Icon name="sparkles" className="mt-0.5 h-5 w-5 shrink-0 text-amber-600" />
                <div className="text-sm">
                  <p className="font-extrabold text-brand-ink">
                    {p.name} · {p.discountPercent}% de desconto
                  </p>
                  {p.description && <p className="text-brand-muted">{p.description}</p>}
                  <p className="text-brand-muted">
                    Para horários de {formatDate(p.startsOn)} a {formatDate(p.endsOn)}
                    {p.serviceIds.length > 0 &&
                      ` em ${salon.services.filter((s) => p.serviceIds.includes(s.id)).map((s) => s.name).join(", ")}`}
                    .
                  </p>
                </div>
              </div>
            ))}
          </section>
        )}
        {photos && photos.length > 0 && (
          <section className="mt-7">
            <h2 className="mb-3 text-lg font-extrabold">Nossos trabalhos</h2>
            {categories.length > 1 && (
              <div className="mb-2 flex gap-2 overflow-x-auto pb-1">
                {[null, ...categories].map((c) => (
                  <button
                    key={c ?? "todas"}
                    onClick={() => {
                      setPhotoCategory(c);
                      setPhotoFilter(null);
                    }}
                    className={`shrink-0 rounded-full px-3 py-1.5 text-sm font-bold ${
                      photoCategory === c
                        ? "bg-brand-ink text-white"
                        : "border border-[#F1E3EB] bg-white text-brand-muted"
                    }`}
                  >
                    {c ?? "Todas"}
                  </button>
                ))}
              </div>
            )}
            {photoServices.length > 0 && (
              <div className="mb-3 flex gap-2 overflow-x-auto pb-1">
                {[
                  { id: null as number | null, name: "Todos" },
                  ...photoServices,
                ].map((s) => (
                  <button
                    key={s.id ?? 0}
                    onClick={() => setPhotoFilter(s.id)}
                    className={`shrink-0 rounded-full px-3 py-1.5 text-sm font-bold ${
                      photoFilter === s.id
                        ? "bg-brand text-white"
                        : "border border-[#F1E3EB] bg-white text-brand-muted"
                    }`}
                  >
                    {s.name}
                  </button>
                ))}
              </div>
            )}
            <Gallery
              key={photoFilter ?? 0}
              photos={allPhotos ? shownPhotos : shownPhotos.slice(0, 9)}
            />
            {!allPhotos && shownPhotos.length > 9 && (
              <button
                onClick={() => setAllPhotos(true)}
                className="mt-2 text-sm font-bold text-brand-rose hover:underline"
              >
                Ver todas as {shownPhotos.length} fotos
              </button>
            )}
          </section>
        )}

        <Step n={1} title="Escolha o serviço">
          <div className="space-y-3">
            {groups.map(([category, items]) => (
              <div key={category} className="space-y-3">
                {groups.length > 1 && (
                  <h3 className="pt-1 text-sm font-extrabold text-brand-muted">
                    {category}
                  </h3>
                )}
                {items.map((s) => {
                  const active = serviceId === s.id;
                  return (
                    <button
                      key={s.id}
                      onClick={() => {
                        setServiceId(s.id);
                        if (
                          professionalId &&
                          s.professionalIds.length > 0 &&
                          !s.professionalIds.includes(professionalId)
                        )
                          setProfessionalId(null);
                      }}
                      className={`shadow-soft flex w-full items-center gap-4 rounded-2xl border-2 bg-white p-4 text-left transition ${
                        active
                          ? "border-brand-rose"
                          : "border-transparent hover:border-brand-pink/40"
                      }`}
                    >
                      <span
                        className={`flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl ${active ? "bg-brand text-white" : "bg-[#FFEAF2] text-brand-rose"}`}
                      >
                        <Icon name={serviceIcon(s.name)} />
                      </span>
                      <span className="min-w-0 flex-1">
                        <span className="block font-extrabold">{s.name}</span>
                        {s.kitItems.length > 0 && (
                          <span className="block text-xs text-brand-muted">Inclui {s.kitItems.join(" + ")}</span>
                        )}
                        {s.promoName && (
                          <span className="mt-1 inline-block rounded-full bg-amber-100 px-2 py-0.5 text-xs font-bold text-amber-800">
                            {s.promoName}: -{s.promoPercent}% {s.promoStartsOn && s.promoEndsOn && `de ${formatDate(s.promoStartsOn)} a ${formatDate(s.promoEndsOn)}`}
                          </span>
                        )}
                        <span className="mt-1 inline-flex items-center gap-1 rounded-full bg-[#F6EEF3] px-2 py-0.5 text-xs font-bold text-brand-muted">
                          <Icon name="clock" className="h-3.5 w-3.5" />{" "}
                          {s.durationMinutes} min
                        </span>
                      </span>
                      <PriceTag price={s.price} promo={promoPriceOn(s)} full={s.kitFullPrice} />
                    </button>
                  );
                })}
              </div>
            ))}
            {salon.services.length === 0 && (
              <p className="text-sm text-brand-muted">
                Nenhum serviço disponível no momento.
              </p>
            )}
          </div>
          {servicePhotos.length > 0 && (
            <div className="mt-4">
              <p className="mb-2 text-sm font-bold text-brand-muted">
                Fotos de {service?.name}
              </p>
              <Gallery
                key={serviceId ?? 0}
                photos={servicePhotos.slice(0, 6)}
              />
            </div>
          )}
        </Step>

        {service && (
          <Step n={2} title="Com quem?">
            <div className="flex gap-3 overflow-x-auto pb-1">
              {[
                { id: null, name: "Qualquer um" },
                ...salon.professionals.filter(
                  (p) =>
                    service.professionalIds.length === 0 ||
                    service.professionalIds.includes(p.id),
                ),
              ].map((p) => {
                const active = professionalId === p.id;
                return (
                  <button
                    key={p.id ?? 0}
                    onClick={() => setProfessionalId(p.id)}
                    className="w-20 shrink-0 text-center"
                  >
                    <span
                      className={`mx-auto block w-fit rounded-full p-[3px] ${active ? "bg-brand" : ""}`}
                    >
                      <span className="flex h-14 w-14 items-center justify-center rounded-full border-2 border-white bg-gradient-to-br from-[#B794F6] to-[#7C3AED] font-extrabold text-white">
                        {p.id === null ? (
                          <Icon name="shuffle" />
                        ) : (
                          p.name
                            .split(" ")
                            .map((w) => w[0])
                            .slice(0, 2)
                            .join("")
                        )}
                      </span>
                    </span>
                    <span
                      className={`mt-1 block truncate text-sm ${active ? "font-extrabold text-brand-rose" : "font-semibold"}`}
                    >
                      {p.name}
                    </span>
                  </button>
                );
              })}
            </div>
          </Step>
        )}

        {service && (
          <Step n={3} title="Quando?">
            <div className="mb-4 flex gap-2 overflow-x-auto pb-1">
              {days.map((d) => {
                const dt = new Date(d + "T12:00:00");
                const active = date === d;
                return (
                  <button
                    key={d}
                    onClick={() => setDate(d)}
                    className={`min-w-15 rounded-2xl px-2 py-2.5 text-center transition ${
                      active
                        ? "bg-brand shadow-glow text-white"
                        : "border-2 border-[#F1E3EB] bg-white"
                    }`}
                  >
                    <span className="block text-xs font-semibold capitalize opacity-80">
                      {dt
                        .toLocaleDateString("pt-BR", { weekday: "short" })
                        .replace(".", "")}
                    </span>
                    <span className="block text-xl font-extrabold">
                      {dt.getDate()}
                    </span>
                  </button>
                );
              })}
            </div>
            <SlotPicker
              slots={slots}
              loading={loading}
              value={time}
              onChange={setTime}
            />
          </Step>
        )}

        {time && (
          <Step n={4} title="Seus dados">
            <form
              id="booking"
              onSubmit={book}
              className="shadow-soft space-y-3 rounded-2xl bg-white p-4"
            >
              <Field
                label="Nome"
                required
                autoComplete="name"
                value={name}
                onChange={(e) => setName(e.target.value)}
              />
              <Field
                label="WhatsApp"
                required
                type="tel"
                inputMode="tel"
                autoComplete="tel"
                placeholder="(11) 99999-9999"
                minLength={10}
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
              />
              <p className="flex items-start gap-1.5 text-xs text-brand-muted">
                <Icon name="shield" className="h-4 w-4 shrink-0" />
                <span>
                  Seus dados vão apenas para {salon.name}. Ao agendar você
                  concorda com a{" "}
                  <a href="/privacidade" className="underline">
                    Política de Privacidade
                  </a>
                  .
                </span>
              </p>
              <ErrorMessage message={error} />
            </form>
          </Step>
        )}

        <AppPromo className="mt-10" />
      </div>

      {service && (
        <div className="fixed inset-x-0 bottom-0 z-20 rounded-t-3xl bg-white/95 px-4 pb-5 pt-4 shadow-[0_-8px_30px_rgba(0,0,0,0.08)] backdrop-blur">
          <div className="mx-auto flex max-w-xl items-center gap-4">
            <div className="min-w-0 flex-1">
              <p className="truncate font-extrabold">{service.name}</p>
              <p className="text-sm text-brand-muted">
                {time && date
                  ? `${new Date(date + "T12:00:00").toLocaleDateString("pt-BR", { weekday: "short", day: "numeric", month: "short" })} · ${time}`
                  : "Escolha um horário"}
              </p>
              <p className="font-extrabold text-brand-rose">
                {promoPriceOn(service, date) != null ? (
                  <>
                    <span className="mr-1 text-sm font-semibold text-zinc-400 line-through">{formatMoney(service.price)}</span>
                    {formatMoney(promoPriceOn(service, date)!)}
                  </>
                ) : (
                  formatMoney(service.price)
                )}
              </p>
            </div>
            <button
              form="booking"
              disabled={!time || busy}
              className="bg-brand shadow-glow rounded-2xl px-7 py-4 font-extrabold text-white transition disabled:opacity-50 disabled:shadow-none"
            >
              {busy ? "Agendando..." : "Agendar"}
            </button>
          </div>
        </div>
      )}
    </main>
  );
}

function Step({
  n,
  title,
  children,
}: {
  n: number;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section className="mt-7">
      <h2 className="mb-3 text-lg font-extrabold">
        {n}. {title}
      </h2>
      {children}
    </section>
  );
}

function Centered({ children }: { children: React.ReactNode }) {
  return <p className="p-12 text-center text-zinc-500">{children}</p>;
}

/** Preço do serviço: pacote mostra a soma riscada; promoção mostra o preço normal riscado. */
function PriceTag({ price, promo, full }: { price: number; promo: number | null; full: number | null }) {
  const old = promo != null ? price : full != null && full > price ? full : null;
  return (
    <span className="text-right font-extrabold text-brand-rose">
      {old != null && <span className="block text-xs font-semibold text-zinc-400 line-through">{formatMoney(old)}</span>}
      {formatMoney(promo ?? price)}
    </span>
  );
}
