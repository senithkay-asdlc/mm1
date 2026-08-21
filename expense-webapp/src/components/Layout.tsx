import { NavLink, Outlet } from "react-router-dom";
import { useAuth } from "../AuthContext";
import type { Role } from "../auth";

type SidebarLink = { label: string; to: string };

// Mirrors the per-role `sidebar` line in wireframes.dsl exactly:
//   Employee -> "My Claims -> MyClaims | Settings"
//   Manager  -> "Review Queue -> ReviewQueue | Settings"
//   Finance  -> "Approved Claims -> ApprovedClaims | Export History -> ExportHistory | Settings"
const SIDEBAR_LINKS: Record<Role, SidebarLink[]> = {
  employee: [{ label: "My Claims", to: "/claims" }],
  manager: [{ label: "Review Queue", to: "/review" }],
  finance: [
    { label: "Approved Claims", to: "/approved" },
    { label: "Export History", to: "/exports" },
  ],
};

export default function Layout({ role }: { role: Role }) {
  const { user, signOut } = useAuth();
  const links = SIDEBAR_LINKS[role];

  return (
    <div className="app-shell">
      <header className="navbar">
        <span className="navbar-title">ExpenseClaims</span>
        <div className="navbar-user">
          <span>{user.profile.name ?? user.profile.email ?? user.profile.sub}</span>
          <button type="button" className="link-button" onClick={() => void signOut()}>
            Sign out
          </button>
        </div>
      </header>
      <div className="app-body">
        <nav className="sidebar">
          {links.map((link) => (
            <NavLink
              key={link.to}
              to={link.to}
              className={({ isActive }) => (isActive ? "sidebar-link active" : "sidebar-link")}
            >
              {link.label}
            </NavLink>
          ))}
          <NavLink
            to="/settings"
            className={({ isActive }) => (isActive ? "sidebar-link active" : "sidebar-link")}
          >
            Settings
          </NavLink>
        </nav>
        <main className="content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
