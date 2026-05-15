import { useEffect, useMemo, useState } from "react";
import { AlertTriangle, Filter, RefreshCw, Search, ShieldCheck, Trash2, Undo2 } from "lucide-react";
import Header from "../components/layout/Header";
import { useEmails } from "../hooks/useEmails";
import { useInsights } from "../hooks/useInsights";
import { useEmailStore } from "../store/emailStore";

const FILTERS = [
  { value: "all", label: "All" },
  { value: "promotions", label: "Promotions" },
  { value: "social", label: "Social" },
  { value: "updates", label: "Updates" },
  { value: "spam", label: "Spam" },
  { value: "important", label: "Important" },
  { value: "uncategorized", label: "Uncategorized" },
];

export default function SelectedForDeletionPage({ mode = "cleanup" }) {
  const [query, setQuery] = useState("");
  const [activeFilter, setActiveFilter] = useState("all");
  const [visibleCount, setVisibleCount] = useState(40);

  const cleanupCandidates = useEmailStore((state) => state.cleanupCandidates);
  const cleanupLoading = useEmailStore((state) => state.cleanupLoading);
  const cleanupError = useEmailStore((state) => state.cleanupError);
  const cleanupStats = useEmailStore((state) => state.cleanupStats);
  const insights = useEmailStore((state) => state.insights);

  const {
    fetchCleanupCandidates,
    syncFullMailbox,
    deleteEmail,
    restoreEmail,
    markImportant,
    bulkDeleteCandidates,
    bulkRestoreCandidates,
  } = useEmails();

  useInsights();

  useEffect(() => {
    fetchCleanupCandidates();
  }, []);

  const filtered = useMemo(() => {
    const normalized = query.trim().toLowerCase();
    return cleanupCandidates.filter((email) => {
      const label = email.label || "uncategorized";
      const labelMatch = activeFilter === "all" || label === activeFilter;
      const queryMatch =
        !normalized ||
        [email.subject, email.sender, email.sender_email, email.snippet, email.reason]
          .filter(Boolean)
          .some((value) => value.toLowerCase().includes(normalized));
      return labelMatch && queryMatch;
    });
  }, [activeFilter, cleanupCandidates, query]);

  const visibleItems = filtered.slice(0, visibleCount);
  const title = mode === "suggestions" ? "AI Suggestions" : "Selected for Deletion";
  const subtitle = mode === "suggestions"
    ? "Review what the copilot is surfacing from your full-mailbox scan and sender behavior patterns."
    : "Every email here was selected by the full mailbox scan, never deleted automatically, and stays reversible.";

  return (
    <section className="page">
      <Header
        title={title}
        subtitle={subtitle}
        showSync={false}
        actions={(
          <>
            <button type="button" className="button button-primary" onClick={() => fetchCleanupCandidates({ forceRescan: true })}>
              <RefreshCw size={14} className={cleanupLoading ? "spin" : ""} />
              Refresh full scan
            </button>
            <button type="button" className="button button-secondary" onClick={syncFullMailbox}>
              Sync full mailbox
            </button>
          </>
        )}
      />

      <div className="cleanup-layout">
        <div className="glass-panel cleanup-summary">
          <p className="eyebrow">Cleanup intelligence</p>
          <h2>{cleanupStats?.count ?? cleanupCandidates.length} inactive emails ready for review</h2>
          <p>
            The engine scans your full mailbox, excludes important and recently active threads, and queues only inactive unopened mail older than {cleanupStats?.days ?? 7} days.
          </p>
          <div className="summary-stack">
            <div className="summary-chip"><ShieldCheck size={14} /> Reversible workflow</div>
            {cleanupStats?.syncSummary ? (
              <div className="summary-chip">Scanned {cleanupStats.syncSummary.fetched} emails across {cleanupStats.syncSummary.pages} pages</div>
            ) : null}
            <div className="summary-chip">{insights?.suggestions?.length ?? 0} behavior suggestions ready</div>
          </div>
          <div className="cleanup-bulk-actions">
            <button
              type="button"
              className="button button-danger"
              onClick={() => bulkDeleteCandidates(cleanupCandidates)}
              disabled={!cleanupCandidates.length || cleanupLoading}
            >
              <Trash2 size={14} />
              {cleanupLoading ? "Deleting..." : "Delete All"}
            </button>
            <button
              type="button"
              className="button button-ghost"
              onClick={() => bulkRestoreCandidates(cleanupCandidates)}
              disabled={!cleanupCandidates.length || cleanupLoading}
            >
              <Undo2 size={14} />
              Restore All
            </button>
          </div>
          <div className="warning-callout">
            <AlertTriangle size={16} />
            Nothing is permanently deleted here. This is an AI-assisted review lane.
          </div>
          {cleanupError ? <div className="warning-callout">{cleanupError}</div> : null}
        </div>

        <div className="glass-panel cleanup-list-panel">
          <div className="cleanup-filters">
            <div className="cleanup-filter-row">
              <span className="cleanup-filter-label">
                <Filter size={14} />
                Filter
              </span>
              {FILTERS.map((filter) => (
                <button
                  key={filter.value}
                  type="button"
                  className={`filter-chip ${activeFilter === filter.value ? "active" : ""}`}
                  onClick={() => setActiveFilter(filter.value)}
                >
                  {filter.label}
                </button>
              ))}
            </div>
            <label className="cleanup-search">
              <Search size={14} />
              <input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search selected emails" />
            </label>
          </div>

          {cleanupLoading ? <div className="empty-state">Scanning the full mailbox without batching the review experience...</div> : null}
          {!cleanupLoading && !visibleItems.length ? <div className="empty-state">No selected emails match the current filter.</div> : null}

          <div className="cleanup-list">
            {visibleItems.map((email) => (
              <article key={email.id} className="cleanup-card">
                <div className="cleanup-card-main">
                  <strong>{email.subject}</strong>
                  <span>{email.sender_email}</span>
                  <p>{email.snippet}</p>
                </div>
                <div className="cleanup-card-side">
                  <span>Last opened</span>
                  <strong>{email.last_opened_at ? new Date(email.last_opened_at).toLocaleDateString() : "Never opened"}</strong>
                  <span className="reason-pill">{email.reason}</span>
                  <div className="cleanup-actions">
                    <button type="button" className="button button-danger" onClick={() => deleteEmail(email)}>Delete</button>
                    <button type="button" className="button button-secondary" onClick={() => restoreEmail(email)}>Restore</button>
                    <button type="button" className="button button-ghost" onClick={() => markImportant(email)}>Mark Important</button>
                  </div>
                </div>
              </article>
            ))}
          </div>

          {visibleCount < filtered.length ? (
            <button type="button" className="button button-secondary full-width" onClick={() => setVisibleCount((count) => count + 40)}>
              Load more selected emails
            </button>
          ) : null}
        </div>
      </div>
    </section>
  );
}
