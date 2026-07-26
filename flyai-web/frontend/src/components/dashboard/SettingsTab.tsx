"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { Settings, Sun, Moon, Globe, Shield, Bell, FileText, CheckCircle2 } from "lucide-react";

interface Props {
  theme: "light" | "dark";
  onToggleTheme: () => void;
}

export default function SettingsTab({ theme, onToggleTheme }: Props) {
  const [language, setLanguage] = useState("fr");
  const [notifications, setNotifications] = useState(true);
  const [saved, setSaved] = useState(false);

  const handleSave = () => {
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  };

  return (
    <div style={{ maxWidth: "800px", margin: "0 auto", display: "flex", flexDirection: "column", gap: "var(--space-8)", color: "var(--ink-text)" }}>
      {/* Banner */}
      <div style={{ background: "var(--warm-100)", backdropFilter: "blur(12px)", border: "1px solid var(--border)", borderRadius: "var(--radius-2xl)", padding: "var(--space-6)", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <div>
          <h2 style={{ fontSize: "var(--text-h1)", fontWeight: 700, color: "var(--ink-text)", display: "flex", alignItems: "center", gap: "var(--space-2)", margin: 0 }}>
            <Settings style={{ width: "24px", height: "24px", color: "var(--accent)" }} /> Paramètres & Préférences
          </h2>
          <p style={{ fontSize: "var(--text-body)", color: "var(--ink-muted)", marginTop: "var(--space-1)" }}>
            Personnalise ton expérience d'application, thème et notifications.
          </p>
        </div>
      </div>

      {/* Theme & Appearance */}
      <div style={{ background: "var(--warm-100)", border: "1px solid var(--border)", borderRadius: "var(--radius-2xl)", padding: "var(--space-6)", display: "flex", flexDirection: "column", gap: "var(--space-4)" }}>
        <h3 style={{ fontWeight: 700, color: "var(--ink-text)", fontSize: "var(--text-body)", paddingBottom: "var(--space-3)", borderBottom: "1px solid var(--border)", display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
          {theme === "light" ? <Sun style={{ width: "20px", height: "20px", color: "var(--warning)" }} /> : <Moon style={{ width: "20px", height: "20px", color: "var(--accent)" }} />} Thème & Apparence
        </h3>

        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "var(--space-4)", borderRadius: "var(--radius-xl)", background: "var(--warm-50)", border: "1px solid var(--border)" }}>
          <div>
            <div style={{ fontWeight: 700, fontSize: "var(--text-body)", color: "var(--ink-text)" }}>Mode d'affichage</div>
            <div style={{ fontSize: "var(--text-caption)", color: "var(--ink-muted)" }}>
              {theme === "light" ? "Mode Clair actif (par défaut)" : "Mode Sombre actif"}
            </div>
          </div>

          <button
            onClick={onToggleTheme}
            className="btn-primary"
            style={{ padding: "var(--space-2) var(--space-4)", borderRadius: "var(--radius-xl)", fontWeight: 700, fontSize: "var(--text-caption)", boxShadow: "var(--shadow-md)" }}
          >
            {theme === "light" ? (
              <>
                <Moon style={{ width: "16px", height: "16px" }} />
                <span>Passer en Mode Sombre</span>
              </>
            ) : (
              <>
                <Sun style={{ width: "16px", height: "16px" }} />
                <span>Passer en Mode Clair</span>
              </>
            )}
          </button>
        </div>
      </div>

      {/* Language */}
      <div style={{ background: "var(--warm-100)", border: "1px solid var(--border)", borderRadius: "var(--radius-2xl)", padding: "var(--space-6)", display: "flex", flexDirection: "column", gap: "var(--space-4)" }}>
        <h3 style={{ fontWeight: 700, color: "var(--ink-text)", fontSize: "var(--text-body)", paddingBottom: "var(--space-3)", borderBottom: "1px solid var(--border)", display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
          <Globe style={{ width: "20px", height: "20px", color: "var(--accent)" }} /> Langue de l'interface
        </h3>

        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "var(--space-4)" }}>
          <button
            onClick={() => setLanguage("fr")}
            style={{
              padding: "var(--space-4)",
              borderRadius: "var(--radius-xl)",
              border: "1px solid",
              textAlign: "left",
              fontWeight: 700,
              fontSize: "var(--text-caption)",
              transition: "all var(--transition-base)",
              background: language === "fr" ? "var(--accent)" : "var(--warm-50)",
              color: language === "fr" ? "var(--accent-text)" : "var(--ink-muted)",
              borderColor: language === "fr" ? "var(--accent)" : "var(--border)",
              boxShadow: language === "fr" ? "var(--shadow-md)" : "none"
            }}
            onMouseEnter={(e) => {
              if (language !== "fr") {
                (e.currentTarget as HTMLButtonElement).style.color = "var(--ink-text)";
                (e.currentTarget as HTMLButtonElement).style.borderColor = "var(--accent)";
              }
            }}
            onMouseLeave={(e) => {
              if (language !== "fr") {
                (e.currentTarget as HTMLButtonElement).style.color = "var(--ink-muted)";
                (e.currentTarget as HTMLButtonElement).style.borderColor = "var(--border)";
              }
            }}
          >
            🇫🇷 Français (Default)
          </button>

          <button
            onClick={() => setLanguage("en")}
            style={{
              padding: "var(--space-4)",
              borderRadius: "var(--radius-xl)",
              border: "1px solid",
              textAlign: "left",
              fontWeight: 700,
              fontSize: "var(--text-caption)",
              transition: "all var(--transition-base)",
              background: language === "en" ? "var(--accent)" : "var(--warm-50)",
              color: language === "en" ? "var(--accent-text)" : "var(--ink-muted)",
              borderColor: language === "en" ? "var(--accent)" : "var(--border)",
              boxShadow: language === "en" ? "var(--shadow-md)" : "none"
            }}
            onMouseEnter={(e) => {
              if (language !== "en") {
                (e.currentTarget as HTMLButtonElement).style.color = "var(--ink-text)";
                (e.currentTarget as HTMLButtonElement).style.borderColor = "var(--accent)";
              }
            }}
            onMouseLeave={(e) => {
              if (language !== "en") {
                (e.currentTarget as HTMLButtonElement).style.color = "var(--ink-muted)";
                (e.currentTarget as HTMLButtonElement).style.borderColor = "var(--border)";
              }
            }}
          >
            🇬🇧 English
          </button>
        </div>
      </div>

      {/* Terms & Legal */}
      <div style={{ background: "var(--warm-100)", border: "1px solid var(--border)", borderRadius: "var(--radius-2xl)", padding: "var(--space-6)", display: "flex", flexDirection: "column", gap: "var(--space-4)" }}>
        <h3 style={{ fontWeight: 700, color: "var(--ink-text)", fontSize: "var(--text-body)", paddingBottom: "var(--space-3)", borderBottom: "1px solid var(--border)", display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
          <FileText style={{ width: "20px", height: "20px", color: "var(--success)" }} /> Informations Légales
        </h3>

        <Link
          href="/terms"
          style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "var(--space-4)", borderRadius: "var(--radius-xl)", background: "var(--warm-50)", border: "1px solid var(--border)", transition: "all var(--transition-base)", textDecoration: "none", color: "inherit" }}
          onMouseEnter={(e) => { (e.currentTarget as HTMLAnchorElement).style.borderColor = "var(--accent)"; }}
          onMouseLeave={(e) => { (e.currentTarget as HTMLAnchorElement).style.borderColor = "var(--border)"; }}
        >
          <span style={{ fontWeight: 700, fontSize: "var(--text-caption)", color: "var(--ink-text)" }}>Conditions Générales d'Utilisation & Confidentialité</span>
          <span style={{ fontSize: "var(--text-caption)", color: "var(--accent)", fontWeight: 700 }}>&rarr; Voir la page</span>
        </Link>
      </div>
    </div>
  );
}
