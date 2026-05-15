import { Trash2 } from "lucide-react";
import { formatDistanceToNow } from "date-fns";

export default function EmailCard({ email, onDelete, onOpen }) {
  return (
    <div onClick={() => onOpen?.(email.id)} style={{
      display: "flex", alignItems: "flex-start", gap: 14,
      padding: "14px 18px", borderBottom: "1px solid var(--border)",
      cursor: "pointer", transition: "background .1s",
    }}
    onMouseEnter={e => e.currentTarget.style.background = "var(--bg-elevated)"}
    onMouseLeave={e => e.currentTarget.style.background = "transparent"}>

      {/* Unread dot */}
      <div style={{ marginTop: 6, width: 7, height: 7, borderRadius: "50%",
        background: email.is_read ? "transparent" : "var(--accent)", flexShrink: 0 }} />

      {/* Content */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 3 }}>
          <span style={{ fontWeight: 500, fontSize: 13, color: "var(--text-primary)", flexShrink: 0 }}>
            {email.sender.split("<")[0].trim() || email.sender_email}
          </span>
          {email.label && <span className={`badge badge-${email.label}`}>{email.label}</span>}
          <span style={{ marginLeft: "auto", fontSize: 11, color: "var(--text-muted)", flexShrink: 0 }}>
            {formatDistanceToNow(new Date(email.timestamp), { addSuffix: true })}
          </span>
        </div>
        <div style={{ fontSize: 13, fontWeight: 500, color: "var(--text-primary)", marginBottom: 2,
          overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
          {email.subject}
        </div>
        <div style={{ fontSize: 12, color: "var(--text-muted)",
          overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
          {email.snippet}
        </div>
      </div>

      {/* Delete button */}
      <button onClick={(e) => { e.stopPropagation(); onDelete?.(email.id); }}
        style={{ padding: 6, background: "transparent", border: "none",
          cursor: "pointer", color: "var(--text-muted)", borderRadius: 6,
          opacity: 0, transition: "opacity .15s" }}
        className="delete-btn">
        <Trash2 size={14} />
      </button>
      <style>{`.delete-btn { opacity: 0 } div:hover .delete-btn { opacity: 1 }`}</style>
    </div>
  );
}
