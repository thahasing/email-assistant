import { useEffect, useRef, useState } from "react";
import { PanelRightClose, PanelRightOpen, SendHorizontal, Sparkles } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { emailsApi } from "../../api/client";
import { useEmails } from "../../hooks/useEmails";
import { useEmailStore } from "../../store/emailStore";

const PROMPTS = [
  "Why were these emails selected?",
  "Show only promotional emails",
  "Undo last action",
  "Clean all inactive emails",
];

export default function AssistantPanel() {
  const navigate = useNavigate();
  const threadEndRef = useRef(null);
  const [input, setInput] = useState("");
  const [loading, setLoading] = useState(false);

  const assistantOpen = useEmailStore((state) => state.assistantOpen);
  const setAssistantOpen = useEmailStore((state) => state.setAssistantOpen);
  const assistantMessages = useEmailStore((state) => state.assistantMessages);
  const addAssistantMessage = useEmailStore((state) => state.addAssistantMessage);
  const setActiveLabel = useEmailStore((state) => state.setActiveLabel);
  const setActiveMailbox = useEmailStore((state) => state.setActiveMailbox);
  const popUndo = useEmailStore((state) => state.popUndo);

  const {
    fetchCleanupCandidates,
    bulkDeleteCandidates,
    bulkRestoreCandidates,
    restoreEmail,
    deleteEmail,
  } = useEmails();

  useEffect(() => {
    threadEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [assistantMessages]);

  const undoLastAction = async () => {
    const lastAction = popUndo();
    if (!lastAction) {
      return "There is no reversible action yet.";
    }

    if (lastAction.type.includes("delete")) {
      for (const email of lastAction.emails) {
        await restoreEmail(email);
      }
      return `Restored ${lastAction.emails.length} email${lastAction.emails.length === 1 ? "" : "s"} from the last delete action.`;
    }

    if (lastAction.type.includes("restore")) {
      for (const email of lastAction.emails) {
        await deleteEmail(email);
      }
      return `Moved ${lastAction.emails.length} email${lastAction.emails.length === 1 ? "" : "s"} back to trash.`;
    }

    return "The last action was informational, so there was nothing to reverse.";
  };

  const executeAssistantAction = async (message) => {
    const response = await emailsApi.assistantCommand(message);
    const { reply, action, metadata } = response.data;

    if (action === "filter_label") {
      setActiveMailbox(metadata.mailbox ?? "inbox");
      setActiveLabel(metadata.label ?? null);
      navigate("/inbox");
    }

    if (action === "open_cleanup") {
      await fetchCleanupCandidates({ forceRescan: true });
      navigate("/selected-for-deletion");
    }

    if (action === "bulk_delete_cleanup") {
      const data = await fetchCleanupCandidates();
      await bulkDeleteCandidates(data.emails ?? []);
    }

    if (action === "bulk_restore_cleanup") {
      const data = await fetchCleanupCandidates();
      await bulkRestoreCandidates(data.emails ?? []);
    }

    if (action === "undo") {
      return undoLastAction();
    }

    return reply;
  };

  const runCommand = async (value) => {
    const message = value.trim();
    if (!message) {
      return;
    }

    addAssistantMessage({ sender: "user", text: message });
    setLoading(true);

    try {
      const reply = await executeAssistantAction(message);
      addAssistantMessage({ sender: "ai", text: reply });
    } catch (error) {
      addAssistantMessage({
        sender: "ai",
        text: error.response?.data?.detail ?? "I hit an issue while talking to the mailbox. Try again after a sync.",
      });
    } finally {
      setLoading(false);
      setInput("");
    }
  };

  return (
    <aside className={`assistant-shell ${assistantOpen ? "open" : "collapsed"}`}>
      <div className="assistant-header">
        <div className="assistant-heading">
          <Sparkles size={16} />
          <div>
            <strong>AI Copilot</strong>
            <span>Real-time cleanup control</span>
          </div>
        </div>
        <button type="button" className="icon-button" onClick={() => setAssistantOpen(!assistantOpen)}>
          {assistantOpen ? <PanelRightClose size={16} /> : <PanelRightOpen size={16} />}
        </button>
      </div>

      {assistantOpen ? (
        <>
          <div className="assistant-thread">
            {assistantMessages.map((message) => (
              <div key={message.id} className={`assistant-bubble ${message.sender}`}>
                {message.text}
              </div>
            ))}
            <div ref={threadEndRef} />
          </div>
          <div className="assistant-prompts">
            {PROMPTS.map((prompt) => (
              <button key={prompt} type="button" className="prompt-chip" onClick={() => setInput(prompt)}>
                {prompt}
              </button>
            ))}
          </div>
          <form
            className="assistant-composer"
            onSubmit={(event) => {
              event.preventDefault();
              runCommand(input);
            }}
          >
            <input
              value={input}
              onChange={(event) => setInput(event.target.value)}
              placeholder="Explain, filter, scan, undo, or clean"
              disabled={loading}
            />
            <button type="submit" className="icon-button primary" disabled={loading || !input.trim()}>
              <SendHorizontal size={14} />
            </button>
          </form>
        </>
      ) : (
        <button type="button" className="assistant-mini-launcher" onClick={() => setAssistantOpen(true)} aria-label="Open assistant">
          <Sparkles size={16} />
        </button>
      )}
    </aside>
  );
}
