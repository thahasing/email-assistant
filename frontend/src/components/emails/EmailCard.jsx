import { formatDistanceToNow } from "date-fns";
import { MailOpen, Star, Trash2 } from "lucide-react";

export default function EmailCard({ email, isActive, onDelete, onImportant, onOpen }) {
  return (
    <article className={`email-card ${isActive ? "active" : ""}`} onClick={() => onOpen?.(email)}>
      <div className={`email-status-dot ${email.is_read ? "read" : "unread"}`} />
      <strong className="email-sender">{email.sender?.split("<")[0].trim() || email.sender_email}</strong>
      <div className="email-card-main">
        <div className="email-card-subject-line">
          <span className="email-card-subject">{email.subject}</span>
          <span className="email-card-snippet">{email.snippet}</span>
        </div>
        <div className="email-card-tags">
          {email.label ? <span className={`badge badge-${email.label}`}>{email.label}</span> : null}
          {email.cleanup_reason ? <span className="badge badge-warning">AI selected</span> : null}
        </div>
      </div>
      <span className="email-time">{formatDistanceToNow(new Date(email.timestamp), { addSuffix: true })}</span>
      <div className="email-card-actions">
        <button type="button" className="icon-button" onClick={(event) => { event.stopPropagation(); onImportant?.(email); }}>
          <Star size={14} />
        </button>
        <button type="button" className="icon-button" onClick={(event) => { event.stopPropagation(); onOpen?.(email); }}>
          <MailOpen size={14} />
        </button>
        <button type="button" className="icon-button danger" onClick={(event) => { event.stopPropagation(); onDelete?.(email); }}>
          <Trash2 size={14} />
        </button>
      </div>
    </article>
  );
}
