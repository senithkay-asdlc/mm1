import type { ClaimStatus } from "../api";

const VARIANT: Record<ClaimStatus, string> = {
  draft: "badge-neutral",
  submitted: "badge-info",
  approved: "badge-success",
  rejected: "badge-danger",
};

const LABEL: Record<ClaimStatus, string> = {
  draft: "Draft",
  submitted: "Submitted",
  approved: "Approved",
  rejected: "Rejected",
};

export default function StatusBadge({ status }: { status: ClaimStatus }) {
  return <span className={`badge ${VARIANT[status]}`}>{LABEL[status]}</span>;
}
