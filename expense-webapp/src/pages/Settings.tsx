import { useAuth } from "../AuthContext";

// Referenced by every role's sidebar in wireframes.dsl ("| Settings") but not
// spec'd as its own screen — a minimal account panel with the sign-out action
// every SPA session needs somewhere.
export default function Settings() {
  const { user, role, signOut } = useAuth();

  return (
    <div>
      <h1>Settings</h1>
      <div className="settings-panel">
        <p>
          <strong>Name:</strong> {user.profile.name ?? "—"}
        </p>
        <p>
          <strong>Email:</strong> {user.profile.email ?? "—"}
        </p>
        <p>
          <strong>Role:</strong> {role ?? "unassigned"}
        </p>
        <button type="button" className="btn" onClick={() => void signOut()}>
          Sign out
        </button>
      </div>
    </div>
  );
}
