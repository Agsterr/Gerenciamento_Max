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

/** Link direto do APK mais recente (instalação fora da loja). */
export const appDownloadUrl = (app: "gestao" | "cliente") => `${BASE_URL}/api/app/download/latest?app=${app}`;

async function request<T>(method: string, path: string, body?: unknown): Promise<T> {
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
  if ((res.status === 401 || blocked) && token) {
    tokenStore.clear();
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
