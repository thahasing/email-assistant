import Header from "../components/layout/Header";
import { useInsights } from "../hooks/useInsights";
import { useEmailStore } from "../store/emailStore";

export default function InsightsPage() {
  useInsights();
  const insights = useEmailStore((state) => state.insights);

  return (
    <section className="page">
      <Header
        title="Analytics"
        subtitle="Mailbox performance, sender learning signals, and cleanup readiness at a glance."
        showSync={false}
      />
      <div className="analytics-grid">
        <div className="glass-panel info-panel">
          <p className="eyebrow">Sender learning</p>
          <h2>{insights?.top_senders?.length ?? 0} tracked sender profiles</h2>
          <p>The behavior engine is learning which senders matter most from opens, deletes, and important actions.</p>
        </div>
        <div className="glass-panel info-panel">
          <p className="eyebrow">Cleanup readiness</p>
          <h2>{insights?.cleanup_candidates ?? 0} candidates</h2>
          <p>These emails passed the inactive-mail rules and are safe to review in the Selected for Deletion view.</p>
        </div>
        <div className="glass-panel info-panel">
          <p className="eyebrow">Signals</p>
          <h2>{insights?.unread ?? 0} unread emails</h2>
          <p>Unread volume combines with sender scores and thread recency to help the assistant avoid risky cleanup actions.</p>
        </div>
      </div>
    </section>
  );
}
