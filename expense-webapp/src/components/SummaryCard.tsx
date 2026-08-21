export default function SummaryCard({
  label,
  value,
  hint,
}: {
  label: string;
  value: string | number;
  hint?: string;
}) {
  return (
    <div className="summary-card">
      <div className="summary-card-label">{label}</div>
      <div className="summary-card-value">{value}</div>
      {hint && <div className="summary-card-hint">{hint}</div>}
    </div>
  );
}
