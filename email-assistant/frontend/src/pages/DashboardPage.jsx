import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer, BarChart, Bar, XAxis, YAxis } from "recharts";
import { useState } from "react";
import { Trash2 } from "lucide-react";
import { useInsights } from "../hooks/useInsights";
import { useEmailStore } from "../store/emailStore";
import { api } from "../api/client";
import StatCard from "../components/dashboard/StatCard";
import Header from "../components/layout/Header";

const COLORS = { important: "#4f6ef7", promotions: "#fbbf24", spam: "#f87171", social: "#34d399", updates: "#7b82a0" };

export default function DashboardPage() {
  useInsights();
  const insights = useEmailStore((s) => s.insights);
  const [cleanupLoading, setCleanupLoading] = useState(false);
  const [cleanupResult, setCleanupResult] = useState(null);

  const handleAutoCleanup = async () => {
    setCleanupLoading(true);
    try {
      const response = await api.post("/emails/auto-cleanup", null, {
        params: { days_old: 7, dry_run: false },
      });
      setCleanupResult(response.data);
      // Show success message
      setTimeout(() => setCleanupResult(null), 5000);
    } catch (err) {
      console.error("Cleanup failed:", err);
      setCleanupResult({ error: "Failed to cleanup emails" });
    } finally {
      setCleanupLoading(false);
    }
  };

  const pieData = insights ? [
    { name: "Important",  value: insights.important },
    { name: "Promotions", value: insights.promotions },
    { name: "Spam",       value: insights.spam },
    { name: "Social",     value: insights.social },
    { name: "Updates",    value: insights.updates },
  ].filter(d => d.value > 0) : [];

  return (
    <div style={{ flex: 1, overflow: "auto" }}>
      <Header title="Dashboard" />
      <div style={{ padding: 28 }}>
        {/* Stats row */}
        <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 16, marginBottom: 28 }}>
          <StatCard label="Total emails" value={insights?.total_emails} />
          <StatCard label="Unread" value={insights?.unread} color="var(--amber)" />
          <StatCard label="Spam / Promos" value={(insights?.spam ?? 0) + (insights?.promotions ?? 0)} color="var(--red)" />
          <StatCard label="Weekly change" value={`${insights?.week_over_week_change ?? 0}%`} color="var(--green)"
            sub={insights?.week_over_week_change >= 0 ? "↑ more than last week" : "↓ less than last week"} />
        </div>

        {/* Auto-cleanup section */}
        <div className="card" style={{ marginBottom: 28, background: "linear-gradient(135deg, var(--bg-primary) 0%, var(--bg-elevated) 100%)", border: "1px solid var(--accent-faint)" }}>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
            <div>
              <h3 style={{ fontSize: 14, fontWeight: 600, marginBottom: 4 }}>🧹 Auto-Cleanup</h3>
              <p style={{ fontSize: 13, color: "var(--text-muted)", marginBottom: 0 }}>Remove unopened emails older than 7 days</p>
            </div>
            <button
              onClick={handleAutoCleanup}
              disabled={cleanupLoading}
              style={{
                display: "flex",
                alignItems: "center",
                gap: 8,
                padding: "10px 20px",
                background: cleanupLoading ? "var(--text-muted)" : "var(--accent)",
                color: "#fff",
                border: "none",
                borderRadius: 8,
                cursor: cleanupLoading ? "not-allowed" : "pointer",
                fontWeight: 500,
                fontSize: 14,
                opacity: cleanupLoading ? 0.6 : 1,
              }}
            >
              <Trash2 size={16} />
              {cleanupLoading ? "Cleaning..." : "Run Cleanup"}
            </button>
          </div>
          {cleanupResult && (
            <div style={{ marginTop: 12, padding: 12, background: "rgba(52, 211, 153, 0.1)", borderRadius: 6, fontSize: 13, color: "var(--green)" }}>
              {cleanupResult.error ? (
                <span>{cleanupResult.error}</span>
              ) : (
                <span>✓ {cleanupResult.message}</span>
              )}
            </div>
          )}
        </div>

        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 16, marginBottom: 28 }}>
          {/* Pie chart */}
          <div className="card">
            <h2 style={{ fontSize: 13, fontWeight: 600, marginBottom: 16, color: "var(--text-muted)" }}>BY CATEGORY</h2>
            <ResponsiveContainer width="100%" height={220}>
              <PieChart>
                <Pie data={pieData} cx="50%" cy="50%" innerRadius={60} outerRadius={90} paddingAngle={3} dataKey="value">
                  {pieData.map((entry) => (
                    <Cell key={entry.name} fill={COLORS[entry.name.toLowerCase()] ?? "#888"} />
                  ))}
                </Pie>
                <Tooltip contentStyle={{ background: "var(--bg-elevated)", border: "1px solid var(--border)", borderRadius: 8, fontSize: 12 }} />
              </PieChart>
            </ResponsiveContainer>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginTop: 8 }}>
              {pieData.map(d => (
                <span key={d.name} style={{ display: "flex", alignItems: "center", gap: 5, fontSize: 12, color: "var(--text-muted)" }}>
                  <span style={{ width: 8, height: 8, borderRadius: "50%", background: COLORS[d.name.toLowerCase()] }} />
                  {d.name} ({d.value})
                </span>
              ))}
            </div>
          </div>

          {/* Suggestions */}
          <div className="card">
            <h2 style={{ fontSize: 13, fontWeight: 600, marginBottom: 16, color: "var(--text-muted)" }}>SUGGESTIONS</h2>
            {(insights?.suggestions ?? []).length === 0 ? (
              <p style={{ color: "var(--text-muted)", fontSize: 13 }}>No suggestions yet — keep using the app to build your behavior profile.</p>
            ) : (
              (insights?.suggestions ?? []).map((s, i) => (
                <div key={i} style={{ padding: "10px 0", borderBottom: "1px solid var(--border)", fontSize: 13 }}>
                  <div style={{ fontWeight: 500, marginBottom: 3 }}>{s.display_name}</div>
                  <div style={{ color: "var(--text-muted)", fontSize: 12 }}>{s.suggestion}</div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Top senders */}
        <div className="card">
          <h2 style={{ fontSize: 13, fontWeight: 600, marginBottom: 16, color: "var(--text-muted)" }}>TOP SENDERS</h2>
          <table style={{ width: "100%", borderCollapse: "collapse", fontSize: 13 }}>
            <thead>
              <tr style={{ color: "var(--text-muted)", fontSize: 11, textTransform: "uppercase", letterSpacing: ".06em" }}>
                <th style={{ textAlign: "left", padding: "4px 0", fontWeight: 600 }}>Sender</th>
                <th style={{ textAlign: "right", padding: "4px 0", fontWeight: 600 }}>Received</th>
                <th style={{ textAlign: "right", padding: "4px 0", fontWeight: 600 }}>Open rate</th>
                <th style={{ textAlign: "right", padding: "4px 0", fontWeight: 600 }}>Score</th>
              </tr>
            </thead>
            <tbody>
              {(insights?.top_senders ?? []).map((s) => (
                <tr key={s.sender_email} style={{ borderTop: "1px solid var(--border)" }}>
                  <td style={{ padding: "9px 0" }}>
                    <div style={{ fontWeight: 500 }}>{s.display_name}</div>
                    <div style={{ fontSize: 11, color: "var(--text-muted)" }}>{s.sender_email}</div>
                  </td>
                  <td style={{ textAlign: "right", color: "var(--text-muted)" }}>{s.total_received}</td>
                  <td style={{ textAlign: "right", color: "var(--text-muted)" }}>{(s.open_rate * 100).toFixed(0)}%</td>
                  <td style={{ textAlign: "right" }}>
                    <span style={{ color: s.importance_score >= 0 ? "var(--green)" : "var(--red)", fontWeight: 500 }}>
                      {s.importance_score >= 0 ? "+" : ""}{s.importance_score}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
