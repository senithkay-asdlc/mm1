import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { listExpenseClaims, type ClaimStatus, type ExpenseClaim } from "../api";
import { formatCurrency, formatDateTime } from "../format";
import StatusBadge from "../components/StatusBadge";
import SummaryCard from "../components/SummaryCard";

type Tab = "All" | "Pending" | "Approved" | "Rejected";

const TAB_STATUS: Record<Exclude<Tab, "All">, ClaimStatus> = {
  Pending: "submitted",
  Approved: "approved",
  Rejected: "rejected",
};

export default function MyClaims() {
  const navigate = useNavigate();
  const [claims, setClaims] = useState<ExpenseClaim[]>([]);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<Tab>("All");

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    // The API scopes this to the caller's own claims server-side.
    listExpenseClaims().then((data) => {
      if (!cancelled) {
        setClaims(data);
        setLoading(false);
      }
    });
    return () => {
      cancelled = true;
    };
  }, []);

  const counts = useMemo(
    () => ({
      pending: claims.filter((c) => c.status === "submitted").length,
      approved: claims.filter((c) => c.status === "approved").length,
      rejected: claims.filter((c) => c.status === "rejected").length,
    }),
    [claims],
  );

  const visible = useMemo(() => {
    if (tab === "All") return claims;
    return claims.filter((c) => c.status === TAB_STATUS[tab]);
  }, [claims, tab]);

  return (
    <div>
      <div className="row row-header">
        <h1>My Claims</h1>
        <div className="spacer" />
        <button type="button" className="btn btn-primary" onClick={() => navigate("/claims/new")}>
          New claim
        </button>
      </div>

      <div className="row summary-row">
        <SummaryCard label="Pending" value={counts.pending} hint="awaiting manager review" />
        <SummaryCard label="Approved" value={counts.approved} hint="ready for payroll" />
        <SummaryCard label="Rejected" value={counts.rejected} hint="needs your edits" />
      </div>

      <div className="tabs">
        {(["All", "Pending", "Approved", "Rejected"] as Tab[]).map((t) => (
          <button
            key={t}
            type="button"
            className={t === tab ? "tab active" : "tab"}
            onClick={() => setTab(t)}
          >
            {t}
          </button>
        ))}
      </div>

      {loading ? (
        <p>Loading…</p>
      ) : visible.length === 0 ? (
        <p className="empty-state">No claims here yet.</p>
      ) : (
        <table className="data-table">
          <thead>
            <tr>
              <th>Expense</th>
              <th>Category</th>
              <th>Amount</th>
              <th>Status</th>
              <th>Updated</th>
            </tr>
          </thead>
          <tbody>
            {visible.map((claim) => (
              <tr key={claim.id} className="clickable-row" onClick={() => navigate(`/claims/${claim.id}`)}>
                <td>{claim.description}</td>
                <td>{claim.category}</td>
                <td>{formatCurrency(claim.amount)}</td>
                <td>
                  <StatusBadge status={claim.status} />
                </td>
                <td>{formatDateTime(claim.updatedAt)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
