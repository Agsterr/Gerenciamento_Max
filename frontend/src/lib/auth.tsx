"use client";

import { createContext, useCallback, useContext, useEffect, useState } from "react";
import { api, credStore, tokenStore } from "./api";
import type { User } from "./types";

type AuthState = {
  user: User | null;
  ready: boolean;
  signIn: (token: string, user: User) => void;
  signOut: () => void;
};

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (!tokenStore.get()) {
      setReady(true);
      return;
    }
    api
      .get<User>("/api/me")
      .then(setUser)
      .catch(() => tokenStore.clear())
      .finally(() => setReady(true));
  }, []);

  const signIn = useCallback((token: string, u: User) => {
    tokenStore.set(token);
    credStore.clear(); // nova sessão: a senha salva só vale se o login marcar "Manter conectado"
    setUser(u);
  }, []);

  const signOut = useCallback(() => {
    tokenStore.clear();
    credStore.clear();
    setUser(null);
  }, []);

  return <AuthContext.Provider value={{ user, ready, signIn, signOut }}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth fora do AuthProvider");
  return ctx;
}
