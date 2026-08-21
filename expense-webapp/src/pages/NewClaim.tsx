import { useEffect, useState, type FormEvent } from "react";
import { useNavigate, useParams } from "react-router-dom";
import {
  getExpenseClaim,
  resubmitExpenseClaim,
  submitExpenseClaim,
  updateExpenseClaim,
  uploadExpenseClaimReceipt,
  type ExpenseClaimInput,
} from "../api";

const CATEGORIES = ["Meals", "Travel", "Software", "Office Supplies", "Other"];

// Doubles as the "New Expense Claim" screen (wireframes.dsl: NewClaim) and,
// when routed with :claimId, the "Edit and resubmit" target a rejected
// ClaimDetail links to — same fields, different submit behavior.
export default function NewClaim() {
  const navigate = useNavigate();
  const { claimId } = useParams<{ claimId?: string }>();
  const isEdit = Boolean(claimId);

  const [amount, setAmount] = useState("");
  const [category, setCategory] = useState(CATEGORIES[0]);
  const [expenseDate, setExpenseDate] = useState("");
  const [description, setDescription] = useState("");
  const [receipt, setReceipt] = useState<File | null>(null);
  const [loading, setLoading] = useState(isEdit);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!claimId) return;
    let cancelled = false;
    getExpenseClaim(claimId).then((claim) => {
      if (cancelled || !claim) return;
      setAmount(String(claim.amount));
      setCategory(claim.category);
      setExpenseDate(claim.expenseDate);
      setDescription(claim.description);
      setLoading(false);
    });
    return () => {
      cancelled = true;
    };
  }, [claimId]);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);

    const parsedAmount = Number.parseFloat(amount);
    if (Number.isNaN(parsedAmount) || parsedAmount <= 0) {
      setError("Enter a valid amount.");
      return;
    }
    if (!expenseDate) {
      setError("Enter the date of the expense.");
      return;
    }
    if (!description.trim()) {
      setError("Describe what this expense was for.");
      return;
    }

    const input: ExpenseClaimInput = {
      amount: parsedAmount,
      category,
      expenseDate,
      description: description.trim(),
    };

    setSubmitting(true);
    try {
      if (isEdit && claimId) {
        // Edit and resubmit a rejected claim: PUT the edited fields, then
        // resubmit it for another round of manager review.
        await updateExpenseClaim(claimId, input);
        if (receipt) await uploadExpenseClaimReceipt(claimId, receipt);
        await resubmitExpenseClaim(claimId);
        navigate(`/claims/${claimId}`);
      } else {
        const created = await submitExpenseClaim(input);
        if (created && receipt) {
          await uploadExpenseClaimReceipt(created.id, receipt);
        }
        navigate("/claims");
      }
    } catch {
      setError("Something went wrong submitting the claim. Please try again.");
    } finally {
      setSubmitting(false);
    }
  }

  if (loading) return <p>Loading…</p>;

  return (
    <div>
      <p className="breadcrumb">My Claims / {isEdit ? "Edit claim" : "New claim"}</p>
      <h1>{isEdit ? "Edit Expense Claim" : "New Expense Claim"}</h1>

      <form onSubmit={handleSubmit} className="form">
        {error && <p className="form-error">{error}</p>}

        <div className="row form-row">
          <label className="field">
            <span>Amount</span>
            <input
              type="number"
              step="0.01"
              min="0"
              placeholder="e.g. 84.20"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              required
            />
          </label>
          <label className="field">
            <span>Category</span>
            <select value={category} onChange={(e) => setCategory(e.target.value)}>
              {CATEGORIES.map((c) => (
                <option key={c} value={c}>
                  {c}
                </option>
              ))}
            </select>
          </label>
        </div>

        <label className="field">
          <span>Date of expense</span>
          <input
            type="date"
            value={expenseDate}
            onChange={(e) => setExpenseDate(e.target.value)}
            required
          />
        </label>

        <label className="field">
          <span>What was this expense for?</span>
          <textarea
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            rows={4}
            required
          />
        </label>

        <label className="field">
          <span>Attach receipt</span>
          <input
            type="file"
            accept="image/*,application/pdf"
            onChange={(e) => setReceipt(e.target.files?.[0] ?? null)}
          />
          {receipt && <span className="file-name">{receipt.name}</span>}
        </label>

        <div className="row form-actions">
          <div className="spacer" />
          <button type="button" className="btn" onClick={() => navigate(-1)}>
            Cancel
          </button>
          <button type="submit" className="btn btn-primary" disabled={submitting}>
            {submitting ? "Submitting…" : "Submit claim"}
          </button>
        </div>
      </form>
    </div>
  );
}
