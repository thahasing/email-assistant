/**
 * api/client.js
 * Axios instance configured to talk to the FastAPI backend.
 * Import `api` in hooks/pages — never use fetch() directly.
 */
import axios from "axios";

const BASE_URL = import.meta.env.VITE_API_URL ?? "http://localhost:8003/api/v1";

export const api = axios.create({
  baseURL: BASE_URL,
  withCredentials: true,          // Send cookies for session auth
  headers: { "Content-Type": "application/json" },
});

// Global error interceptor: redirect to login on 401
api.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response?.status === 401) {
      window.location.href = "/login";
    }
    return Promise.reject(err);
  }
);

// Convenience methods
export const emailsApi = {
  sync:   (maxResults = 50) => api.post(`/emails/sync?max_results=${maxResults}`),
  list:   (page = 1, label = null) =>
    api.get("/emails", { params: { page, page_size: 20, ...(label && { label }) } }),
  delete: (id) => api.delete(`/emails/${id}`),
};

export const behaviorApi = {
  log:         (emailId, action) => api.post("/behavior/log", { email_id: emailId, action }),
  suggestions: ()                => api.get("/behavior/suggestions"),
};

export const insightsApi = {
  summary: () => api.get("/insights/summary"),
};

export const authApi = {
  status: ()  => api.get("/auth/status"),
  logout: ()  => api.post("/auth/logout"),
  loginUrl: () => `${BASE_URL}/auth/login`,
};
