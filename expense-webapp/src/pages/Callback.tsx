import { useEffect, useState } from "react";
import { handleCallback } from "../auth";

// Served at /callback — the exact redirect_uri computed in auth.ts and
// registered by the platform once this SPA's public URL resolves.
export default function Callback() {
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    handleCallback()
      .then(() => {
        window.location.assign(window.location.origin);
      })
      .catch((err: unknown) => {
        setError(err instanceof Error ? err.message : "Sign-in failed.");
      });
  }, []);

  if (error) {
    return (
      <div className="full-page-status">
        <p>Sign-in failed: {error}</p>
        <a href="/">Try again</a>
      </div>
    );
  }

  return <div className="full-page-status">Completing sign-in…</div>;
}
