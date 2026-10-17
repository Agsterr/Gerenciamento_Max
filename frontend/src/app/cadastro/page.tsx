"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button, Card, ErrorMessage, Field, NewPasswordFields } from "@/components/ui";
import { api } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import type { User } from "@/lib/types";

const toSlug = (name: string) =>
  name
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "")
    .slice(0, 60);

export default function RegisterPage() {
  const router = useRouter();
  const { signIn } = useAuth();
  const [salonName, setSalonName] = useState("");
  const [slug, setSlug] = useState("");
  const [slugTouched, setSlugTouched] = useState(false);
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
      const res = await api.post<{ token: string; user: User }>("/api/auth/register", {
        salonName,
        slug,
        ownerName: form.get("ownerName"),
        email: form.get("email"),
        password,
      });
      signIn(res.token, res.user);
      router.push("/painel/configuracoes");
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
        <h1 className="mb-4 mt-2 text-xl font-semibold">Cadastre seu salão</h1>
        <form onSubmit={onSubmit} className="space-y-3">
          <Field
            label="Nome do salão"
            required
            value={salonName}
            onChange={(e) => {
              setSalonName(e.target.value);
              if (!slugTouched) setSlug(toSlug(e.target.value));
            }}
          />
          <Field
            label="Endereço da sua página de agendamento"
            required
            pattern="[a-z0-9\\-]{3,60}"
            title="Letras minúsculas, números e hífen"
            value={slug}
            onChange={(e) => {
              setSlugTouched(true);
              setSlug(toSlug(e.target.value));
            }}
          />
          <p className="-mt-2 text-xs text-zinc-500">Seus clientes vão agendar em /s/{slug || "seu-salao"}</p>
          <Field label="Seu nome" name="ownerName" required />
          <Field label="E-mail" name="email" type="email" required autoComplete="email" />
          <NewPasswordFields value={password} onChange={setPassword} confirm={confirm} onConfirmChange={setConfirm} />
          <ErrorMessage message={error} />
          <Button className="w-full" disabled={busy}>
            {busy ? "Criando..." : "Criar salão"}
          </Button>
        </form>
      </Card>
    </main>
  );
}
