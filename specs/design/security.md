# Security design

## Roles → permissions

No role may act on another role's surface: an employee cannot approve claims
(including their own), and a manager cannot approve claims from employees who
do not report to them. Finance can view claims but never edits their content,
only their export/exported state.

## Authentication (Thunder)

- Both `expense-webapp` and `expense-api` declare the same `thunder-app`
dependency, named `user-auth`, so sign-in and API calls share one OIDC
client.
- Scopes: `openid profile email` (default).
- `expense-webapp` performs OIDC + PKCE sign-in in the browser; `expense-api`
sits behind the gateway, which validates the token and injects the caller's
identity as `X-User-Id` on every request.
- No component is unauthenticated: every screen and every `expense-api`
operation requires a signed-in session.

## Role resolution

`expense-api` resolves the caller's role by looking up `X-User-Id` against
the `USER` record in `expense-db`, which carries `role`
(`employee|manager|finance`) and, for employees, their `managerId`. A caller
whose id resolves to no user record, or whose role does not permit the
requested operation (e.g. an employee calling `/approve`), is denied with
`403`.