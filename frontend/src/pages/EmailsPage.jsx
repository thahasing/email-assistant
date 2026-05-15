import { useEffect, useMemo, useState } from "react";
import { Reply, Share2, Sparkles, Star, Trash2 } from "lucide-react";
import Header from "../components/layout/Header";
import EmailCard from "../components/emails/EmailCard";
import { useEmails } from "../hooks/useEmails";
import { useEmailStore } from "../store/emailStore";

export default function EmailsPage({ mailbox = "inbox", title = "Inbox" }) {
  const [search, setSearch] = useState("");
  const emails = useEmailStore((state) => state.emails);
  const total = useEmailStore((state) => state.totalEmails);
  const activeLabel = useEmailStore((state) => state.activeLabel);
  const selectedEmailId = useEmailStore((state) => state.selectedEmailId);
  const emailDetail = useEmailStore((state) => state.emailDetail);
  const emailsLoading = useEmailStore((state) => state.emailsLoading);
  const emailDetailLoading = useEmailStore((state) => state.emailDetailLoading);
  const setActiveMailbox = useEmailStore((state) => state.setActiveMailbox);

  const { syncEmails, deleteEmail, markImportant, fetchEmailDetail } = useEmails(activeLabel, mailbox);

  useEffect(() => {
    setActiveMailbox(mailbox);
  }, [mailbox, setActiveMailbox]);

  const filteredEmails = useMemo(() => {
    const normalized = search.trim().toLowerCase();
    return emails.filter((email) => {
      if (!normalized) {
        return true;
      }
      return [email.subject, email.sender, email.sender_email, email.snippet]
        .filter(Boolean)
        .some((value) => value.toLowerCase().includes(normalized));
    });
  }, [emails, search]);

  return (
    <section className="page">
      <Header
        title={title}
        subtitle="Browse mailbox sections with detail-first reading, soft motion, and AI-assisted cleanup controls."
        onSync={syncEmails}
      />

      <div className="glass-panel mailbox-shell">
        <div className="mailbox-list">
          <div className="mailbox-list-toolbar">
            <div>
              <p className="eyebrow">Mailbox view</p>
              <h2>{total} messages</h2>
            </div>
            <input
              className="search-input"
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="Search sender, subject, or snippet"
            />
          </div>

          {emailsLoading ? <div className="empty-state">Loading mailbox...</div> : null}
          {!emailsLoading && !filteredEmails.length ? (
            <div className="empty-state">No emails match this mailbox view yet.</div>
          ) : null}

          <div className="email-list-scroll">
            {filteredEmails.map((email) => (
              <EmailCard
                key={email.id}
                email={email}
                isActive={selectedEmailId === email.id}
                onDelete={deleteEmail}
                onImportant={markImportant}
                onOpen={(item) => fetchEmailDetail(item.id)}
              />
            ))}
          </div>
        </div>

        <div className="mailbox-detail glass-subpanel">
          {emailDetailLoading ? (
            <div className="empty-state">Opening email...</div>
          ) : emailDetail ? (
            <>
              <div className="detail-head">
                <div>
                  <p className="eyebrow">Email detail</p>
                  <h2>{emailDetail.subject}</h2>
                  <p className="detail-meta">{emailDetail.sender} · {emailDetail.date || new Date(emailDetail.timestamp).toLocaleString()}</p>
                </div>
                <div className="detail-actions">
                  <button type="button" className="button button-secondary">
                    <Reply size={14} />
                    Reply
                  </button>
                  <button type="button" className="button button-ghost">
                    <Share2 size={14} />
                    Forward
                  </button>
                  <button type="button" className="button button-ghost" onClick={() => markImportant(emailDetail)}>
                    <Star size={14} />
                    Important
                  </button>
                  <button type="button" className="button button-danger" onClick={() => deleteEmail(emailDetail)}>
                    <Trash2 size={14} />
                    Delete
                  </button>
                </div>
              </div>
              <div className="detail-stats">
                <span className="badge badge-soft">{mailbox}</span>
                {emailDetail.label ? <span className={`badge badge-${emailDetail.label}`}>{emailDetail.label}</span> : null}
                <span className="badge badge-soft">{emailDetail.to ? `To: ${emailDetail.to}` : "Mailbox synced"}</span>
              </div>
              <article className="detail-body">
                {emailDetail.body || emailDetail.snippet}
              </article>
            </>
          ) : (
            <div className="empty-state detail-empty">
              <Sparkles size={18} />
              Select an email to open a detailed reading panel with quick actions.
            </div>
          )}
        </div>
      </div>
    </section>
  );
}
