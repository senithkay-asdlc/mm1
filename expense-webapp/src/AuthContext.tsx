import {
  createContext,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import type { User } from "oidc-client-ts";
import { currentUser, getRoles, resolveRole, signIn, signOut, type Role } from "./auth";

type AuthState = {
  user: User;
  role: Role | null;
  signOut: () => Promise<void>;
};

const AuthContext = createContext<AuthState | null>(null);

// Gates all rendering on a signed-in session (component contract: "every
// screen requires a signed-in session — gate rendering on currentUser()").
// A `null` result means there is no session to renew, so we start an
// interactive sign-in redirect rather than rendering anything protected.
export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<"loading" | "authed" | "signing-in">("loading");
  const [user, setUser] = useState<User | null>(null);
  const [role, setRole] = useState<Role | null>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const u = await currentUser();
      if (cancelled) return;
      if (!u) {
        setState("signing-in");
        await signIn();
        return;
      }
      const groups = await getRoles();
      if (cancelled) return;
      setUser(u);
      setRole(resolveRole(groups));
      setState("authed");
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const value = useMemo<AuthState | null>(
    () => (user ? { user, role, signOut } : null),
    [user, role],
  );

  if (state === "loading" || state === "signing-in") {
    return <div className="full-page-status">Signing you in…</div>;
  }

  if (!value) {
    return <div className="full-page-status">Signing you in…</div>;
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth() called outside <AuthProvider>");
  return ctx;
}
