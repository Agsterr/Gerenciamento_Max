"use client";

import Link from "next/link";
import { useSearchParams } from "next/navigation";
import { Suspense, useState } from "react";
import { Button, Card, ErrorMessage, NewPasswordFields } from "@/components/ui";
import { api } from "@/lib/api";

function ResetForm() {
  const token = useSearchParams().get("token") ?? "";
  const [password, setPassword] = useState("");
  const [confirm, setConfirm] = useState("");
  const [done, setDone] = useState(false);
  const [error, setError] = useState<string>();
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (password !== confirm) return setError("As senhas não conferem.");
    setBusy(true);
    setError(undefined);
    try {
      await api.post("/api/auth/reset-password", { token, password });
      setDone(true);
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  }

  if (!token)
    return (
      <p className="text-sm text-zinc-700">
        Link incompleto. Peça um novo em{" "}
        <Link href="/esqueci-senha" className="font-bold text-brand-rose">
          Esqueci minha senha
        </Link>
        .
      </p>
    );
  if (done)
    return (
      <div className="space-y-3 text-sm text-zinc-700">
        <p className="text-lg">✓ Senha alterada!</p>
        <p>Agora é só entrar com a nova senha, no site ou no app.</p>
        <Link href="/login" className="bg-brand shadow-glow block rounded-xl px-4 py-2.5 text-center font-bold text-white">
          Entrar
        </Link>
      </div>
    );
  return (
    <form onSubmit={onSubmit} className="space-y-3">
      <NewPasswordFields value={password} onChange={setPassword} confirm={confirm} onConfirmChange={setConfirm} label="Nova senha" />
      <ErrorMessage message={error} />
      <Button className="w-full" disabled={busy}>
        {busy ? "Salvando..." : "Salvar nova senha"}
      </Button>
      {error?.includes("vencido") && (
        <Link href="/esqueci-senha" className="block text-center text-sm font-bold text-brand-rose">
          Pedir um novo link
        </Link>
      )}
    </form>
  );
}

export default function ResetPasswordPage() {
  return (
    <main className="bg-night flex min-h-screen items-center justify-center px-4">
      <Card className="w-full max-w-sm rounded-3xl p-7">
        <Link href="/" className="text-brand text-lg font-extrabold">
          Salão Max
        </Link>
        <h1 className="mb-3 mt-2 text-xl font-semibold">Criar nova senha</h1>
        <Suspense fallback={<p className="text-sm text-zinc-500">Carregando...</p>}>
          <ResetForm />
        </Suspense>
      </Card>
    </main>
  );
}
