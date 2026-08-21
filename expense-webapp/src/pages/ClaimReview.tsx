import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { approveExpenseClaim, getExpenseClaim, rejectExpenseClaim, type ExpenseClaim } from "../api";
import { formatCurrency, formatDate, formatDateTime } from "../format";
import StatusBadge from "../components/StatusBadge";

export default function ClaimReview() {
  const { claimId } = useParams<{ claimId: string }>();
  const navigate = useNavigate();
  const [claim, setClaim] = useState<ExpenseClaim | null>(null);
  const [loading, setLoading] = useState(true);
  const [note, setNote] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (!claimId) return;
    let cancelled = false;
    getExpenseClaim(claimId).then((data) => {
      if (!cancelled) {
        setClaim(data);
        setLoading(false);
      }
    });
    return () => {
      cancelled = true;
    };
  }, [claimId]);

  async function handleApprove() {
    if (!claimId) return;
    setBusy(true);
    setError(null);
    try {
      await approveExpenseClaim(claimId);
      navigate("/review");
    } catch {
      setError("Could not approve this claim. Please try again.");
    } finally {
      setBusy(false);
    }
  }

  async function handleReject() {
    if (!claimId) return;
    if (!note.trim()) {
      setError("Add a note explaining the rejection.");
      return;
    }
    setBusy(true);
    setError(null);
    try {
      await rejectExpenseClaim(claimId, note.trim());
      navigate("/review");
    } catch {
      setError("Could not reject this claim. Please try again.");
    } finally {
      setBusy(false);
    }
  }

  if (loading) return <p>Loading…</p>;
  if (!claim) return <p>Claim not found.</p>;

  return (
    <div>
      <p className="breadcrumb">Review Queue / {claim.description}</p>
      <div className="row row-header">
        <h1>{claim.description}</h1>
        <StatusBadge status={claim.status} />
      </div>
      <p className="muted">
        Employee: {claim.employeeId} — Submitted {formatDateTime(claim.updatedAt)}
      </p>

      <div className="split-60-40">
        <div className="split-left">
          <p>
            Amount: {formatCurrency(claim.amount)} — Category: {claim.category}
          </p>
          <p>Date: {formatDate(claim.expenseDate)}</p>
          <p>Description: {claim.description}</p>
          {claim.receiptUrl ? (
            <img className="receipt-thumb" src={claim.receiptUrl} alt="Receipt" />
          ) : (
            <p className="muted">No receipt attached.</p>
          )}

          {error && <p className="form-error">{error}</p>}

          {claim.status === "submitted" && (
            <div className="row form-actions">
              <div className="spacer" />
              <button type="button" className="btn" disabled={busy} onClick={() => void handleReject()}>
                Reject
              </button>
              <button
                type="button"
                className="btn btn-primary"
                disabled={busy}
                onClick={() => void handleApprove()}
              >
                Approve
              </button>
            </div>
          )}
        </div>
        <div className="split-right">
          <label className="field">
            <span>Add a note if rejecting…</span>
            <textarea value={note} onChange={(e) => setNote(e.target.value)} rows={5} />
          </label>
        </div>
      </div>
    </div>
  );
}
