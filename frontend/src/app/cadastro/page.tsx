"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { Button, Card, ErrorMessage, Field, NewPasswordFields } from "@/components/ui";
import { api } from "@/lib/api";
import { subscribeLink } from "@/components/PlanBanner";
import { useAuth } from "@/lib/auth";
import { useApi } from "@/lib/useApi";
import type { TrialTerms, User } from "@/lib/types";

export const REF_KEY = "salao.ref";

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
  // código do representante: vem do link /r/CODIGO (?ref=) ou fica guardado do último link aberto neste aparelho
  const [ref, setRef] = useState("");
  useEffect(() => {
    try {
      const fromUrl = new URLSearchParams(window.location.search).get("ref");
      setRef((fromUrl || localStorage.getItem(REF_KEY) || "").toUpperCase());
    } catch {
      // sem armazenamento: segue sem indicação
    }
  }, []);
  const { data: referral } = useApi<{ valid: boolean; name: string | null }>(ref ? `/api/public/referral/${encodeURIComponent(ref)}` : null);

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
        referralCode: referral?.valid ? ref : undefined,
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
        <h1 className="mt-2 text-xl font-semibold">Cadastre seu salão</h1>
        {referral?.valid && (
          <p className="mt-2 rounded-xl bg-[#FFF1F6] px-3 py-2 text-sm font-semibold text-brand-rose">Indicado por {referral.name}</p>
        )}
        <TrialTermsBox />
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

/** Deixa claro antes do cadastro: é um teste grátis com prazo e limites; para continuar, fala-se com a gente. */
function TrialTermsBox() {
  const { data: t } = useApi<TrialTerms>("/api/public/plan");
  if (!t) return <div className="mb-4" />;
  const link = subscribeLink(t);
  return (
    <div className="mb-4 mt-3 rounded-2xl bg-amber-50 p-4 text-sm text-amber-900 ring-1 ring-amber-200">
      <p className="font-extrabold">Teste grátis por {t.trialDays} dias, sem cartão</p>
      <p className="mt-1">
        No teste: até {t.maxProfessionals} profissionais, {t.maxServices} serviços e {t.maxCustomers} clientes. Depois do prazo
        você continua vendo seus dados, mas para seguir usando é preciso ativar o plano com a gente.
      </p>
      {link && (
        <a href={link} target="_blank" rel="noreferrer" className="mt-2 inline-block font-extrabold text-brand-rose underline">
          Já quero o plano completo — falar com o Salão Max
        </a>
      )}
    </div>
  );
}
