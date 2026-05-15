import { BrowserRouter, Routes, Route, Navigate, useLocation } from "react-router-dom";
import { useEffect, useState } from "react";
import { authApi } from "./api/client";
import { useEmailStore } from "./store/emailStore";
import Sidebar from "./components/layout/Sidebar";
import LoginPage from "./pages/LoginPage";
import DashboardPage from "./pages/DashboardPage";
import EmailsPage from "./pages/EmailsPage";
import InsightsPage from "./pages/InsightsPage";

function AppLayout({ children }) {
  return (
    <div style={{ display: "flex", minHeight: "100vh" }}>
      <Sidebar />
      <div style={{ flex: 1, display: "flex", flexDirection: "column" }}>
        {children}
      </div>
    </div>
  );
}

function ProtectedRoute({ children }) {
  const isAuthenticated = useEmailStore((s) => s.isAuthenticated);
  console.log('ProtectedRoute check - isAuthenticated:', isAuthenticated);
  return isAuthenticated ? children : <Navigate to="/login" replace />;
}

function AppContent() {
  const location = useLocation();
  const { setAuthenticated, isAuthenticated } = useEmailStore();
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    console.log('Checking auth status for path:', location.pathname);
    setIsLoading(true);
    authApi.status()
      .then((res) => {
        console.log('Auth status response:', res.data);
        setAuthenticated(res.data.authenticated);
      })
      .catch((err) => {
        console.error('Auth check failed:', err);
        setAuthenticated(false);
      })
      .finally(() => {
        setIsLoading(false);
      });
  }, [location.pathname]);

  if (isLoading) {
    return (
      <div style={{ minHeight: "100vh", display: "grid", placeItems: "center" }}>
        <div>Loading...</div>
      </div>
    );
  }

  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route path="/dashboard" element={<ProtectedRoute><AppLayout><DashboardPage /></AppLayout></ProtectedRoute>} />
      <Route path="/emails"    element={<ProtectedRoute><AppLayout><EmailsPage /></AppLayout></ProtectedRoute>} />
      <Route path="/insights"  element={<ProtectedRoute><AppLayout><InsightsPage /></AppLayout></ProtectedRoute>} />
      <Route path="*" element={<Navigate to="/dashboard" replace />} />
    </Routes>
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AppContent />
    </BrowserRouter>
  );
}
