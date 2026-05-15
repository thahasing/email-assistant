import { create } from "zustand";

const initialAssistantMessages = [
  {
    id: "welcome",
    sender: "ai",
    text: "Ask me why emails were selected, filter promotional mail, undo the last action, or scan inactive emails.",
  },
];

export const useEmailStore = create((set, get) => ({
  isAuthenticated: false,
  authChecked: false,
  setAuthenticated: (value) => set({ isAuthenticated: value, authChecked: true }),
  resetAuth: () => set({ isAuthenticated: false, authChecked: false }),

  activeMailbox: "inbox",
  activeLabel: null,
  setActiveMailbox: (mailbox) => set({ activeMailbox: mailbox }),
  setActiveLabel: (label) => set({ activeLabel: label }),

  emails: [],
  totalEmails: 0,
  emailsLoading: false,
  emailDetail: null,
  emailDetailLoading: false,
  selectedEmailId: null,
  setEmails: (emails, total) => set({ emails, totalEmails: total }),
  setEmailsLoading: (value) => set({ emailsLoading: value }),
  setEmailDetailLoading: (value) => set({ emailDetailLoading: value }),
  setSelectedEmailId: (emailId) => set({ selectedEmailId: emailId }),
  setEmailDetail: (detail) => set({ emailDetail: detail, selectedEmailId: detail?.id ?? null }),
  updateEmail: (emailId, patch) =>
    set((state) => ({
      emails: state.emails.map((email) => (email.id === emailId ? { ...email, ...patch } : email)),
      cleanupCandidates: state.cleanupCandidates.map((email) => (email.id === emailId ? { ...email, ...patch } : email)),
      emailDetail: state.emailDetail?.id === emailId ? { ...state.emailDetail, ...patch } : state.emailDetail,
    })),
  removeEmailFromLists: (emailId) =>
    set((state) => ({
      emails: state.emails.filter((email) => email.id !== emailId),
      cleanupCandidates: state.cleanupCandidates.filter((email) => email.id !== emailId),
      totalEmails: Math.max(state.totalEmails - 1, 0),
      emailDetail: state.emailDetail?.id === emailId ? null : state.emailDetail,
      selectedEmailId: state.selectedEmailId === emailId ? null : state.selectedEmailId,
    })),
  restoreEmailInLists: (email) =>
    set((state) => ({
      emails: state.emails.some((item) => item.id === email.id) ? state.emails : [email, ...state.emails],
      cleanupCandidates: state.cleanupCandidates.some((item) => item.id === email.id)
        ? state.cleanupCandidates
        : [email, ...state.cleanupCandidates],
      totalEmails: state.totalEmails + 1,
    })),

  cleanupDays: 7,
  cleanupCandidates: [],
  cleanupLoading: false,
  cleanupError: null,
  cleanupStats: null,
  setCleanupLoading: (value) => set({ cleanupLoading: value }),
  setCleanupError: (value) => set({ cleanupError: value }),
  setCleanupCandidates: (emails, stats) => set({ cleanupCandidates: emails, cleanupStats: stats, cleanupError: null }),

  insights: null,
  setInsights: (data) => set({ insights: data }),

  isSyncing: false,
  setSyncing: (value) => set({ isSyncing: value }),

  assistantOpen: false,
  assistantMessages: initialAssistantMessages,
  addAssistantMessage: (message) =>
    set((state) => ({
      assistantMessages: [
        ...state.assistantMessages,
        { id: crypto.randomUUID?.() ?? `${Date.now()}-${Math.random()}`, ...message },
      ],
    })),
  setAssistantOpen: (value) => set({ assistantOpen: value }),

  undoStack: [],
  pushUndo: (entry) => set((state) => ({ undoStack: [...state.undoStack, entry] })),
  popUndo: () => {
    const stack = get().undoStack;
    const item = stack[stack.length - 1];
    set({ undoStack: stack.slice(0, -1) });
    return item;
  },
}));
