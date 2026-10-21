"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button, Card, ErrorMessage, Field, PasswordField } from "@/components/ui";
import { api, credStore } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import type { User } from "@/lib/types";

export default function LoginPage() {
  const router = useRouter();
  const { signIn } = useAuth();
  const [error, setError] = useState<string>();
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = new FormData(e.currentTarget);
    setBusy(true);
    setError(undefined);
    try {
      const res = await api.post<{ token: string; user: User }>("/api/auth/login", {
        email: form.get("email"),
        password: form.get("password"),
      });
      signIn(res.token, res.user);
      if (form.get("keep")) credStore.set(String(form.get("email")), String(form.get("password")));
      else credStore.clear();
      router.push(res.user.role === "PLATFORM_ADMIN" ? "/plataforma" : "/painel");
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="bg-night flex min-h-screen items-center justify-center px-4">
      <Card className="w-full max-w-sm rounded-3xl p-7">
        <Link href="/" className="text-brand text-lg font-extrabold">
          Salão Max
        </Link>
        <h1 className="mb-4 mt-2 text-xl font-semibold">Entrar no painel</h1>
        <form onSubmit={onSubmit} className="space-y-3">
          <Field label="E-mail" name="email" type="email" required autoComplete="email" />
          <PasswordField label="Senha" name="password" required autoComplete="current-password" />
          <label className="flex items-center gap-2 text-sm text-zinc-700">
            <input type="checkbox" name="keep" className="h-4 w-4" />
            Manter conectado
          </label>
          <Link href="/esqueci-senha" className="block text-right text-sm font-semibold text-brand-rose hover:underline">
            Esqueci minha senha
          </Link>
          <ErrorMessage message={error} />
          <Button className="w-full" disabled={busy}>
            {busy ? "Entrando..." : "Entrar"}
          </Button>
        </form>
        <p className="mt-4 text-center text-sm text-zinc-600">
          Novo por aqui?{" "}
          <Link href="/cadastro" className="font-bold text-brand-rose">
            Cadastre seu salão
          </Link>
        </p>
      </Card>
    </main>
  );
}
