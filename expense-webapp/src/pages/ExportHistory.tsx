import { useEffect, useState } from "react";
import { downloadPayrollExportCsv, listPayrollExports, type PayrollExport } from "../api";
import { formatDate } from "../format";

export default function ExportHistory() {
  const [exports, setExports] = useState<PayrollExport[]>([]);
  const [loading, setLoading] = useState(true);
  const [downloadingId, setDownloadingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    listPayrollExports().then((data) => {
      if (!cancelled) {
        setExports(data);
        setLoading(false);
      }
    });
    return () => {
      cancelled = true;
    };
  }, []);

  async function handleDownload(exp: PayrollExport) {
    setDownloadingId(exp.id);
    setError(null);
    try {
      const csv = await downloadPayrollExportCsv(exp.id);
      const blob = new Blob([csv], { type: "text/csv" });
      const url = URL.createObjectURL(blob);
      const a = document.createElement("a");
      a.href = url;
      a.download = `payroll-export-${exp.id}.csv`;
      document.body.appendChild(a);
      a.click();
      a.remove();
      URL.revokeObjectURL(url);
    } catch {
      setError("Could not download this export. Please try again.");
    } finally {
      setDownloadingId(null);
    }
  }

  return (
    <div>
      <h1>Export History</h1>
      {error && <p className="form-error">{error}</p>}

      {loading ? (
        <p>Loading…</p>
      ) : exports.length === 0 ? (
        <p className="empty-state">No payroll exports yet.</p>
      ) : (
        <table className="data-table">
          <thead>
            <tr>
              <th>Export date</th>
              <th>Claims</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {exports.map((exp) => (
              <tr key={exp.id}>
                <td>{formatDate(exp.generatedAt)}</td>
                <td>{exp.claimCount}</td>
                <td>
                  <button
                    type="button"
                    className="link-button"
                    disabled={downloadingId === exp.id}
                    onClick={() => void handleDownload(exp)}
                  >
                    {downloadingId === exp.id ? "Downloading…" : "Download"}
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
