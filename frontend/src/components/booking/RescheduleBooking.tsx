"use client";

import { useEffect, useMemo, useState } from "react";
import { SlotPicker } from "@/components/agenda/SlotPicker";
import { ErrorMessage } from "@/components/ui";
import { api } from "@/lib/api";
import { bookableDays } from "@/lib/format";
import type { Booking, PublicSalon, Slot } from "@/lib/types";
import { useApi } from "@/lib/useApi";

/** Cliente escolhe outro dia/horário livre para o mesmo serviço. */
export function RescheduleBooking({
  slug,
  booking,
  onDone,
  onCancel,
}: {
  slug: string;
  booking: Booking;
  onDone: () => void;
  onCancel: () => void;
}) {
  const base = `/api/public/salons/${slug}`;
  const { data: salon } = useApi<PublicSalon>(base);
  const [professionalId, setProfessionalId] = useState<number | null>(booking.professionalId);
  const [date, setDate] = useState<string | null>(null);
  const [time, setTime] = useState<string | null>(null);
  const [error, setError] = useState<string>();
  const [busy, setBusy] = useState(false);

  const days = useMemo(() => (salon ? bookableDays(salon.workDays) : []), [salon]);
  useEffect(() => {
    if (!date && days.length) setDate(days.includes(booking.startAt.slice(0, 10)) ? booking.startAt.slice(0, 10) : days[0]);
  }, [days, date, booking.startAt]);
  useEffect(() => setTime(null), [professionalId, date]);

  const { data: slots, loading } = useApi<Slot[]>(
    date
      ? `${base}/availability?serviceId=${booking.serviceId}&date=${date}` + (professionalId ? `&professionalId=${professionalId}` : "")
      : null,
  );

  async function confirm() {
    if (!date || !time) return;
    const pro = professionalId ?? slots?.find((s) => s.time.startsWith(time))?.professionalIds[0] ?? null;
    setBusy(true);
    setError(undefined);
    try {
      await api.post(`${base}/bookings/${booking.token}/reschedule`, { startAt: `${date}T${time}:00`, professionalId: pro });
      onDone();
    } catch (e) {
      setError((e as Error).message);
      setBusy(false);
    }
  }

  return (
    <div className="mt-6 space-y-4 text-left">
      <h2 className="text-lg font-extrabold">Escolha o novo horário</h2>
      {salon && salon.professionals.length > 1 && (
        <div className="flex gap-2 overflow-x-auto pb-1">
          {[{ id: null, name: "Qualquer um" }, ...salon.professionals].map((p) => (
            <button
              key={p.id ?? 0}
              onClick={() => setProfessionalId(p.id)}
              className={`shrink-0 rounded-full px-3 py-1.5 text-sm font-bold ${
                professionalId === p.id ? "bg-brand text-white" : "border-2 border-[#F1E3EB] bg-white"
              }`}
            >
              {p.name}
            </button>
          ))}
        </div>
      )}
      <div className="flex gap-2 overflow-x-auto pb-1">
        {days.map((d) => {
          const dt = new Date(d + "T12:00:00");
          return (
            <button
              key={d}
              onClick={() => setDate(d)}
              className={`min-w-15 rounded-2xl px-2 py-2.5 text-center ${date === d ? "bg-brand text-white" : "border-2 border-[#F1E3EB] bg-white"}`}
            >
              <span className="block text-xs font-semibold capitalize opacity-80">{dt.toLocaleDateString("pt-BR", { weekday: "short" }).replace(".", "")}</span>
              <span className="block text-xl font-extrabold">{dt.getDate()}</span>
            </button>
          );
        })}
      </div>
      <SlotPicker slots={slots} loading={loading} value={time} onChange={setTime} />
      <ErrorMessage message={error} />
      <div className="flex gap-2">
        <button onClick={onCancel} className="flex-1 rounded-2xl border-2 border-[#F1E3EB] py-3 font-bold">
          Voltar
        </button>
        <button
          onClick={confirm}
          disabled={!time || busy}
          className="bg-brand shadow-glow flex-[2] rounded-2xl py-3 font-extrabold text-white disabled:opacity-50 disabled:shadow-none"
        >
          {busy ? "Remarcando..." : time ? `Remarcar para ${time}` : "Escolha um horário"}
        </button>
      </div>
    </div>
  );
}
