import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { useEffect } from "react";
import { authApi } from "./api/client";
import { useEmailStore } from "./store/emailStore";
import Sidebar from "./components/layout/Sidebar";
import AssistantPanel from "./components/layout/AssistantPanel";
import LoginPage from "./pages/LoginPage";
import DashboardPage from "./pages/DashboardPage";
import EmailsPage from "./pages/EmailsPage";
import InsightsPage from "./pages/InsightsPage";
import SelectedForDeletionPage from "./pages/SelectedForDeletionPage";
import SettingsPage from "./pages/SettingsPage";

function ProtectedRoute({ children }) {
  const isAuthenticated = useEmailStore((state) => state.isAuthenticated);
  const authChecked = useEmailStore((state) => state.authChecked);

  if (!authChecked) {
    return <div className="app-boot-screen">Verifying workspace access...</div>;
  }

  return isAuthenticated ? children : <Navigate to="/login" replace />;
}

function PublicOnlyRoute({ children }) {
  const isAuthenticated = useEmailStore((state) => state.isAuthenticated);
  const authChecked = useEmailStore((state) => state.authChecked);

  if (!authChecked) {
    return <div className="app-boot-screen">Loading MailMind...</div>;
  }

  return isAuthenticated ? <Navigate to="/dashboard" replace /> : children;
}

function AppLayout({ children }) {
  return (
    <div className="shell">
      <Sidebar />
      <main className="shell-main">{children}</main>
      <AssistantPanel />
    </div>
  );
}

export default function App() {
  const setAuthenticated = useEmailStore((state) => state.setAuthenticated);

  useEffect(() => {
    let cancelled = false;
    const params = new URLSearchParams(window.location.search);
    const authSuccess = params.get("auth") === "success";
    const storedAuthHint = window.localStorage.getItem("mailmind_auth_hint") === "true";

    if (authSuccess) {
      setAuthenticated(true);
      window.localStorage.setItem("mailmind_auth_hint", "true");
      params.delete("auth");
      const nextSearch = params.toString();
      const nextUrl = `${window.location.pathname}${nextSearch ? `?${nextSearch}` : ""}${window.location.hash}`;
      window.history.replaceState({}, "", nextUrl);
    } else if (storedAuthHint) {
      setAuthenticated(true);
    }

    const bootstrapAuth = async () => {
      try {
        const response = await Promise.race([
          authApi.status(),
          new Promise((_, reject) => {
            window.setTimeout(() => reject(new Error("auth-timeout")), 5000);
          }),
        ]);

        if (!cancelled) {
          const authenticated = authSuccess || response.data.authenticated || storedAuthHint;
          if (authenticated) {
            window.localStorage.setItem("mailmind_auth_hint", "true");
          } else {
            window.localStorage.removeItem("mailmind_auth_hint");
          }
          setAuthenticated(authenticated);
        }
      } catch {
        if (!cancelled) {
          setAuthenticated(authSuccess || storedAuthHint);
        }
      }
    };

    bootstrapAuth();

    return () => {
      cancelled = true;
    };
  }, [setAuthenticated]);

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={<PublicOnlyRoute><LoginPage /></PublicOnlyRoute>} />
        <Route path="/dashboard" element={<ProtectedRoute><AppLayout><DashboardPage /></AppLayout></ProtectedRoute>} />
        <Route path="/inbox" element={<ProtectedRoute><AppLayout><EmailsPage mailbox="inbox" title="Inbox" /></AppLayout></ProtectedRoute>} />
        <Route path="/sent" element={<ProtectedRoute><AppLayout><EmailsPage mailbox="sent" title="Sent" /></AppLayout></ProtectedRoute>} />
        <Route path="/drafts" element={<ProtectedRoute><AppLayout><EmailsPage mailbox="drafts" title="Drafts" /></AppLayout></ProtectedRoute>} />
        <Route path="/spam" element={<ProtectedRoute><AppLayout><EmailsPage mailbox="spam" title="Spam" /></AppLayout></ProtectedRoute>} />
        <Route path="/trash" element={<ProtectedRoute><AppLayout><EmailsPage mailbox="trash" title="Trash" /></AppLayout></ProtectedRoute>} />
        <Route path="/ai-suggestions" element={<ProtectedRoute><AppLayout><SelectedForDeletionPage mode="suggestions" /></AppLayout></ProtectedRoute>} />
        <Route path="/selected-for-deletion" element={<ProtectedRoute><AppLayout><SelectedForDeletionPage mode="cleanup" /></AppLayout></ProtectedRoute>} />
        <Route path="/analytics" element={<ProtectedRoute><AppLayout><InsightsPage /></AppLayout></ProtectedRoute>} />
        <Route path="/settings" element={<ProtectedRoute><AppLayout><SettingsPage /></AppLayout></ProtectedRoute>} />
        <Route path="/emails" element={<Navigate to="/inbox" replace />} />
        <Route path="/insights" element={<Navigate to="/analytics" replace />} />
        <Route path="*" element={<Navigate to="/dashboard" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
