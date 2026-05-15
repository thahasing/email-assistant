import { startTransition, useEffect } from "react";
import { behaviorApi, emailsApi } from "../api/client";
import { useEmailStore } from "../store/emailStore";

export function useEmails(label = null, mailboxOverride = null) {
  const store = useEmailStore();
  const mailbox = mailboxOverride ?? store.activeMailbox;

  const fetchEmails = async (page = 1, pageSize = 30) => {
    store.setEmailsLoading(true);
    try {
      const response = await emailsApi.list({ page, pageSize, label, mailbox });
      startTransition(() => {
        store.setEmails(response.data.emails, response.data.total);
      });
      return response.data;
    } finally {
      store.setEmailsLoading(false);
    }
  };

  const syncEmails = async () => {
    store.setSyncing(true);
    try {
      await emailsApi.sync({ maxResults: 50, fullScan: false });
      await fetchEmails();
    } finally {
      store.setSyncing(false);
    }
  };

  const syncFullMailbox = async () => {
    store.setCleanupLoading(true);
    try {
      const response = await emailsApi.sync({ fullScan: true });
      await fetchEmails();
      return response.data;
    } finally {
      store.setCleanupLoading(false);
    }
  };

  const fetchCleanupCandidates = async ({ forceRescan = false } = {}) => {
    store.setCleanupLoading(true);
    store.setCleanupError(null);
    try {
      const response = await emailsApi.cleanupCandidates({ days: store.cleanupDays, forceRescan });
      startTransition(() => {
        store.setCleanupCandidates(response.data.emails, {
          count: response.data.count,
          days: response.data.days,
          syncSummary: response.data.sync_summary,
        });
      });
      return response.data;
    } catch (error) {
      store.setCleanupError(error.response?.data?.detail ?? "Unable to scan mailbox right now.");
      throw error;
    } finally {
      store.setCleanupLoading(false);
    }
  };

  const fetchEmailDetail = async (emailId) => {
    store.setEmailDetailLoading(true);
    try {
      const response = await emailsApi.detail(emailId);
      startTransition(() => {
        store.setEmailDetail(response.data);
        store.updateEmail(emailId, { is_read: true, last_opened_at: new Date().toISOString() });
      });
      return response.data;
    } finally {
      store.setEmailDetailLoading(false);
    }
  };

  const deleteEmail = async (emailOrId) => {
    const email = typeof emailOrId === "string"
      ? store.emails.find((item) => item.id === emailOrId) || store.cleanupCandidates.find((item) => item.id === emailOrId)
      : emailOrId;
    if (!email) {
      return;
    }

    store.removeEmailFromLists(email.id);
    store.pushUndo({ type: "delete", emails: [email] });
    await emailsApi.delete(email.id);
  };

  const restoreEmail = async (email) => {
    await emailsApi.restore(email.id);
    store.updateEmail(email.id, {
      is_deleted: false,
      is_cleanup_candidate: false,
      cleanup_reason: null,
      mailbox: "inbox",
    });
    store.removeEmailFromLists(email.id);
    store.pushUndo({ type: "restore", emails: [email] });
  };

  const markImportant = async (email) => {
    await emailsApi.markImportant(email.id);
    store.updateEmail(email.id, {
      label: "important",
      is_cleanup_candidate: false,
      cleanup_reason: null,
    });
    store.removeEmailFromLists(email.id);
  };

  const bulkDeleteCandidates = async (emails = store.cleanupCandidates) => {
    const candidates = emails.filter(Boolean);
    if (!candidates.length) {
      return;
    }
    store.setCleanupError(null);
    store.setCleanupLoading(true);

    let successIds = new Set();
    let failedIds = [];

    try {
      const response = await emailsApi.deleteCleanupCandidates();
      successIds = new Set(response.data.success ?? []);
      failedIds = response.data.failed ?? [];
    } catch (error) {
      store.setCleanupLoading(false);
      store.setCleanupError(error.response?.data?.detail ?? "Delete All failed. Please try again.");
      throw error;
    }

    const deletedEmails = candidates.filter((email) => successIds.has(email.id));

    deletedEmails.forEach((email) => store.removeEmailFromLists(email.id));

    if (deletedEmails.length) {
      store.pushUndo({ type: "bulk-delete", emails: deletedEmails });
    }

    if (failedIds.length) {
      store.setCleanupError(`Deleted ${deletedEmails.length} emails, but ${failedIds.length} could not be moved to trash.`);
    }

    store.setCleanupLoading(false);
    return { success: [...successIds], failed: failedIds };
  };

  const bulkRestoreCandidates = async (emails = store.cleanupCandidates) => {
    const candidates = emails.filter(Boolean);
    if (!candidates.length) {
      return;
    }
    store.setCleanupError(null);
    const response = await emailsApi.bulkRestore(candidates.map((email) => email.id));
    const successIds = new Set(response.data.success ?? []);
    const failedIds = response.data.failed ?? [];
    const restoredEmails = candidates.filter((email) => successIds.has(email.id));

    restoredEmails.forEach((email) => store.removeEmailFromLists(email.id));

    if (restoredEmails.length) {
      store.pushUndo({ type: "bulk-restore", emails: restoredEmails });
    }

    if (failedIds.length) {
      store.setCleanupError(`Restored ${restoredEmails.length} emails, but ${failedIds.length} could not be moved back.`);
    }

    return response.data;
  };

  const logOpen = async (emailId) => {
    await behaviorApi.log(emailId, "open");
  };

  useEffect(() => {
    fetchEmails();
  }, [label, mailbox]);

  return {
    fetchEmails,
    syncEmails,
    syncFullMailbox,
    fetchCleanupCandidates,
    fetchEmailDetail,
    deleteEmail,
    restoreEmail,
    markImportant,
    bulkDeleteCandidates,
    bulkRestoreCandidates,
    logOpen,
  };
}
