"use client";

import { useEffect } from "react";

type ButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: "primary" | "secondary" | "danger" | "ghost";
  size?: "sm" | "md";
};

const VARIANTS = {
  primary: "bg-brand text-white shadow-glow hover:brightness-105 disabled:opacity-50 disabled:shadow-none",
  secondary: "bg-white text-zinc-800 border border-zinc-300 hover:bg-zinc-50",
  danger: "bg-white text-brand-rose border border-rose-200 hover:bg-rose-50",
  ghost: "text-zinc-600 hover:bg-zinc-100",
};

export function Button({ variant = "primary", size = "md", className = "", ...props }: ButtonProps) {
  const sizing = size === "sm" ? "px-2.5 py-1 text-sm" : "px-4 py-2";
  return (
    <button
      className={`rounded-xl font-bold transition disabled:cursor-not-allowed ${sizing} ${VARIANTS[variant]} ${className}`}
      {...props}
    />
  );
}

type FieldProps = React.InputHTMLAttributes<HTMLInputElement> & { label: string };

export function Field({ label, className = "", ...props }: FieldProps) {
  return (
    <label className={`block text-sm ${className}`}>
      <span className="mb-1 block font-semibold text-brand-ink">{label}</span>
      <input
        className="w-full rounded-xl border border-[#F1E3EB] bg-white px-3 py-2.5 outline-none focus:border-brand-rose focus:ring-4 focus:ring-brand-pink/15"
        {...props}
      />
    </label>
  );
}

type SelectProps = React.SelectHTMLAttributes<HTMLSelectElement> & { label: string };

export function Select({ label, className = "", children, ...props }: SelectProps) {
  return (
    <label className={`block text-sm ${className}`}>
      <span className="mb-1 block font-semibold text-brand-ink">{label}</span>
      <select
        className="w-full rounded-xl border border-[#F1E3EB] bg-white px-3 py-2.5 outline-none focus:border-brand-rose"
        {...props}
      >
        {children}
      </select>
    </label>
  );
}

export function Card({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  return <div className={`shadow-soft rounded-2xl bg-white p-4 ${className}`}>{children}</div>;
}

export function PageHeader({ title, children }: { title: string; children?: React.ReactNode }) {
  return (
    <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
      <h1 className="text-2xl font-extrabold tracking-tight text-brand-ink">{title}</h1>
      <div className="flex flex-wrap items-center gap-2">{children}</div>
    </div>
  );
}

export function ErrorMessage({ message }: { message?: string }) {
  if (!message) return null;
  return <p className="rounded-lg bg-rose-50 px-3 py-2 text-sm text-brand-rose">{message}</p>;
}

export function Empty({ children }: { children: React.ReactNode }) {
  return <p className="py-8 text-center text-sm text-zinc-500">{children}</p>;
}

export function Modal({
  title,
  open,
  onClose,
  children,
}: {
  title: string;
  open: boolean;
  onClose: () => void;
  children: React.ReactNode;
}) {
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => e.key === "Escape" && onClose();
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [open, onClose]);

  if (!open) return null;
  return (
    <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 sm:items-center" onClick={onClose}>
      <div
        className="max-h-[92vh] w-full overflow-y-auto rounded-t-2xl bg-white p-5 shadow-xl sm:max-w-lg sm:rounded-2xl"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="mb-4 flex items-center justify-between">
          <h2 className="text-lg font-semibold">{title}</h2>
          <button onClick={onClose} className="text-2xl leading-none text-zinc-400 hover:text-zinc-700" aria-label="Fechar">
            ×
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

export function Badge({ className, children }: { className: string; children: React.ReactNode }) {
  return <span className={`inline-block rounded-full px-2 py-0.5 text-xs font-medium ${className}`}>{children}</span>;
}

export function Stat({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <Card>
      <p className="text-sm text-zinc-500">{label}</p>
      <p className="mt-1 text-2xl font-semibold text-zinc-900">{value}</p>
      {hint && <p className="mt-1 text-xs text-zinc-500">{hint}</p>}
    </Card>
  );
}
