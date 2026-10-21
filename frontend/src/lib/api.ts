const BASE_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8080";
const TOKEN_KEY = "salao.token";

/** Código do ProblemDetail quando o usuário ou o salão foi bloqueado pela plataforma. */
export const ACCOUNT_BLOCKED = "ACCOUNT_BLOCKED";

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string,
    public code?: string,
  ) {
    super(message);
  }
}

export const tokenStore = {
  get: () => (typeof window === "undefined" ? null : localStorage.getItem(TOKEN_KEY)),
  set: (token: string) => localStorage.setItem(TOKEN_KEY, token),
  clear: () => localStorage.removeItem(TOKEN_KEY),
};

/** "Manter conectado": e-mail e senha ficam neste aparelho para entrar de novo quando o token de 24h vencer. */
const CRED_KEY = "salao.cred";
export const credStore = {
  get: (): { email: string; password: string } | null => {
    try {
      const raw = typeof window === "undefined" ? null : localStorage.getItem(CRED_KEY);
      return raw ? JSON.parse(raw) : null;
    } catch {
      return null;
    }
  },
  set: (email: string, password: string) => localStorage.setItem(CRED_KEY, JSON.stringify({ email, password })),
  clear: () => localStorage.removeItem(CRED_KEY),
};

let relogin: Promise<boolean> | null = null;

/** Entra de novo com a senha salva (sem o token vencido). Várias requisições juntas compartilham um login só. */
function reauthenticate(): Promise<boolean> {
  const cred = credStore.get();
  if (!cred) return Promise.resolve(false);
  relogin ??= fetch(BASE_URL + "/api/auth/login", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(cred),
  })
    .then(async (res) => {
      if (res.ok) {
        tokenStore.set((await res.json()).token);
        return true;
      }
      if (res.status === 400 || res.status === 401 || res.status === 403) credStore.clear();
      return false;
    })
    .catch(() => false)
    .finally(() => {
      relogin = null;
    });
  return relogin;
}

/** Link direto do APK mais recente (instalação fora da loja). */
export const appDownloadUrl = (app: "gestao" | "cliente") => `${BASE_URL}/api/app/download/latest?app=${app}`;

async function request<T>(method: string, path: string, body?: unknown, retried = false): Promise<T> {
  const headers: Record<string, string> = {};
  const token = tokenStore.get();
  if (token && !path.startsWith("/api/public")) headers.Authorization = `Bearer ${token}`;
  const isForm = body instanceof FormData;
  if (body !== undefined && !isForm) headers["Content-Type"] = "application/json";

  const res = await fetch(BASE_URL + path, {
    method,
    headers,
    body: body === undefined ? undefined : isForm ? body : JSON.stringify(body),
  });

  const problem = res.ok ? null : await res.json().catch(() => null);
  const blocked = res.status === 403 && problem?.code === ACCOUNT_BLOCKED;
  if (res.status === 401 && token && !retried && (await reauthenticate())) {
    return request<T>(method, path, body, true);
  }
  if ((res.status === 401 || blocked) && token) {
    tokenStore.clear();
    credStore.clear();
    if (typeof window !== "undefined" && window.location.pathname.startsWith("/painel")) {
      window.location.href = "/login";
    }
  }
  if (!res.ok) {
    throw new ApiError(res.status, problem?.detail ?? problem?.message ?? `Erro ${res.status}`, problem?.code);
  }
  return res.status === 204 ? (undefined as T) : res.json();
}

export const api = {
  get: <T>(path: string) => request<T>("GET", path),
  post: <T>(path: string, body?: unknown) => request<T>("POST", path, body ?? {}),
  put: <T>(path: string, body: unknown) => request<T>("PUT", path, body),
  del: (path: string) => request<void>("DELETE", path),
  /** multipart/form-data (o navegador define o boundary). */
  upload: <T>(path: string, form: FormData) => request<T>("POST", path, form),
};
