import { Navigate, Route, Routes } from "react-router-dom";
import { AuthProvider, useAuth } from "./AuthContext";
import Layout from "./components/Layout";
import Callback from "./pages/Callback";
import MyClaims from "./pages/MyClaims";
import NewClaim from "./pages/NewClaim";
import ClaimDetail from "./pages/ClaimDetail";
import ReviewQueue from "./pages/ReviewQueue";
import ClaimReview from "./pages/ClaimReview";
import ApprovedClaims from "./pages/ApprovedClaims";
import ExportHistory from "./pages/ExportHistory";
import Settings from "./pages/Settings";

// Role determines which screens/nav are shown at all — routes for the other
// two roles are never registered, on top of Layout only rendering that
// role's sidebar (per wireframes.dsl's per-role `sidebar` lines).
function RoleRoutes() {
  const { role } = useAuth();

  if (!role) {
    return (
      <div className="full-page-status">
        <p>Your account has no assigned role (employee, manager or finance).</p>
        <p>Contact an administrator to be added to the right group.</p>
      </div>
    );
  }

  return (
    <Routes>
      <Route element={<Layout role={role} />}>
        {role === "employee" && (
          <>
            <Route path="/" element={<Navigate to="/claims" replace />} />
            <Route path="/claims" element={<MyClaims />} />
            <Route path="/claims/new" element={<NewClaim />} />
            <Route path="/claims/:claimId" element={<ClaimDetail />} />
            <Route path="/claims/:claimId/edit" element={<NewClaim />} />
          </>
        )}
        {role === "manager" && (
          <>
            <Route path="/" element={<Navigate to="/review" replace />} />
            <Route path="/review" element={<ReviewQueue />} />
            <Route path="/review/:claimId" element={<ClaimReview />} />
          </>
        )}
        {role === "finance" && (
          <>
            <Route path="/" element={<Navigate to="/approved" replace />} />
            <Route path="/approved" element={<ApprovedClaims />} />
            <Route path="/exports" element={<ExportHistory />} />
          </>
        )}
        <Route path="/settings" element={<Settings />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  );
}

export default function App() {
  return (
    <Routes>
      {/* Outside AuthProvider: this route only completes the OIDC redirect. */}
      <Route path="/callback" element={<Callback />} />
      <Route
        path="/*"
        element={
          <AuthProvider>
            <RoleRoutes />
          </AuthProvider>
        }
      />
    </Routes>
  );
}
