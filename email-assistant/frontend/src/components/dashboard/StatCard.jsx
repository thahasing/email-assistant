export default function StatCard({ label, value, sub, color = "var(--accent)" }) {
  return (
    <div className="card" style={{ display: "flex", flexDirection: "column", gap: 6 }}>
      <span style={{ fontSize: 11, fontWeight: 600, color: "var(--text-muted)",
        textTransform: "uppercase", letterSpacing: ".08em" }}>{label}</span>
      <span style={{ fontSize: 32, fontWeight: 600, color }}>{value ?? "—"}</span>
      {sub && <span style={{ fontSize: 12, color: "var(--text-muted)" }}>{sub}</span>}
    </div>
  );
}
