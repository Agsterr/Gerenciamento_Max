"use client";

import type { Slot } from "@/lib/types";

/** Grade de horários livres. */
export function SlotPicker({
  slots,
  value,
  onChange,
  loading,
}: {
  slots: Slot[] | undefined;
  value: string | null;
  onChange: (time: string) => void;
  loading?: boolean;
}) {
  if (loading || !slots) return <p className="text-sm text-zinc-500">Buscando horários...</p>;
  if (slots.length === 0) return <p className="text-sm text-zinc-500">Nenhum horário livre nesse dia.</p>;
  return (
    <div className="grid grid-cols-4 gap-2 sm:grid-cols-5">
      {slots.map((s) => {
        const time = s.time.slice(0, 5);
        return (
          <button
            type="button"
            key={s.time}
            onClick={() => onChange(time)}
            className={`rounded-lg border px-2 py-2 text-sm font-medium ${
              value === time ? "border-rose-600 bg-rose-600 text-white" : "border-zinc-300 bg-white hover:border-rose-400"
            }`}
          >
            {time}
          </button>
        );
      })}
    </div>
  );
}
