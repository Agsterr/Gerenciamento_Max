"use client";

import { useState } from "react";
import { LegalPage } from "@/components/LegalPage";
import { Button, ErrorMessage, Field, PasswordField } from "@/components/ui";
import { api, tokenStore } from "@/lib/api";
import { LEGAL } from "@/lib/legal";
import type { User } from "@/lib/types";

/**
 * Página web de exclusão de conta — o Google Play exige um link público para isso
 * (além da opção dentro do app).
 */
export default function DeleteAccountPage() {
  const [done, setDone] = useState<string>();
  const [error, setError] = useState<string>();
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const form = new FormData(e.currentTarget);
    const password = String(form.get("password"));
    if (!confirm("Esta ação é definitiva. Excluir a conta?")) return;
    setBusy(true);
    setError(undefined);
    try {
      const login = await api.post<{ token: string; user: User }>("/api/auth/login", {
        email: form.get("email"),
        password,
      });
      tokenStore.set(login.token);
      const res = await api.post<{ salonDeleted: boolean }>("/api/me/delete", { password });
      tokenStore.clear();
      setDone(res.salonDeleted ? "Conta e salão excluídos com todos os dados." : "Seu acesso foi excluído.");
    } catch (err) {
      tokenStore.clear();
      setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <LegalPage title="Excluir conta">
      <p>
        Informe o e-mail e a senha da conta do <strong>Salão Max Gestão</strong>. Se você for o último dono do salão,
        o salão e <strong>todos os dados</strong> (agenda, clientes, produtos, financeiro) serão apagados de forma
        definitiva e imediata. Usuários de equipe têm apenas o próprio acesso removido.
      </p>
      <p>
        Clientes que agendaram sem conta podem pedir a exclusão dos seus dados para o salão ou por {LEGAL.email}.
      </p>
      {done ? (
        <p className="rounded-lg bg-emerald-50 px-3 py-2 text-emerald-800">{done}</p>
      ) : (
        <form onSubmit={onSubmit} className="max-w-sm space-y-3">
          <Field label="E-mail" name="email" type="email" required />
          <PasswordField label="Senha" name="password" required />
          <ErrorMessage message={error} />
          <Button variant="danger" disabled={busy}>
            {busy ? "Excluindo..." : "Excluir minha conta"}
          </Button>
        </form>
      )}
    </LegalPage>
  );
}
