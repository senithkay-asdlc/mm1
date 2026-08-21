import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { getExpenseClaim, type ExpenseClaim } from "../api";
import { formatCurrency, formatDate, formatDateTime } from "../format";
import StatusBadge from "../components/StatusBadge";

export default function ClaimDetail() {
  const { claimId } = useParams<{ claimId: string }>();
  const navigate = useNavigate();
  const [claim, setClaim] = useState<ExpenseClaim | null>(null);
  const [loading, setLoading] = useState(true);

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

  if (loading) return <p>Loading…</p>;
  if (!claim) return <p>Claim not found.</p>;

  return (
    <div>
      <p className="breadcrumb">My Claims / {claim.description}</p>
      <div className="row row-header">
        <h1>{claim.description}</h1>
        <StatusBadge status={claim.status} />
      </div>
      <p className="muted">Updated {formatDateTime(claim.updatedAt)}</p>

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

          {claim.status === "rejected" && (
            <div className="row form-actions">
              <div className="spacer" />
              <button
                type="button"
                className="btn btn-primary"
                onClick={() => navigate(`/claims/${claim.id}/edit`)}
              >
                Edit and resubmit
              </button>
            </div>
          )}
        </div>
        <div className="split-right">
          <h2>Review notes</h2>
          {claim.rejectionReason ? (
            <p>{claim.rejectionReason}</p>
          ) : (
            <p className="muted">No review notes yet.</p>
          )}
        </div>
      </div>
    </div>
  );
}
