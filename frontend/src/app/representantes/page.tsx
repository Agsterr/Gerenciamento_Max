"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button, Card, ErrorMessage, Field, NewPasswordFields } from "@/components/ui";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import type { User } from "@/lib/types";

/** Cadastro público do representante: gera o código e o link para indicar salões. */
export default function RepresentativeSignUp() {
  const router = useRouter();
  const { signIn } = useAuth();
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [error, setError] = useState<string>();
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = new FormData(e.currentTarget);
    if (password !== confirm) return setError("As senhas não conferem.");
    setBusy(true);
    setError(undefined);
    try {
      const res = await api.post<{ token: string; user: User }>("/api/auth/register-representative", {
        name: form.get("name"),
        email: form.get("email"),
        password,
        pixKey: form.get("pixKey"),
      });
      signIn(res.token, res.user);
      router.push("/representante");
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="bg-night flex min-h-screen items-center justify-center px-4 py-8">
      <Card className="w-full max-w-md rounded-3xl p-7">
        <Link href="/" className="text-brand text-lg font-extrabold">
          Salão Max
        </Link>
        <h1 className="mt-2 text-xl font-semibold">Seja representante</h1>
        <div className="mb-4 mt-3 rounded-2xl bg-[#FFF1F6] p-4 text-sm text-brand-ink">
          <p className="font-extrabold">Ganhe R$ 15,00 por mês por salão indicado</p>
          <p className="mt-1">
            Você recebe um link só seu. Cada salão que se cadastrar por ele e pagar a mensalidade gera R$ 15,00 para você, todo mês
            em que o pagamento for confirmado. Se o salão cancelar, os próximos meses deixam de contar; se o pagamento for
            estornado, aquele valor é descontado.
          </p>
        </div>
        <form onSubmit={onSubmit} className="space-y-3">
          <Field label="Seu nome" name="name" required autoComplete="name" />
          <Field label="E-mail" name="email" type="email" required autoComplete="email" />
          <Field label="Chave Pix para receber (pode preencher depois)" name="pixKey" />
          <NewPasswordFields value={password} onChange={setPassword} confirm={confirm} onConfirmChange={setConfirm} />
          <ErrorMessage message={error} />
          <Button className="w-full" disabled={busy}>
            {busy ? "Criando..." : "Criar meu link"}
          </Button>
        </form>
        <p className="mt-4 text-center text-sm text-zinc-600">
          Já é representante?{" "}
          <Link href="/login" className="font-bold text-brand-rose">
            Entrar
          </Link>
        </p>
      </Card>
    </main>
  );
}
