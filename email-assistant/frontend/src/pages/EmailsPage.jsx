import Header from "../components/layout/Header";
import EmailCard from "../components/emails/EmailCard";
import { useEmails } from "../hooks/useEmails";
import { useEmailStore } from "../store/emailStore";

export default function EmailsPage() {
  const activeLabel = useEmailStore((s) => s.activeLabel);
  const emails      = useEmailStore((s) => s.emails);
  const total       = useEmailStore((s) => s.totalEmails);
  const { deleteEmail, logOpen } = useEmails(activeLabel);

  return (
    <div style={{ flex: 1, overflow: "auto" }}>
      <Header title={activeLabel ? `Label: ${activeLabel}` : "Inbox"} />
      <div style={{ padding: "0 0 40px" }}>
        <div style={{ padding: "12px 18px", fontSize: 12, color: "var(--text-muted)", borderBottom: "1px solid var(--border)" }}>
          {total} emails {activeLabel && `· filtered by ${activeLabel}`}
        </div>
        {emails.length === 0 ? (
          <div style={{ padding: 40, textAlign: "center", color: "var(--text-muted)" }}>
            No emails found. Hit Sync to fetch your inbox.
          </div>
        ) : (
          emails.map((email) => (
            <EmailCard key={email.id} email={email}
              onDelete={deleteEmail}
              onOpen={(id) => logOpen(id)} />
          ))
        )}
      </div>
    </div>
  );
}
