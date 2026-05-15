import Header from "../components/layout/Header";

export default function InsightsPage() {
  return (
    <div style={{ flex: 1 }}>
      <Header title="Insights" />
      <div style={{ padding: 28, color: "var(--text-muted)", fontSize: 14 }}>
        Weekly insights coming in Phase 3 — sync more emails to build your behavior profile.
      </div>
    </div>
  );
}
