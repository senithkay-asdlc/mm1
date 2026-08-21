import createClient from "openapi-fetch";
import type { components, paths } from "./generated/expense-api";
import { getAccessToken, signIn } from "./auth";

// Same-origin — nginx reverse-proxies /api to the expense-api sibling
// (see nginx/default.conf + nginx/15-aep-api-proxy.sh). Never the public
// gateway URL, never window._env_.
const client = createClient<paths>({ baseUrl: "/api" });

export type ExpenseClaim = components["schemas"]["ExpenseClaim"];
export type ExpenseClaimInput = components["schemas"]["ExpenseClaimInput"];
export type PayrollExport = components["schemas"]["PayrollExport"];
export type ClaimStatus = ExpenseClaim["status"];

// `X-User-Id` is a REQUIRED header on every operation per expense-api's
// openapi.yaml, but per api-management/thunder-authentication it is
// gateway-injected from the validated bearer token — the gateway sets it
// (overwriting anything a client sends) and a client never computes it.
// This placeholder only exists to satisfy the generated type; its value is
// never read by the backend.
const GATEWAY_INJECTED_USER_ID = "gateway-injected";

async function authHeaders(): Promise<{
  Authorization?: string;
  "X-User-Id": string;
}> {
  const token = await getAccessToken();
  return {
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
    "X-User-Id": GATEWAY_INJECTED_USER_ID,
  };
}

// Any 401 means the gateway rejected/expired the caller's token in a way
// silent renewal could not fix — fall back to a full interactive sign-in.
async function guard401(status: number) {
  if (status === 401) await signIn();
}

export async function listExpenseClaims(query?: {
  status?: ClaimStatus;
  employeeId?: string;
  limit?: number;
  offset?: number;
}): Promise<ExpenseClaim[]> {
  const { data, response } = await client.GET("/expense-claims", {
    params: { header: await authHeaders(), query },
  });
  await guard401(response.status);
  return data?.data ?? [];
}

export async function getExpenseClaim(claimId: string): Promise<ExpenseClaim | null> {
  const { data, response } = await client.GET("/expense-claims/{claimId}", {
    params: { header: await authHeaders(), path: { claimId } },
  });
  await guard401(response.status);
  return data ?? null;
}

export async function submitExpenseClaim(
  input: ExpenseClaimInput,
): Promise<ExpenseClaim | null> {
  const { data, response } = await client.POST("/expense-claims", {
    params: { header: await authHeaders() },
    body: input,
  });
  await guard401(response.status);
  return data ?? null;
}

export async function updateExpenseClaim(
  claimId: string,
  input: ExpenseClaimInput,
): Promise<ExpenseClaim | null> {
  const { data, response } = await client.PUT("/expense-claims/{claimId}", {
    params: { header: await authHeaders(), path: { claimId } },
    body: input,
  });
  await guard401(response.status);
  return data ?? null;
}

export async function uploadExpenseClaimReceipt(
  claimId: string,
  file: File,
): Promise<ExpenseClaim | null> {
  const form = new FormData();
  form.append("file", file);
  const { data, response } = await client.POST("/expense-claims/{claimId}/receipt", {
    params: { header: await authHeaders(), path: { claimId } },
    // openapi-fetch passes a FormData body through untouched (no JSON.stringify),
    // letting the browser set the multipart boundary.
    body: form as unknown as { file: string },
  });
  await guard401(response.status);
  return data ?? null;
}

export async function resubmitExpenseClaim(claimId: string): Promise<ExpenseClaim | null> {
  const { data, response } = await client.POST("/expense-claims/{claimId}/resubmit", {
    params: { header: await authHeaders(), path: { claimId } },
  });
  await guard401(response.status);
  return data ?? null;
}

export async function approveExpenseClaim(claimId: string): Promise<ExpenseClaim | null> {
  const { data, response } = await client.POST("/expense-claims/{claimId}/approve", {
    params: { header: await authHeaders(), path: { claimId } },
  });
  await guard401(response.status);
  return data ?? null;
}

export async function rejectExpenseClaim(
  claimId: string,
  reason: string,
): Promise<ExpenseClaim | null> {
  const { data, response } = await client.POST("/expense-claims/{claimId}/reject", {
    params: { header: await authHeaders(), path: { claimId } },
    body: { reason },
  });
  await guard401(response.status);
  return data ?? null;
}

export async function listPayrollExports(query?: {
  limit?: number;
  offset?: number;
}): Promise<PayrollExport[]> {
  const { data, response } = await client.GET("/payroll-exports", {
    params: { header: await authHeaders(), query },
  });
  await guard401(response.status);
  return data?.data ?? [];
}

export async function createPayrollExport(): Promise<PayrollExport | null> {
  const { data, response } = await client.POST("/payroll-exports", {
    params: { header: await authHeaders() },
  });
  await guard401(response.status);
  return data ?? null;
}

export async function downloadPayrollExportCsv(exportId: string): Promise<string> {
  const { data, response } = await client.GET("/payroll-exports/{exportId}/download", {
    params: { header: await authHeaders(), path: { exportId } },
    parseAs: "text",
  });
  await guard401(response.status);
  return data ?? "";
}
