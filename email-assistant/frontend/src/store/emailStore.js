/**
 * store/emailStore.js
 * Zustand global store — single source of truth for the frontend.
 * Components read from this store; they don't each manage their own fetch state.
 */
import { create } from "zustand";

export const useEmailStore = create((set, get) => ({
  // Auth
  isAuthenticated: false,
  setAuthenticated: (val) => set({ isAuthenticated: val }),

  // Emails
  emails: [],
  totalEmails: 0,
  activeLabel: null,
  setEmails: (emails, total) => set({ emails, totalEmails: total }),
  setActiveLabel: (label) => set({ activeLabel: label }),

  // Insights
  insights: null,
  setInsights: (data) => set({ insights: data }),

  // UI state
  isSyncing: false,
  setSyncing: (val) => set({ isSyncing: val }),

  // Optimistic delete — remove from UI immediately
  removeEmail: (id) =>
    set((state) => ({ emails: state.emails.filter((e) => e.id !== id) })),
}));
