import { NavLink } from "react-router-dom";
import { LayoutDashboard, Mail, BarChart2, Lightbulb, Settings } from "lucide-react";
import { useEmailStore } from "../../store/emailStore";

const NAV = [
  { to: "/dashboard",  icon: LayoutDashboard, label: "Dashboard" },
  { to: "/emails",     icon: Mail,            label: "Inbox"     },
  { to: "/insights",   icon: BarChart2,       label: "Insights"  },
];

const LABELS = ["important", "promotions", "spam", "social", "updates"];

export default function Sidebar() {
  const setActiveLabel = useEmailStore((s) => s.setActiveLabel);
  const activeLabel    = useEmailStore((s) => s.activeLabel);

  return (
    <aside style={{
      width: 220, minHeight: "100vh",
      background: "var(--bg-surface)",
      borderRight: "1px solid var(--border)",
      display: "flex", flexDirection: "column", padding: "24px 0",
    }}>
      {/* Logo */}
      <div style={{ padding: "0 20px 28px", display: "flex", alignItems: "center", gap: 10 }}>
        <div style={{
          width: 32, height: 32, borderRadius: 8,
          background: "var(--accent)", display: "grid", placeItems: "center",
        }}>
          <Mail size={16} color="#fff" />
        </div>
        <span style={{ fontWeight: 600, fontSize: 15 }}>MailMind</span>
      </div>

      {/* Main nav */}
      <nav style={{ flex: 1 }}>
        {NAV.map(({ to, icon: Icon, label }) => (
          <NavLink key={to} to={to} style={({ isActive }) => ({
            display: "flex", alignItems: "center", gap: 10,
            padding: "9px 20px", fontSize: 14, fontWeight: 500,
            color: isActive ? "var(--accent)" : "var(--text-muted)",
            background: isActive ? "var(--accent-glow)" : "transparent",
            textDecoration: "none", borderRight: isActive ? "2px solid var(--accent)" : "2px solid transparent",
            transition: "all .15s",
          })}>
            <Icon size={16} />
            {label}
          </NavLink>
        ))}

        {/* Label filters */}
        <div style={{ margin: "20px 20px 8px", fontSize: 11, fontWeight: 600, color: "var(--text-muted)", letterSpacing: ".08em", textTransform: "uppercase" }}>
          Labels
        </div>
        {LABELS.map((l) => (
          <button key={l} onClick={() => setActiveLabel(activeLabel === l ? null : l)}
            style={{
              display: "block", width: "100%", textAlign: "left",
              padding: "7px 20px", fontSize: 13,
              color: activeLabel === l ? "var(--text-primary)" : "var(--text-muted)",
              background: activeLabel === l ? "var(--accent-glow)" : "transparent",
              border: "none", cursor: "pointer", transition: "all .15s",
            }}>
            <span className={`badge badge-${l}`}>{l}</span>
          </button>
        ))}
      </nav>
    </aside>
  );
}
