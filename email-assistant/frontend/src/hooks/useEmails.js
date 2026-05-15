import { useEffect } from "react";
import { emailsApi, behaviorApi } from "../api/client";
import { useEmailStore } from "../store/emailStore";

export function useEmails(label = null) {
  const { setEmails, setSyncing, removeEmail } = useEmailStore();

  const fetchEmails = async (page = 1) => {
    const res = await emailsApi.list(page, label);
    setEmails(res.data.emails, res.data.total);
  };

  const syncEmails = async () => {
    setSyncing(true);
    try {
      await emailsApi.sync(50);
      await fetchEmails();
    } finally {
      setSyncing(false);
    }
  };

  const deleteEmail = async (id) => {
    removeEmail(id);   // Optimistic update first
    await emailsApi.delete(id);
    await behaviorApi.log(id, "delete");
  };

  const logOpen = (id) => behaviorApi.log(id, "open");

  useEffect(() => { fetchEmails(); }, [label]);

  return { fetchEmails, syncEmails, deleteEmail, logOpen };
}
