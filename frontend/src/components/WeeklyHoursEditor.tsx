"use client";

import { TimeSelect } from "@/components/TimeSelect";
import type { DayHours } from "@/lib/types";

const DAYS = [
  { day: 1, label: "Segunda" },
  { day: 2, label: "Terça" },
  { day: 3, label: "Quarta" },
  { day: 4, label: "Quinta" },
  { day: 5, label: "Sexta" },
  { day: 6, label: "Sábado" },
  { day: 7, label: "Domingo" },
];

const hhmm = (t: string | null) => (t ? t.slice(0, 5) : null);

/** Normaliza o que vem da API ("09:00:00") para "09:00". */
export function normalizeHours(hours: DayHours[]): DayHours[] {
  return hours.map((h) => ({
    ...h,
    openTime: hhmm(h.openTime)!,
    closeTime: hhmm(h.closeTime)!,
    breakStart: hhmm(h.breakStart),
    breakEnd: hhmm(h.breakEnd),
  }));
}

/** Grade semanal: cada dia aberto/fechado, com horário próprio e pausa opcional (almoço). */
export function WeeklyHoursEditor({ value, onChange }: { value: DayHours[]; onChange: (v: DayHours[]) => void }) {
  const byDay = new Map(value.map((h) => [h.dayOfWeek, h]));
  const sorted = (list: DayHours[]) => [...list].sort((a, b) => a.dayOfWeek - b.dayOfWeek);

  const update = (day: number, patch: Partial<DayHours>) =>
    onChange(sorted(value.map((h) => (h.dayOfWeek === day ? { ...h, ...patch } : h))));

  const toggle = (day: number) => {
    if (byDay.has(day)) return onChange(value.filter((h) => h.dayOfWeek !== day));
    const model = value[0] ?? { openTime: "09:00", closeTime: "18:00", breakStart: null, breakEnd: null };
    onChange(sorted([...value, { ...model, dayOfWeek: day }]));
  };

  const copyToAll = (from: DayHours) =>
    onChange(value.map((h) => ({ ...from, dayOfWeek: h.dayOfWeek })));

  return (
    <div className="space-y-2">
      {DAYS.map(({ day, label }) => {
        const h = byDay.get(day);
        return (
          <div key={day} className={`rounded-2xl border p-3 ${h ? "border-[#F1E3EB] bg-white" : "border-dashed border-[#E9DCE4] bg-[#FFFBFD]"}`}>
            <div className="flex items-center justify-between gap-2">
              <span className={`font-bold ${h ? "text-brand-ink" : "text-brand-muted"}`}>{label}</span>
              <button
                type="button"
                role="switch"
                aria-checked={!!h}
                aria-label={`${label}: ${h ? "aberto" : "fechado"}`}
                onClick={() => toggle(day)}
                className={`flex items-center gap-2 rounded-full px-3 py-1 text-sm font-bold ${
                  h ? "bg-brand text-white" : "bg-[#F1E3EB] text-brand-muted"
                }`}
              >
                {h ? "Aberto" : "Fechado"}
              </button>
            </div>

            {h && (
              <div className="mt-3 space-y-3">
                <div className="flex flex-wrap gap-3">
                  <TimeSelect label="Abre" value={h.openTime} onChange={(v) => v && update(day, { openTime: v })} />
                  <TimeSelect label="Fecha" value={h.closeTime} onChange={(v) => v && update(day, { closeTime: v })} />
                </div>

                {h.breakStart != null ? (
                  <div className="flex flex-wrap items-end gap-3 rounded-xl bg-[#FFF1F6] p-2">
                    <TimeSelect label="Pausa de" value={h.breakStart} onChange={(v) => update(day, { breakStart: v ?? h.breakStart })} />
                    <TimeSelect label="até" value={h.breakEnd} onChange={(v) => update(day, { breakEnd: v ?? h.breakEnd })} />
                    <button type="button" className="pb-2.5 text-sm font-bold text-brand-muted hover:text-brand-rose"
                      onClick={() => update(day, { breakStart: null, breakEnd: null })}>
                      Remover pausa
                    </button>
                  </div>
                ) : (
                  <button type="button" className="text-sm font-bold text-brand-rose"
                    onClick={() => update(day, { breakStart: "12:00", breakEnd: "13:00" })}>
                    + Adicionar pausa (almoço)
                  </button>
                )}

                {value.length > 1 && (
                  <button type="button" className="block text-xs font-semibold text-brand-muted underline" onClick={() => copyToAll(h)}>
                    Usar este horário em todos os dias abertos
                  </button>
                )}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}
