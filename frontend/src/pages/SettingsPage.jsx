import Header from "../components/layout/Header";
import { useEmailStore } from "../store/emailStore";

export default function SettingsPage() {
  const cleanupDays = useEmailStore((state) => state.cleanupDays);

  return (
    <section className="page">
      <Header
        title="Settings"
        subtitle="Mailbox connection details and AI cleanup policy controls."
        showSync={false}
      />
      <div className="analytics-grid">
        <div className="glass-panel info-panel">
          <p className="eyebrow">Policy</p>
          <h2>Inactive email threshold: {cleanupDays} days</h2>
          <p>
            Cleanup excludes starred or important emails and avoids threads with recent activity.
          </p>
        </div>
        <div className="glass-panel info-panel">
          <p className="eyebrow">Connection</p>
          <h2>Google OAuth mailbox link</h2>
          <p>
            Keep the backend running on <code>127.0.0.1:8000</code> and the frontend on <code>127.0.0.1:5173</code> for local development.
          </p>
        </div>
        <div className="glass-panel info-panel">
          <p className="eyebrow">Assistant</p>
          <h2>Persistent control layer</h2>
          <p>
            The AI copilot can explain selections, filter by label, surface cleanup candidates, and reverse the latest bulk action.
          </p>
        </div>
      </div>
    </section>
  );
}
