import { NavLink } from "react-router-dom";
import {
  BarChart3,
  Inbox,
  Lightbulb,
  Mail,
  Send,
  Settings,
  ShieldAlert,
  Sparkles,
  Trash2,
  FileEdit,
} from "lucide-react";
import { useEmailStore } from "../../store/emailStore";

const NAV_ITEMS = [
  { to: "/inbox", icon: Inbox, label: "Inbox", mailbox: "inbox" },
  { to: "/sent", icon: Send, label: "Sent", mailbox: "sent" },
  { to: "/drafts", icon: FileEdit, label: "Drafts", mailbox: "drafts" },
  { to: "/spam", icon: ShieldAlert, label: "Spam", mailbox: "spam" },
  { to: "/trash", icon: Trash2, label: "Trash", mailbox: "trash" },
  { to: "/ai-suggestions", icon: Lightbulb, label: "AI Suggestions" },
  { to: "/selected-for-deletion", icon: Sparkles, label: "Selected for Deletion" },
  { to: "/analytics", icon: BarChart3, label: "Analytics" },
  { to: "/settings", icon: Settings, label: "Settings" },
];

const LABELS = ["important", "promotions", "social", "updates", "spam"];

export default function Sidebar() {
  const setActiveMailbox = useEmailStore((state) => state.setActiveMailbox);
  const setActiveLabel = useEmailStore((state) => state.setActiveLabel);
  const activeLabel = useEmailStore((state) => state.activeLabel);

  return (
    <aside className="sidebar">
      <div className="sidebar-brand">
        <div className="sidebar-brand-mark">
          <Mail size={16} />
        </div>
        <div>
          <strong>MailMind</strong>
          <span>Intelligent mailbox ops</span>
        </div>
      </div>

      <nav className="sidebar-nav">
        {NAV_ITEMS.map(({ to, icon: Icon, label, mailbox }) => (
          <NavLink
            key={to}
            to={to}
            className={({ isActive }) => `sidebar-link ${isActive ? "active" : ""}`}
            onClick={() => {
              setActiveLabel(null);
              if (mailbox) {
                setActiveMailbox(mailbox);
              }
            }}
          >
            <Icon size={16} />
            <span>{label}</span>
          </NavLink>
        ))}
      </nav>

      <div className="sidebar-subsection">
        <span className="sidebar-subtitle">Quick Filters</span>
        <div className="sidebar-filter-list">
          {LABELS.map((label) => (
            <button
              key={label}
              type="button"
              className={`filter-pill ${activeLabel === label ? "active" : ""}`}
              onClick={() => setActiveLabel(activeLabel === label ? null : label)}
            >
              {label}
            </button>
          ))}
        </div>
      </div>
    </aside>
  );
}
