import { useNavigate } from "react-router-dom";
import { BarChart, Bar, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis, Cell } from "recharts";
import Header from "../components/layout/Header";
import StatCard from "../components/dashboard/StatCard";
import { useInsights } from "../hooks/useInsights";
import { useEmails } from "../hooks/useEmails";
import { useEmailStore } from "../store/emailStore";

const COLORS = ["#7c9cff", "#f5c46b", "#5de2c2", "#ff8a8a", "#9a8cff"];

export default function DashboardPage() {
  const navigate = useNavigate();
  const insights = useEmailStore((state) => state.insights);
  const cleanupStats = useEmailStore((state) => state.cleanupStats);
  const { fetchCleanupCandidates, syncFullMailbox } = useEmails();

  useInsights();

  const pieData = insights
    ? [
        { name: "Important", value: insights.important },
        { name: "Promotions", value: insights.promotions },
        { name: "Social", value: insights.social },
        { name: "Spam", value: insights.spam },
        { name: "Updates", value: insights.updates },
      ].filter((item) => item.value > 0)
    : [];

  const senderData = (insights?.top_senders ?? []).slice(0, 5).map((sender) => ({
    name: sender.display_name.slice(0, 12),
    received: sender.total_received,
  }));

  return (
    <section className="page">
      <Header
        title="Command Dashboard"
        subtitle="A premium view into mailbox health, cleanup opportunities, sender behavior, and AI-guided action."
        onSync={syncFullMailbox}
        actions={(
          <button
            type="button"
            className="button button-secondary"
            onClick={async () => {
              await fetchCleanupCandidates({ forceRescan: true });
              navigate("/selected-for-deletion");
            }}
          >
            View Selected Emails
          </button>
        )}
      />

      <div className="hero-grid">
        <div className="glass-panel hero-card">
          <p className="eyebrow">Full mailbox scan</p>
          <h2>AI-selected cleanup workspace</h2>
          <p>
            Scan the entire mailbox, surface stale unopened emails older than 7 days, and review every action before anything reaches trash.
          </p>
          <div className="hero-metrics">
            <span>{cleanupStats?.count ?? insights?.cleanup_candidates ?? 0} selected</span>
            <span>{cleanupStats?.syncSummary?.pages ?? 0} pages scanned</span>
          </div>
        </div>
        <div className="hero-floating-card">
          <div className="orb orb-one" />
          <div className="orb orb-two" />
          <div className="glass-panel hero-float-panel">
            <strong>Mailbox pulse</strong>
            <p>{insights?.stale_unopened ?? 0} inactive emails waiting for a safe review pass.</p>
          </div>
        </div>
      </div>

      <div className="stats-grid">
        <StatCard label="Total emails" value={insights?.total_emails ?? 0} />
        <StatCard label="Unread" value={insights?.unread ?? 0} color="var(--amber)" />
        <StatCard label="Cleanup candidates" value={insights?.cleanup_candidates ?? 0} color="var(--pink)" />
        <StatCard
          label="Weekly change"
          value={`${insights?.week_over_week_change ?? 0}%`}
          color="var(--green)"
          sub={insights?.week_over_week_change >= 0 ? "Inbox volume is rising" : "Inbox volume is cooling"}
        />
      </div>

      <div className="dashboard-grid">
        <div className="glass-panel chart-card">
          <div className="section-heading">
            <div>
              <p className="eyebrow">Category mix</p>
              <h3>Classification blend</h3>
            </div>
          </div>
          <ResponsiveContainer width="100%" height={260}>
            <PieChart>
              <Pie data={pieData} dataKey="value" innerRadius={70} outerRadius={104} paddingAngle={3}>
                {pieData.map((item, index) => (
                  <Cell key={item.name} fill={COLORS[index % COLORS.length]} />
                ))}
              </Pie>
              <Tooltip contentStyle={{ background: "rgba(14,18,31,.92)", border: "1px solid rgba(255,255,255,.08)", borderRadius: 18 }} />
            </PieChart>
          </ResponsiveContainer>
        </div>

        <div className="glass-panel chart-card">
          <div className="section-heading">
            <div>
              <p className="eyebrow">Top senders</p>
              <h3>Mailbox gravity</h3>
            </div>
          </div>
          <ResponsiveContainer width="100%" height={260}>
            <BarChart data={senderData}>
              <XAxis dataKey="name" stroke="#98a3c7" tickLine={false} axisLine={false} />
              <YAxis stroke="#98a3c7" tickLine={false} axisLine={false} />
              <Tooltip contentStyle={{ background: "rgba(14,18,31,.92)", border: "1px solid rgba(255,255,255,.08)", borderRadius: 18 }} />
              <Bar dataKey="received" radius={[12, 12, 0, 0]} fill="url(#senderGradient)" />
              <defs>
                <linearGradient id="senderGradient" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#8cb3ff" />
                  <stop offset="100%" stopColor="#4b6bff" />
                </linearGradient>
              </defs>
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      <div className="glass-panel suggestion-list">
        <div className="section-heading">
          <div>
            <p className="eyebrow">AI suggestions</p>
            <h3>Behavior-driven automations</h3>
          </div>
        </div>
        {(insights?.suggestions ?? []).length ? (
          (insights?.suggestions ?? []).map((suggestion) => (
            <div key={suggestion.sender_email} className="suggestion-item">
              <div>
                <strong>{suggestion.display_name}</strong>
                <p>{suggestion.suggestion}</p>
              </div>
              <span>{Math.round((suggestion.confidence ?? 0) * 100)}% confidence</span>
            </div>
          ))
        ) : (
          <div className="empty-state">Keep interacting with email to unlock richer automation suggestions.</div>
        )}
      </div>
    </section>
  );
}
