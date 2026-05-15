import { Mail, Sparkles } from "lucide-react";
import { authApi } from "../api/client";

export default function LoginPage() {
  return (
    <div style={{ minHeight: "100vh", display: "grid", placeItems: "center",
      background: "var(--bg-primary)" }}>
      <div style={{ textAlign: "center", maxWidth: 400 }}>
        <div style={{ width: 64, height: 64, borderRadius: 16, background: "var(--accent)",
          display: "grid", placeItems: "center", margin: "0 auto 24px" }}>
          <Mail size={28} color="#fff" />
        </div>
        <h1 style={{ fontSize: 28, fontWeight: 600, marginBottom: 10 }}>MailMind</h1>
        <p style={{ color: "var(--text-muted)", marginBottom: 32, lineHeight: 1.7 }}>
          AI-powered email assistant that learns your habits and keeps your inbox under control.
        </p>
        <a href={authApi.loginUrl()} style={{
          display: "inline-flex", alignItems: "center", gap: 10,
          padding: "12px 28px", background: "var(--accent)", color: "#fff",
          borderRadius: 10, fontWeight: 500, fontSize: 15, textDecoration: "none",
          transition: "opacity .15s",
        }}
        onMouseEnter={e => e.currentTarget.style.opacity = ".85"}
        onMouseLeave={e => e.currentTarget.style.opacity = "1"}>
          <Sparkles size={16} /> Connect Gmail
        </a>
        <p style={{ fontSize: 12, color: "var(--text-muted)", marginTop: 20 }}>
          We only read email metadata — we never store full email bodies.
        </p>
      </div>
    </div>
  );
}
