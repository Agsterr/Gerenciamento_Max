"use client";

import Link from "next/link";
import { useState } from "react";
import { Button, Card, ErrorMessage, Field } from "@/components/ui";
import { api } from "@/lib/api";

/** Pede o e-mail e manda o link para criar uma nova senha. A resposta é igual exista ou não a conta. */
export default function ForgotPasswordPage() {
  const [sent, setSent] = useState<string>();
  const [error, setError] = useState<string>();
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const email = String(new FormData(e.currentTarget).get("email")).trim();
    setBusy(true);
    setError(undefined);
    try {
      await api.post("/api/auth/forgot-password", { email });
      setSent(email);
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
        <h1 className="mb-2 mt-2 text-xl font-semibold">Esqueci minha senha</h1>
        {sent ? (
          <div className="space-y-3 text-sm text-zinc-700">
            <p>
              Se existe uma conta com <strong>{sent}</strong>, enviamos um link para criar uma nova senha. Ele vale por 1 hora.
            </p>
            <p className="text-zinc-500">Não chegou? Veja a caixa de spam ou tente de novo em alguns minutos.</p>
            <Link href="/login" className="block pt-2 font-bold text-brand-rose">
              Voltar para o login
            </Link>
          </div>
        ) : (
          <form onSubmit={onSubmit} className="space-y-3">
            <p className="text-sm text-zinc-600">Digite o e-mail da sua conta e enviaremos um link para criar uma nova senha.</p>
            <Field label="E-mail" name="email" type="email" required autoComplete="email" />
            <ErrorMessage message={error} />
            <Button className="w-full" disabled={busy}>
              {busy ? "Enviando..." : "Enviar link"}
            </Button>
            <Link href="/login" className="block text-center text-sm text-zinc-600 hover:underline">
              Voltar para o login
            </Link>
          </form>
        )}
      </Card>
    </main>
  );
}
