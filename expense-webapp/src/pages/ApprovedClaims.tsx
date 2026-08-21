import { useEffect, useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { createPayrollExport, listExpenseClaims, listPayrollExports, type ExpenseClaim } from "../api";
import { formatCurrency, formatDateTime } from "../format";
import SummaryCard from "../components/SummaryCard";

export default function ApprovedClaims() {
  const navigate = useNavigate();
  const [claims, setClaims] = useState<ExpenseClaim[]>([]);
  const [batchCount, setBatchCount] = useState(0);
  const [loading, setLoading] = useState(true);
  const [exporting, setExporting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function load() {
    setLoading(true);
    const [approved, exports] = await Promise.all([
      listExpenseClaims({ status: "approved" }),
      listPayrollExports(),
    ]);
    setClaims(approved);
    setBatchCount(exports.length);
    setLoading(false);
  }

  useEffect(() => {
    void load();
  }, []);

  const readyToExport = useMemo(() => claims.filter((c) => !c.exported), [claims]);
  const alreadyExported = useMemo(() => claims.filter((c) => c.exported), [claims]);
  const readyTotal = useMemo(
    () => readyToExport.reduce((sum, c) => sum + c.amount, 0),
    [readyToExport],
  );

  async function handleExport() {
    setExporting(true);
    setError(null);
    try {
      await createPayrollExport();
      navigate("/exports");
    } catch {
      setError("Could not generate a payroll export. Please try again.");
    } finally {
      setExporting(false);
    }
  }

  return (
    <div>
      <div className="row row-header">
        <h1>Approved Claims</h1>
        <div className="spacer" />
        <button
          type="button"
          className="btn btn-primary"
          disabled={exporting || readyToExport.length === 0}
          onClick={() => void handleExport()}
        >
          {exporting ? "Exporting…" : "Export to payroll"}
        </button>
      </div>

      {error && <p className="form-error">{error}</p>}

      <div className="row summary-row">
        <SummaryCard
          label="Ready to export"
          value={readyToExport.length}
          hint={`total ${formatCurrency(readyTotal)}`}
        />
        <SummaryCard
          label="Already exported"
          value={alreadyExported.length}
          hint={`across ${batchCount} batches`}
        />
      </div>

      {loading ? (
        <p>Loading…</p>
      ) : claims.length === 0 ? (
        <p className="empty-state">No approved claims yet.</p>
      ) : (
        <table className="data-table">
          <thead>
            <tr>
              <th>Employee</th>
              <th>Expense</th>
              <th>Category</th>
              <th>Amount</th>
              <th>Approved</th>
              <th>Export status</th>
            </tr>
          </thead>
          <tbody>
            {claims.map((claim) => (
              <tr key={claim.id}>
                <td>{claim.employeeId}</td>
                <td>{claim.description}</td>
                <td>{claim.category}</td>
                <td>{formatCurrency(claim.amount)}</td>
                <td>{formatDateTime(claim.updatedAt)}</td>
                <td>
                  <span className={claim.exported ? "badge badge-success" : "badge badge-neutral"}>
                    {claim.exported ? "Exported" : "Ready"}
                  </span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
