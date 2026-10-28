"use client";

import { useParams, useRouter } from "next/navigation";
import { useEffect } from "react";

const REF_KEY = "salao.ref";

/** Link do representante (/r/CODIGO): guarda o código neste aparelho e leva para o cadastro do salão. */
export default function ReferralLink() {
  const { code } = useParams<{ code: string }>();
  const router = useRouter();

  useEffect(() => {
    const ref = String(code).toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 20);
    try {
      localStorage.setItem(REF_KEY, ref);
    } catch {
      // o código também vai na URL
    }
    router.replace(`/cadastro?ref=${ref}`);
  }, [code, router]);

  return <p className="p-8 text-center text-zinc-500">Abrindo...</p>;
}
