"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button, Card, ErrorMessage, Field } from "@/components/ui";
import { api } from "@/lib/api";
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
      router.push("/painel");
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center px-4">
      <Card className="w-full max-w-sm p-6">
        <Link href="/" className="text-lg font-bold text-rose-600">
          Salão Max
        </Link>
        <h1 className="mb-4 mt-2 text-xl font-semibold">Entrar no painel</h1>
        <form onSubmit={onSubmit} className="space-y-3">
          <Field label="E-mail" name="email" type="email" required autoComplete="email" />
          <Field label="Senha" name="password" type="password" required autoComplete="current-password" />
          <ErrorMessage message={error} />
          <Button className="w-full" disabled={busy}>
            {busy ? "Entrando..." : "Entrar"}
          </Button>
        </form>
        <p className="mt-4 text-center text-sm text-zinc-600">
          Novo por aqui?{" "}
          <Link href="/cadastro" className="font-medium text-rose-600">
            Cadastre seu salão
          </Link>
        </p>
      </Card>
    </main>
  );
}
