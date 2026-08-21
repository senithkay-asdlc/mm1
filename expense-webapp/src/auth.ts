import { UserManager, WebStorageStateStore, type User } from "oidc-client-ts";
import { env } from "./env";

export const userManager = new UserManager({
  authority: env.USER_AUTH_ISSUER,
  client_id: env.USER_AUTH_CLIENT_ID,
  redirect_uri: window.location.origin + "/callback",
  post_logout_redirect_uri: window.location.origin,
  response_type: "code",
  scope: env.USER_AUTH_SCOPES,
  // The token lives in JS-readable storage — acceptable for a public SPA;
  // keep loadUserInfo:false and lean on the platform CSP.
  userStore: new WebStorageStateStore({ store: window.localStorage }),
  automaticSilentRenew: true,
  loadUserInfo: false,
});

export async function signIn() {
  await userManager.signinRedirect();
}

export async function handleCallback() {
  return userManager.signinRedirectCallback();
}

// No end_session_endpoint → signoutRedirect() rejects; drop the LOCAL session
// instead and let the load-time guard start a fresh sign-in.
export async function signOut() {
  try {
    await userManager.signoutRedirect();
  } catch {
    await userManager.removeUser();
    window.location.assign("/");
  }
}

// null ONLY when there is no session to renew — an expired one renews silently.
export async function currentUser(): Promise<User | null> {
  const user = await userManager.getUser();
  if (user && !user.expired) return user;
  try {
    return await userManager.signinSilent();
  } catch {
    return null;
  }
}

export async function getAccessToken(): Promise<string | null> {
  const user = await currentUser();
  return user?.access_token ?? null;
}

export type Role = "employee" | "manager" | "finance";

const ROLE_KEYWORDS: Record<Role, string> = {
  employee: "employee",
  manager: "manager",
  finance: "finance",
};

export async function getRoles(): Promise<string[]> {
  const user = await currentUser();
  const groups = user?.profile?.groups;
  return Array.isArray(groups) ? (groups as string[]) : [];
}

// Resolve the caller's single role by keyword-matching their groups against
// the role model in specs/design/security.md (employee|manager|finance).
// A substring match survives the org renaming its groups.
export function resolveRole(groups: string[]): Role | null {
  const lowered = groups.map((g) => g.toLowerCase());
  for (const role of Object.keys(ROLE_KEYWORDS) as Role[]) {
    if (lowered.some((g) => g.includes(ROLE_KEYWORDS[role]))) return role;
  }
  return null;
}
