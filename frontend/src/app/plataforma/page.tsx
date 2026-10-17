"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { Badge, Button, Card, Empty, ErrorMessage, Field, Modal, PageHeader, PasswordField, Select } from "@/components/ui";
import { api, appDownloadUrl } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { formatDate, formatDateTime, isoDate } from "@/lib/format";
import type { AppRelease, MobileApp, PlatformSalon, PlatformUser, TrialTerms, User } from "@/lib/types";
import { useApi } from "@/lib/useApi";

const APPS: { id: MobileApp; label: string }[] = [
  { id: "gestao", label: "Salão Max Gestão (salão)" },
  { id: "cliente", label: "Salão Max (clientes)" },
];

/** Administração da plataforma: bloqueio de salões/usuários e versões dos apps fora da loja. */
export default function PlatformPage() {
  const { user, ready, signOut } = useAuth();
  const [tab, setTab] = useState<"salons" | "trial" | "apps">("salons");

  if (!ready) return <p className="p-8 text-center text-zinc-500">Carregando...</p>;
  if (user?.role !== "PLATFORM_ADMIN") return <PlatformLogin loggedAsSalon={!!user} />;

  return (
    <div className="min-h-screen">
      <header className="border-b border-zinc-200 bg-white">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-3 px-4 py-3">
          <Link href="/plataforma" className="flex items-center gap-2 text-lg font-extrabold">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src="/icon-gestao.png" alt="" className="h-8 w-8 rounded-lg" />
            <span className="text-brand">Salão Max</span>
            <span className="text-sm font-bold text-brand-muted">Plataforma</span>
          </Link>
          <nav className="flex gap-1">
            {(
              [
                ["salons", "Salões"],
                ["trial", "Teste grátis"],
                ["apps", "Apps"],
              ] as const
            ).map(([id, label]) => (
              <button
                key={id}
                onClick={() => setTab(id)}
                className={`rounded-xl px-3 py-2 text-sm font-bold ${
                  tab === id ? "bg-brand text-white shadow-glow" : "text-brand-muted hover:bg-[#FFF1F6]"
                }`}
              >
                {label}
              </button>
            ))}
          </nav>
          <div className="flex items-center gap-3 text-sm">
            <span className="hidden text-zinc-600 sm:inline">{user.email}</span>
            <button onClick={signOut} className="text-zinc-500 hover:text-brand-rose">
              Sair
            </button>
          </div>
        </div>
      </header>
      <main className="mx-auto w-full max-w-6xl p-4 md:p-8">{tab === "salons" ? <SalonsTab /> : tab === "trial" ? <TrialTab /> : <AppsTab />}</main>
    </div>
  );
}

function PlatformLogin({ loggedAsSalon }: { loggedAsSalon: boolean }) {
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
      if (res.user.role !== "PLATFORM_ADMIN") {
        setError("Esta conta não é de administrador da plataforma. Use o login do painel do salão.");
        return;
      }
      signIn(res.token, res.user);
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
        <h1 className="mb-4 mt-2 text-xl font-semibold">Administração da plataforma</h1>
        {loggedAsSalon && (
          <p className="mb-3 rounded-lg bg-amber-50 px-3 py-2 text-sm text-amber-800">
            Você está logado como usuário de salão. Entre com a conta da plataforma.
          </p>
        )}
        <form onSubmit={onSubmit} className="space-y-3">
          <Field label="E-mail" name="email" type="email" required autoComplete="username" />
          <PasswordField label="Senha" name="password" required autoComplete="current-password" />
          <ErrorMessage message={error} />
          <Button className="w-full" disabled={busy}>
            {busy ? "Entrando..." : "Entrar"}
          </Button>
        </form>
      </Card>
    </main>
  );
}

// ---------------- Salões ----------------

type BlockTarget = { kind: "salon" | "user"; id: number; name: string };

function SalonsTab() {
  const [query, setQuery] = useState("");
  const [search, setSearch] = useState("");
  const { data: salons, error, loading, reload } = useApi<PlatformSalon[]>(
    `/api/platform/salons?q=${encodeURIComponent(search)}`,
  );
  const [openSalon, setOpenSalon] = useState<number | null>(null);
  const [target, setTarget] = useState<BlockTarget | null>(null);
  const [actionError, setActionError] = useState<string>();
  const [usersVersion, setUsersVersion] = useState(0);
  const [planFor, setPlanFor] = useState<PlatformSalon | null>(null);

  async function unblock(kind: BlockTarget["kind"], id: number) {
    setActionError(undefined);
    try {
      await api.post(`/api/platform/${kind === "salon" ? "salons" : "users"}/${id}/unblock`);
      reload();
      setUsersVersion((v) => v + 1);
    } catch (err) {
      setActionError((err as Error).message);
    }
  }

  return (
    <>
      <PageHeader title="Salões">
        <form
          onSubmit={(e) => {
            e.preventDefault();
            setSearch(query.trim());
          }}
          className="flex gap-2"
        >
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Buscar por nome ou link"
            className="w-56 rounded-xl border border-[#F1E3EB] bg-white px-3 py-2 text-sm outline-none focus:border-brand-rose"
          />
          <Button variant="secondary">Buscar</Button>
        </form>
      </PageHeader>
      <ErrorMessage message={error ?? actionError} />
      {loading && !salons && <p className="text-zinc-500">Carregando...</p>}
      {salons && salons.length === 0 && <Empty>Nenhum salão encontrado.</Empty>}
      <div className="space-y-3">
        {salons?.map((s) => (
          <Card key={s.id}>
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div>
                <p className="font-extrabold text-brand-ink">
                  {s.name}{" "}
                  {s.blocked ? (
                    <Badge className="bg-rose-100 text-brand-rose">Bloqueado</Badge>
                  ) : (
                    <PlanBadge salon={s} />
                  )}
                </p>
                <p className="text-sm text-zinc-500">
                  /s/{s.slug} · {s.userCount} {s.userCount === 1 ? "usuário" : "usuários"}
                  {s.createdAt && ` · desde ${formatDate(s.createdAt)}`}
                  {s.phone && ` · ${s.phone}`}
                </p>
                {s.blocked && (
                  <p className="mt-1 text-sm text-brand-rose">
                    Motivo: {s.blockedReason}
                    {s.blockedAt && <span className="text-zinc-400"> ({formatDateTime(s.blockedAt)})</span>}
                  </p>
                )}
              </div>
              <div className="flex flex-wrap gap-2">
                <Button variant="secondary" size="sm" onClick={() => setPlanFor(s)}>
                  Plano
                </Button>
                <Button variant="ghost" size="sm" onClick={() => setOpenSalon(openSalon === s.id ? null : s.id)}>
                  {openSalon === s.id ? "Ocultar usuários" : "Usuários"}
                </Button>
                {s.blocked ? (
                  <Button variant="secondary" size="sm" onClick={() => unblock("salon", s.id)}>
                    Desbloquear
                  </Button>
                ) : (
                  <Button variant="danger" size="sm" onClick={() => setTarget({ kind: "salon", id: s.id, name: s.name })}>
                    Bloquear
                  </Button>
                )}
              </div>
            </div>
            {openSalon === s.id && (
              <SalonUsers
                key={usersVersion}
                salonId={s.id}
                onBlock={(u) => setTarget({ kind: "user", id: u.id, name: u.name })}
                onUnblock={(u) => unblock("user", u.id)}
              />
            )}
          </Card>
        ))}
      </div>
      <PlanModal
        salon={planFor}
        onClose={() => setPlanFor(null)}
        onDone={() => {
          setPlanFor(null);
          reload();
        }}
      />
      <BlockModal
        target={target}
        onClose={() => setTarget(null)}
        onDone={() => {
          setTarget(null);
          reload();
          setUsersVersion((v) => v + 1);
        }}
      />
    </>
  );
}

function SalonUsers({
  salonId,
  onBlock,
  onUnblock,
}: {
  salonId: number;
  onBlock: (u: PlatformUser) => void;
  onUnblock: (u: PlatformUser) => void;
}) {
  const { data: users, error } = useApi<PlatformUser[]>(`/api/platform/salons/${salonId}/users`);
  return (
    <div className="mt-3 border-t border-zinc-100 pt-3">
      <ErrorMessage message={error} />
      {users?.length === 0 && <p className="text-sm text-zinc-500">Nenhum usuário.</p>}
      <ul className="divide-y divide-zinc-100 text-sm">
        {users?.map((u) => (
          <li key={u.id} className="flex flex-wrap items-center justify-between gap-2 py-2">
            <div>
              <span className="font-semibold">{u.name}</span> <span className="text-zinc-400">{u.email}</span>{" "}
              <span className="text-zinc-500">· {u.role === "OWNER" ? "Dono" : "Funcionário"}</span>
              {!u.active && <span className="text-zinc-400"> · inativo</span>}
              {u.blocked && <p className="text-brand-rose">Bloqueado: {u.blockedReason}</p>}
            </div>
            {u.blocked ? (
              <Button variant="secondary" size="sm" onClick={() => onUnblock(u)}>
                Desbloquear
              </Button>
            ) : (
              <Button variant="danger" size="sm" onClick={() => onBlock(u)}>
                Bloquear
              </Button>
            )}
          </li>
        ))}
      </ul>
    </div>
  );
}

function BlockModal({ target, onClose, onDone }: { target: BlockTarget | null; onClose: () => void; onDone: () => void }) {
  const [error, setError] = useState<string>();
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!target) return;
    const reason = String(new FormData(e.currentTarget).get("reason") ?? "");
    setBusy(true);
    setError(undefined);
    try {
      await api.post(`/api/platform/${target.kind === "salon" ? "salons" : "users"}/${target.id}/block`, { reason });
      onDone();
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal title={target ? `Bloquear ${target.name}` : ""} open={!!target} onClose={onClose}>
      <form onSubmit={submit} className="space-y-3">
        <p className="text-sm text-zinc-600">
          {target?.kind === "salon"
            ? "Todos os usuários do salão perdem o acesso na hora e a página pública sai do ar."
            : "O usuário perde o acesso na hora, inclusive nos apps já abertos."}{" "}
          O motivo aparece para quem foi bloqueado.
        </p>
        <Field label="Motivo" name="reason" required maxLength={300} placeholder="Ex.: mensalidade em atraso" />
        <ErrorMessage message={error} />
        <div className="flex justify-end gap-2">
          <Button type="button" variant="ghost" onClick={onClose}>
            Cancelar
          </Button>
          <Button disabled={busy}>{busy ? "Bloqueando..." : "Bloquear"}</Button>
        </div>
      </form>
    </Modal>
  );
}

// ---------------- Apps ----------------

function AppsTab() {
  const { data: releases, error, reload } = useApi<AppRelease[]>("/api/platform/releases");
  const [actionError, setActionError] = useState<string>();

  async function toggleForce(r: AppRelease) {
    setActionError(undefined);
    try {
      await api.put(`/api/platform/releases/${r.id}/force-update`, { forceUpdate: !r.forceUpdate });
      reload();
    } catch (err) {
      setActionError((err as Error).message);
    }
  }

  return (
    <>
      <PageHeader title="Apps fora da loja" />
      <p className="-mt-2 mb-4 text-sm text-zinc-600">
        APKs publicados pelo GitHub Actions ou enviados aqui. Os apps instalados por fora da loja avisam quando há versão nova;
        com <strong>atualização obrigatória</strong> ligada, só voltam a funcionar depois de atualizar.
      </p>
      <ErrorMessage message={error ?? actionError} />
      <div className="grid gap-4 lg:grid-cols-2">
        {APPS.map((app) => {
          const list = releases?.filter((r) => r.app === app.id) ?? [];
          return (
            <Card key={app.id}>
              <div className="mb-3 flex items-center justify-between gap-2">
                <h2 className="font-extrabold">{app.label}</h2>
                <a href={appDownloadUrl(app.id)} className="text-sm font-bold text-brand-rose hover:underline">
                  Baixar última
                </a>
              </div>
              {releases && list.length === 0 && <p className="text-sm text-zinc-500">Nenhuma versão publicada.</p>}
              <ul className="divide-y divide-zinc-100 text-sm">
                {list.map((r, i) => (
                  <li key={r.id} className="py-2">
                    <div className="flex flex-wrap items-center justify-between gap-2">
                      <span>
                        <span className="font-bold">
                          {r.versionName} ({r.versionCode})
                        </span>{" "}
                        {i === 0 && <Badge className="bg-emerald-100 text-emerald-700">Atual</Badge>}{" "}
                        {r.forceUpdate && <Badge className="bg-rose-100 text-brand-rose">Obrigatória</Badge>}
                      </span>
                      <Button variant={r.forceUpdate ? "secondary" : "danger"} size="sm" onClick={() => toggleForce(r)}>
                        {r.forceUpdate ? "Tornar opcional" : "Tornar obrigatória"}
                      </Button>
                    </div>
                    <p className="text-zinc-500">
                      {formatDateTime(r.createdAt)} · {(r.fileSizeBytes / 1024 / 1024).toFixed(1)} MB ·{" "}
                      <a href={r.downloadUrl} className="hover:underline">
                        baixar
                      </a>
                    </p>
                    {r.releaseNotes && <p className="text-zinc-600">{r.releaseNotes}</p>}
                  </li>
                ))}
              </ul>
            </Card>
          );
        })}
      </div>
      <UploadCard onDone={reload} />
    </>
  );
}

function UploadCard({ onDone }: { onDone: () => void }) {
  const [error, setError] = useState<string>();
  const [message, setMessage] = useState<string>();
  const [busy, setBusy] = useState(false);

  async function submit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const formEl = e.currentTarget;
    const form = new FormData(formEl);
    form.set("forceUpdate", form.get("forceUpdate") ? "true" : "false");
    setBusy(true);
    setError(undefined);
    setMessage(undefined);
    try {
      const r = await api.upload<AppRelease>("/api/platform/releases", form);
      setMessage(`Versão ${r.versionName} (${r.versionCode}) publicada.`);
      formEl.reset();
      onDone();
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card className="mt-4">
      <h2 className="mb-3 font-extrabold">Enviar APK manualmente</h2>
      <form onSubmit={submit} className="grid gap-3 sm:grid-cols-2">
        <Select label="App" name="app" defaultValue="gestao">
          {APPS.map((a) => (
            <option key={a.id} value={a.id}>
              {a.label}
            </option>
          ))}
        </Select>
        <Field label="Arquivo .apk" name="file" type="file" accept=".apk" required />
        <Field label="Versão (versionName)" name="versionName" required placeholder="1.2.0" maxLength={32} />
        <Field label="Build (versionCode)" name="versionCode" type="number" min={1} required placeholder="12" />
        <Field label="Novidades" name="releaseNotes" className="sm:col-span-2" maxLength={2000} />
        <label className="flex items-center gap-2 text-sm sm:col-span-2">
          <input type="checkbox" name="forceUpdate" className="h-4 w-4 accent-brand-rose" /> Atualização obrigatória
        </label>
        <div className="space-y-2 sm:col-span-2">
          <ErrorMessage message={error} />
          {message && <p className="text-sm text-emerald-700">{message}</p>}
          <Button disabled={busy}>{busy ? "Enviando..." : "Publicar versão"}</Button>
        </div>
      </form>
    </Card>
  );
}

function PlanBadge({ salon: s }: { salon: PlatformSalon }) {
  if (s.planStatus === "ACTIVE")
    return (
      <Badge className="bg-emerald-100 text-emerald-700">Pago{s.paidUntil ? ` até ${formatDate(s.paidUntil)}` : ""}</Badge>
    );
  if (s.planStatus === "TRIAL") return <Badge className="bg-amber-100 text-amber-800">Teste até {formatDate(s.trialEndsAt)}</Badge>;
  return <Badge className="bg-rose-100 text-brand-rose">{s.plan === "PAID" ? "Plano vencido" : "Teste vencido"}</Badge>;
}

/** Ativar o plano pago (com ou sem vencimento) ou dar/estender o teste grátis. */
function PlanModal({ salon, onClose, onDone }: { salon: PlatformSalon | null; onClose: () => void; onDone: () => void }) {
  const [mode, setMode] = useState<"PAID" | "TRIAL">("PAID");
  const [paidUntil, setPaidUntil] = useState("");
  const [trialEnds, setTrialEnds] = useState("");
  const [error, setError] = useState<string>();
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!salon) return;
    setMode(salon.plan);
    setPaidUntil(salon.paidUntil ?? "");
    const base = new Date(Math.max(Date.now(), new Date(salon.trialEndsAt).getTime()));
    base.setDate(base.getDate() + 7);
    setTrialEnds(isoDate(base));
    setError(undefined);
  }, [salon]);

  async function save() {
    if (!salon) return;
    setBusy(true);
    setError(undefined);
    try {
      await api.post(`/api/platform/salons/${salon.id}/plan`, {
        plan: mode,
        paidUntil: mode === "PAID" && paidUntil ? paidUntil : null,
        trialEndsAt: mode === "TRIAL" ? `${trialEnds}T23:59:00` : null,
      });
      onDone();
    } catch (e) {
      setError((e as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <Modal title={`Plano · ${salon?.name ?? ""}`} open={!!salon} onClose={onClose}>
      <div className="space-y-4">
        <div className="inline-flex rounded-xl border border-zinc-300 p-0.5 text-sm">
          {(
            [
              ["PAID", "Pago"],
              ["TRIAL", "Teste grátis"],
            ] as const
          ).map(([value, label]) => (
            <button
              key={value}
              type="button"
              onClick={() => setMode(value)}
              className={`rounded-lg px-4 py-1.5 font-bold ${mode === value ? "bg-brand text-white" : "text-zinc-600"}`}
            >
              {label}
            </button>
          ))}
        </div>
        {mode === "PAID" ? (
          <>
            <Field label="Pago até (deixe vazio para sem vencimento)" type="date" value={paidUntil} onChange={(e) => setPaidUntil(e.target.value)} />
            <p className="text-sm text-zinc-500">Sem limites de cadastro. Depois da data, o salão fica só para consulta até você renovar.</p>
          </>
        ) : (
          <>
            <Field label="Teste vai até" type="date" required value={trialEnds} onChange={(e) => setTrialEnds(e.target.value)} />
            <p className="text-sm text-zinc-500">Com os limites do teste grátis (aba “Teste grátis”).</p>
          </>
        )}
        <ErrorMessage message={error} />
        <Button className="w-full" onClick={save} disabled={busy || (mode === "TRIAL" && !trialEnds)}>
          {busy ? "Salvando..." : "Salvar"}
        </Button>
      </div>
    </Modal>
  );
}

/** Prazo, limites do teste grátis e contato que aparece para quem quer assinar. */
function TrialTab() {
  const { data, error, reload } = useApi<TrialTerms>("/api/platform/settings");
  const [form, setForm] = useState<TrialTerms | null>(null);
  const [message, setMessage] = useState<string>();
  const [saveError, setSaveError] = useState<string>();

  useEffect(() => {
    if (data) setForm(data);
  }, [data]);

  if (!form) return <ErrorMessage message={error} />;
  const num = (key: keyof TrialTerms) => (e: React.ChangeEvent<HTMLInputElement>) => setForm({ ...form, [key]: Number(e.target.value) });

  async function save(e: React.FormEvent) {
    e.preventDefault();
    setMessage(undefined);
    setSaveError(undefined);
    try {
      await api.put("/api/platform/settings", form);
      setMessage("Salvo! Vale para os próximos cadastros e para os limites de quem está em teste.");
      reload();
    } catch (err) {
      setSaveError((err as Error).message);
    }
  }

  return (
    <>
      <PageHeader title="Teste grátis" />
      <Card className="max-w-xl">
        <form onSubmit={save} className="space-y-3">
          <p className="text-sm text-zinc-600">
            Todo salão novo começa em teste. Quando o prazo acaba, ele só consulta os dados (não cria, não altera e o agendamento
            online pausa) até você ativar o plano em <strong>Salões → Plano</strong>.
          </p>
          <Field label="Dias de teste" type="number" min={1} max={365} required value={form.trialDays} onChange={num("trialDays")} />
          <div className="grid gap-3 sm:grid-cols-3">
            <Field label="Máx. profissionais" type="number" min={1} required value={form.maxProfessionals} onChange={num("maxProfessionals")} />
            <Field label="Máx. serviços" type="number" min={1} required value={form.maxServices} onChange={num("maxServices")} />
            <Field label="Máx. clientes" type="number" min={1} required value={form.maxCustomers} onChange={num("maxCustomers")} />
          </div>
          <Field
            label="Seu WhatsApp para quem quer assinar"
            inputMode="tel"
            placeholder="(11) 99999-9999"
            value={form.contactWhatsapp}
            onChange={(e) => setForm({ ...form, contactWhatsapp: e.target.value })}
          />
          <Field
            label="Ou e-mail de contato"
            type="email"
            value={form.contactEmail}
            onChange={(e) => setForm({ ...form, contactEmail: e.target.value })}
          />
          <ErrorMessage message={saveError} />
          {message && <p className="text-sm text-emerald-700">{message}</p>}
          <Button>Salvar</Button>
        </form>
      </Card>
    </>
  );
}
