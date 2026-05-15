import axios from "axios";

const BASE_URL = import.meta.env.VITE_API_URL ?? "http://127.0.0.1:8000/api/v1";

export const api = axios.create({
  baseURL: BASE_URL,
  withCredentials: true,
  headers: { "Content-Type": "application/json" },
  timeout: 8000,
});

api.interceptors.response.use(
  (response) => response,
  (error) => {
    const requestUrl = error.config?.url ?? "";
    if (error.response?.status === 401 && requestUrl.includes("/auth/")) {
      window.localStorage.removeItem("mailmind_auth_hint");
      window.location.href = "/login";
    }
    return Promise.reject(error);
  }
);

export const emailsApi = {
  sync: ({ maxResults = 50, fullScan = false } = {}) =>
    api.post("/emails/sync", null, { params: { max_results: maxResults, full_scan: fullScan } }),
  list: ({ page = 1, pageSize = 30, label = null, mailbox = "inbox" } = {}) =>
    api.get("/emails", { params: { page, page_size: pageSize, mailbox, ...(label && { label }) } }),
  detail: (id) => api.get(`/emails/${id}`),
  delete: (id) => api.delete(`/emails/${id}`),
  restore: (id) => api.post(`/emails/${id}/restore`),
  markImportant: (id) => api.post(`/emails/${id}/important`),
  cleanupCandidates: ({ days = 7, forceRescan = false } = {}) =>
    api.get("/emails/cleanup-candidates", { params: { days, force_rescan: forceRescan } }),
  deleteCleanupCandidates: () => api.post("/emails/delete-cleanup-candidates", null, { timeout: 120000 }),
  bulkDelete: (emailIds) => api.post("/emails/bulk-delete", { email_ids: emailIds }),
  bulkRestore: (emailIds) => api.post("/emails/bulk-restore", { email_ids: emailIds }),
  assistantCommand: (message) => api.post("/emails/assistant/command", { message }),
};

export const behaviorApi = {
  log: (emailId, action) => api.post("/behavior/log", { email_id: emailId, action }),
  suggestions: () => api.get("/behavior/suggestions"),
};

export const insightsApi = {
  summary: () => api.get("/insights/summary"),
};

export const authApi = {
  status: () => api.get("/auth/status"),
  logout: () => api.post("/auth/logout"),
  loginUrl: () => `${BASE_URL}/auth/login`,
};
