import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { listExpenseClaims, type ExpenseClaim } from "../api";
import { formatCurrency, formatDateTime } from "../format";
import SummaryCard from "../components/SummaryCard";

const ONE_WEEK_MS = 7 * 24 * 60 * 60 * 1000;

export default function ReviewQueue() {
  const navigate = useNavigate();
  const [pending, setPending] = useState<ExpenseClaim[]>([]);
  const [approved, setApproved] = useState<ExpenseClaim[]>([]);
  const [loading, setLoading] = useState(true);
  const [employeeFilter, setEmployeeFilter] = useState<string>("All");

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    // The API scopes both calls to claims from this manager's own reports.
    Promise.all([
      listExpenseClaims({ status: "submitted" }),
      listExpenseClaims({ status: "approved" }),
    ]).then(([submitted, approvedClaims]) => {
      if (cancelled) return;
      setPending(submitted);
      setApproved(approvedClaims);
      setLoading(false);
    });
    return () => {
      cancelled = true;
    };
  }, []);

  const employees = useMemo(
    () => Array.from(new Set(pending.map((c) => c.employeeId))),
    [pending],
  );

  const visible = useMemo(
    () =>
      employeeFilter === "All" ? pending : pending.filter((c) => c.employeeId === employeeFilter),
    [pending, employeeFilter],
  );

  const approvedThisWeek = useMemo(() => {
    const cutoff = Date.now() - ONE_WEEK_MS;
    const recent = approved.filter((c) => new Date(c.updatedAt).getTime() >= cutoff);
    const total = recent.reduce((sum, c) => sum + c.amount, 0);
    return { count: recent.length, total };
  }, [approved]);

  return (
    <div>
      <div className="row row-header">
        <h1>Review Queue</h1>
        <div className="spacer" />
        <label className="field field-inline">
          <span>Employee</span>
          <select value={employeeFilter} onChange={(e) => setEmployeeFilter(e.target.value)}>
            <option value="All">All</option>
            {employees.map((id) => (
              <option key={id} value={id}>
                {id}
              </option>
            ))}
          </select>
        </label>
      </div>

      <div className="row summary-row">
        <SummaryCard label="Pending review" value={pending.length} hint="across your team" />
        <SummaryCard
          label="Approved this week"
          value={approvedThisWeek.count}
          hint={`total ${formatCurrency(approvedThisWeek.total)}`}
        />
      </div>

      {loading ? (
        <p>Loading…</p>
      ) : visible.length === 0 ? (
        <p className="empty-state">No pending claims.</p>
      ) : (
        <table className="data-table">
          <thead>
            <tr>
              <th>Employee</th>
              <th>Expense</th>
              <th>Category</th>
              <th>Amount</th>
              <th>Submitted</th>
            </tr>
          </thead>
          <tbody>
            {visible.map((claim) => (
              <tr
                key={claim.id}
                className="clickable-row"
                onClick={() => navigate(`/review/${claim.id}`)}
              >
                <td>{claim.employeeId}</td>
                <td>{claim.description}</td>
                <td>{claim.category}</td>
                <td>{formatCurrency(claim.amount)}</td>
                <td>{formatDateTime(claim.updatedAt)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
