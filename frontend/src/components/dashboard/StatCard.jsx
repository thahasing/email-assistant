export default function StatCard({ label, value, sub, color = "var(--accent)" }) {
  return (
    <div className="glass-panel stat-card">
      <span className="stat-label">{label}</span>
      <span className="stat-value" style={{ color }}>{value ?? "—"}</span>
      {sub ? <span className="stat-sub">{sub}</span> : null}
    </div>
  );
}
