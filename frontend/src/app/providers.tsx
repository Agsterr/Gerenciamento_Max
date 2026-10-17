"use client";

import { useEffect } from "react";
import { AuthProvider } from "@/lib/auth";
import { setupPwa } from "@/lib/pwa";

export function Providers({ children }: { children: React.ReactNode }) {
  useEffect(setupPwa, []);
  return <AuthProvider>{children}</AuthProvider>;
}
