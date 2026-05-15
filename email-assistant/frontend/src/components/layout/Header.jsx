import { RefreshCw, LogOut } from "lucide-react";
import { useEmails } from "../../hooks/useEmails";
import { useEmailStore } from "../../store/emailStore";
import { authApi } from "../../api/client";

export default function Header({ title }) {
  const { syncEmails } = useEmails();
  const isSyncing = useEmailStore((s) => s.isSyncing);

  return (
    <header style={{
      height: 56, borderBottom: "1px solid var(--border)",
      display: "flex", alignItems: "center", justifyContent: "space-between",
      padding: "0 28px", background: "var(--bg-surface)",
    }}>
      <h1 style={{ fontSize: 16, fontWeight: 600 }}>{title}</h1>
      <div style={{ display: "flex", gap: 10 }}>
        <button onClick={syncEmails} disabled={isSyncing} style={{
          display: "flex", alignItems: "center", gap: 6, padding: "6px 14px",
          background: "var(--accent)", color: "#fff", border: "none",
          borderRadius: 8, fontSize: 13, fontWeight: 500, cursor: "pointer",
          opacity: isSyncing ? 0.6 : 1,
        }}>
          <RefreshCw size={13} style={{ animation: isSyncing ? "spin 1s linear infinite" : "none" }} />
          {isSyncing ? "Syncing…" : "Sync"}
        </button>
        <button onClick={() => { authApi.logout(); window.location.href = "/login"; }}
          style={{ display: "flex", alignItems: "center", gap: 6, padding: "6px 12px",
            background: "transparent", color: "var(--text-muted)", border: "1px solid var(--border)",
            borderRadius: 8, fontSize: 13, cursor: "pointer" }}>
          <LogOut size={13} /> Sign out
        </button>
      </div>
      <style>{`@keyframes spin { to { transform: rotate(360deg) }}`}</style>
    </header>
  );
}
