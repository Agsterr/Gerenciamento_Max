"use client";

/**
 * Seletor de horário com duas listas (hora e minuto).
 * Substitui o <input type="time">, cujo relógio nativo do Android corta o botão de confirmar
 * quando a fonte do celular está grande.
 */
const HOURS = Array.from({ length: 24 }, (_, h) => String(h).padStart(2, "0"));

export function TimeSelect({
  label,
  value,
  onChange,
  step = 5,
  className = "",
  allowEmpty = false,
}: {
  label: string;
  /** "HH:mm" (segundos são ignorados) ou vazio */
  value: string | null;
  onChange: (value: string | null) => void;
  step?: number;
  className?: string;
  allowEmpty?: boolean;
}) {
  const minutes = Array.from({ length: 60 / step }, (_, i) => String(i * step).padStart(2, "0"));
  const [h, m] = value ? value.slice(0, 5).split(":") : ["", ""];
  // mantém minutos fora do passo (ex.: 10:07 vindo da API) selecionáveis
  const minuteOptions = m && !minutes.includes(m) ? [...minutes, m].sort() : minutes;
  const select =
    "rounded-xl border border-[#F1E3EB] bg-white px-2 py-2.5 text-base font-semibold outline-none focus:border-brand-rose";

  return (
    <div className={`block text-sm ${className}`} role="group" aria-label={label}>
      <span className="mb-1 block font-semibold text-brand-ink">{label}</span>
      <div className="flex items-center gap-1">
        <select
          aria-label={`${label} — hora`}
          className={select}
          value={h}
          onChange={(e) => onChange(e.target.value === "" ? null : `${e.target.value}:${m || "00"}`)}
        >
          {(allowEmpty || !h) && <option value="">--</option>}
          {HOURS.map((x) => (
            <option key={x} value={x}>
              {x}
            </option>
          ))}
        </select>
        <span className="font-bold text-brand-muted">:</span>
        <select
          aria-label={`${label} — minuto`}
          className={select}
          value={m}
          disabled={!h}
          onChange={(e) => onChange(`${h}:${e.target.value}`)}
        >
          {!h && <option value="">--</option>}
          {minuteOptions.map((x) => (
            <option key={x} value={x}>
              {x}
            </option>
          ))}
        </select>
      </div>
    </div>
  );
}
