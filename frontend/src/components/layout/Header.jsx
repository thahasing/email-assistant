import { RefreshCw, LogOut } from "lucide-react";
import { authApi } from "../../api/client";
import { useEmailStore } from "../../store/emailStore";

export default function Header({ title, subtitle, actions = null, showSync = true, onSync = null }) {
  const isSyncing = useEmailStore((state) => state.isSyncing);

  return (
    <header className="page-header glass-panel">
      <div>
        <p className="eyebrow">AI-powered control center</p>
        <h1>{title}</h1>
        {subtitle ? <p className="page-subtitle">{subtitle}</p> : null}
      </div>
      <div className="header-actions">
        {actions}
        {showSync ? (
          <button type="button" className="button button-primary" onClick={onSync} disabled={isSyncing}>
            <RefreshCw size={14} className={isSyncing ? "spin" : ""} />
            {isSyncing ? "Syncing" : "Sync mailbox"}
          </button>
        ) : null}
        <button
          type="button"
          className="button button-ghost"
          onClick={async () => {
            await authApi.logout();
            window.localStorage.removeItem("mailmind_auth_hint");
            window.location.href = "/login";
          }}
        >
          <LogOut size={14} />
          Sign out
        </button>
      </div>
    </header>
  );
}
