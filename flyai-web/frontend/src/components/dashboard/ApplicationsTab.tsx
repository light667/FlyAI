"use client";

import { useState, useEffect } from "react";
import { Application } from "@/types";
import { Briefcase, Calendar, CheckSquare, Square, X, ExternalLink } from "lucide-react";

interface Props {
  userId?: string;
}

const COLUMNS: { id: Application["status"]; label: string; accent: string }[] = [
  { id: "draft",       label: "Brouillon",    accent: "var(--ink-subtle)" },
  { id: "in_progress", label: "En cours",     accent: "var(--accent)" },
  { id: "submitted",   label: "Soumise",      accent: "#d97706" },
  { id: "accepted",    label: "Acceptee",     accent: "var(--accent)" },
];

const CHECKLIST_ITEMS = [
  { key: "cv_uploaded",       label: "CV academique (2 pages max)",                    is_eliminating: true },
  { key: "motivation_letter", label: "Lettre de motivation",                            is_eliminating: true },
  { key: "transcripts",       label: "Releves de notes certifies",                     is_eliminating: true },
  { key: "recommendation_1",  label: "Lettre de recommandation — Ref. 1",              is_eliminating: true },
  { key: "recommendation_2",  label: "Lettre de recommandation — Ref. 2",              is_eliminating: false },
  { key: "language_test",     label: "Resultat test de langue (TOEFL/IELTS/DELF)",     is_eliminating: false },
];

function daysUntil(dateStr?: string | null): number | null {
  if (!dateStr) return null;
  return Math.ceil((new Date(dateStr).getTime() - Date.now()) / (1000 * 60 * 60 * 24));
}

function DeadlineBadge({ dateStr }: { dateStr?: string | null }) {
  const days = daysUntil(dateStr);
  if (days === null) return null;
  const color = days <= 7 ? "var(--alert)" : days <= 21 ? "#d97706" : "var(--ink-subtle)";
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 4 }}>
      <Calendar size={11} style={{ color }} />
      <span style={{ fontSize: "10px", fontWeight: 600, color }}>
        {days <= 0 ? "Deadline depassee" : `J-${days}`}
      </span>
    </div>
  );
}

export default function ApplicationsTab({ userId }: Props) {
  const [applications, setApplications] = useState<Application[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeApp, setActiveApp] = useState<Application | null>(null);
  const [showRejected, setShowRejected] = useState(false);

  useEffect(() => {
    if (!userId) return;
    setLoading(true);
    fetch(`/api/applications?userId=${userId}`)
      .then((r) => r.json())
      .then((j) => { if (j.data) setApplications(j.data); })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [userId]);

  const toggleItem = async (app: Application, key: string) => {
    const updated = { ...app.checklist, [key]: !(app.checklist as any)[key] };
    setApplications((prev) => prev.map((a) => a.id === app.id ? { ...a, checklist: updated } : a));
    setActiveApp((a) => a?.id === app.id ? { ...a, checklist: updated } : a);
    try {
      await fetch("/api/applications", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userId: app.userId || userId, bourseId: app.bourseId, status: app.status, checklist: updated }),
      });
    } catch (e) { console.error(e); }
  };

  const updateStatus = async (app: Application, newStatus: Application["status"]) => {
    setApplications((prev) => prev.map((a) => a.id === app.id ? { ...a, status: newStatus } : a));
    try {
      await fetch("/api/applications", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userId: app.userId || userId, bourseId: app.bourseId, status: newStatus, checklist: app.checklist }),
      });
    } catch (e) { console.error(e); }
  };

  const rejected = applications.filter((a) => a.status === "rejected");
  const visible = applications.filter((a) => a.status !== "rejected");

  if (loading) {
    return (
      <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-6)" }}>
        <div className="skeleton" style={{ height: 72, borderRadius: "var(--radius)" }} />
        <div style={{ display: "grid", gridTemplateColumns: "repeat(4,1fr)", gap: "var(--space-4)" }}>
          {[1,2,3,4].map((i) => <div key={i} className="skeleton" style={{ height: 200, borderRadius: "var(--radius)" }} />)}
        </div>
      </div>
    );
  }

  return (
    <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-6)" }}>

      {/* Header */}
      <div className="card" style={{ display: "flex", alignItems: "center", justifyContent: "space-between", padding: "var(--space-4) var(--space-6)" }}>
        <div style={{ display: "flex", alignItems: "center", gap: "var(--space-3)" }}>
          <Briefcase size={18} style={{ color: "var(--ink-700)" }} />
          <div>
            <h2 style={{ fontFamily: "var(--font-display)", fontSize: "var(--text-h1)", fontWeight: 400, margin: 0, color: "var(--ink-text)" }}>
              Mes candidatures
            </h2>
            <p style={{ fontSize: "var(--text-caption)", color: "var(--ink-muted)", margin: 0 }}>
              Suivez l avancement de chaque dossier et les prochaines actions
            </p>
          </div>
        </div>
        <span style={{ fontSize: "var(--text-caption)", fontWeight: 700, padding: "4px 10px", borderRadius: "var(--radius-sm)", border: "1px solid var(--border)", color: "var(--ink-muted)" }}>
          {visible.length} active{visible.length > 1 ? "s" : ""}
        </span>
      </div>

      {applications.length === 0 ? (
        <div style={{ padding: "var(--space-8)", textAlign: "center", background: "var(--warm-100)", border: "1px solid var(--border)", borderRadius: "var(--radius)" }}>
          <CheckSquare size={32} style={{ color: "var(--ink-subtle)", margin: "0 auto var(--space-4)" }} />
          <h3 style={{ fontFamily: "var(--font-display)", fontSize: "var(--text-h1)", fontWeight: 400, color: "var(--ink-text)", margin: "0 0 var(--space-2)" }}>
            Aucune candidature en cours
          </h3>
          <p style={{ fontSize: "var(--text-body)", color: "var(--ink-muted)", maxWidth: 420, margin: "0 auto" }}>
            Selectionnez une bourse dans l onglet "Mes meilleures options" et cliquez sur "Preparer ce dossier" pour demarrer.
          </p>
        </div>
      ) : (
        <>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(4,1fr)", gap: "var(--space-4)", overflowX: "auto" }}>
            {COLUMNS.map((col) => {
              const colApps = visible.filter((a) => a.status === col.id);
              return (
                <div key={col.id} style={{ background: "var(--warm-100)", border: "1px solid var(--border)", borderRadius: "var(--radius)", padding: "var(--space-4)", minWidth: 220, display: "flex", flexDirection: "column", gap: "var(--space-3)" }}>
                  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                    <span style={{ fontSize: "var(--text-caption)", fontWeight: 700, padding: "2px 8px", borderRadius: "var(--radius-sm)", border: `1px solid ${col.accent}`, color: col.accent, textTransform: "uppercase", letterSpacing: "0.04em" }}>
                      {col.label}
                    </span>
                    <span style={{ fontSize: "var(--text-caption)", color: "var(--ink-subtle)", fontWeight: 600 }}>{colApps.length}</span>
                  </div>
                  <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-3)" }}>
                    {colApps.map((app) => {
                      const cl = app.checklist || {};
                      const checked = Object.values(cl).filter(Boolean).length;
                      const total = Math.max(Object.keys(cl).length, CHECKLIST_ITEMS.length);
                      const pct = Math.round((checked / total) * 100);
                      const days = daysUntil(app.bourse?.deadline);
                      const crit = days !== null && days <= 7;
                      return (
                        <div key={app.id} onClick={() => setActiveApp(app)} style={{ background: "var(--warm-50)", border: `1px solid ${crit ? "var(--alert)" : "var(--border)"}`, borderRadius: "var(--radius)", padding: "var(--space-4)", cursor: "pointer", boxShadow: "var(--shadow-sm)", display: "flex", flexDirection: "column", gap: "var(--space-3)", transition: "box-shadow var(--transition-base)" }} onMouseEnter={(e) => (e.currentTarget.style.boxShadow = "var(--shadow-md)")} onMouseLeave={(e) => (e.currentTarget.style.boxShadow = "var(--shadow-sm)")}>
                          <h4 style={{ fontSize: "var(--text-body)", fontWeight: 600, color: "var(--ink-text)", margin: 0, overflow: "hidden", display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical" }}>
                            {app.bourse?.titre || "Bourse d etudes"}
                          </h4>
                          <div>
                            <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 4 }}>
                              <span style={{ fontSize: "10px", color: "var(--ink-subtle)" }}>Documents</span>
                              <span style={{ fontSize: "10px", fontWeight: 600, color: "var(--ink-muted)" }}>{checked}/{total}</span>
                            </div>
                            <div className="score-gauge">
                              <div className="score-gauge-fill" style={{ width: `${pct}%` }} />
                            </div>
                          </div>
                          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", paddingTop: "var(--space-2)", borderTop: "1px solid var(--border-subtle)" }}>
                            <DeadlineBadge dateStr={app.bourse?.deadline} />
                            <select value={app.status} onChange={(e) => { e.stopPropagation(); updateStatus(app, e.target.value as Application["status"]); }} onClick={(e) => e.stopPropagation()} style={{ fontSize: "10px", background: "var(--warm-100)", border: "1px solid var(--border)", borderRadius: "var(--radius-sm)", color: "var(--ink-muted)", padding: "2px 4px", cursor: "pointer" }}>
                              {[...COLUMNS, { id: "rejected" as const, label: "Refusee", accent: "var(--alert)" }].map((c) => (
                                <option key={c.id} value={c.id}>{c.label}</option>
                              ))}
                            </select>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              );
            })}
          </div>

          {rejected.length > 0 && (
            <div>
              <button onClick={() => setShowRejected((v) => !v)} style={{ fontSize: "var(--text-caption)", color: "var(--ink-subtle)", background: "none", border: "none", cursor: "pointer", marginBottom: "var(--space-3)", display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
                {showRejected ? "Masquer" : `Voir ${rejected.length} candidature${rejected.length > 1 ? "s" : ""} refusee${rejected.length > 1 ? "s" : ""}`}
              </button>
              {showRejected && (
                <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-2)" }}>
                  {rejected.map((app) => (
                    <div key={app.id} style={{ padding: "var(--space-3) var(--space-4)", border: "1px solid var(--border-subtle)", borderRadius: "var(--radius)", background: "var(--warm-100)", opacity: 0.7, display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                      <span style={{ fontSize: "var(--text-body)", color: "var(--ink-muted)" }}>{app.bourse?.titre || "Bourse"}</span>
                      <span style={{ fontSize: "var(--text-caption)", color: "var(--alert)", fontWeight: 600, textTransform: "uppercase" }}>Refusee</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}
        </>
      )}

      {activeApp && (
        <div onClick={() => setActiveApp(null)} style={{ position: "fixed", inset: 0, zIndex: 50, display: "flex", alignItems: "center", justifyContent: "center", padding: "var(--space-4)", background: "rgba(15,26,46,0.6)", backdropFilter: "blur(8px)" }}>
          <div onClick={(e) => e.stopPropagation()} style={{ background: "var(--warm-50)", border: "1px solid var(--border)", borderRadius: "var(--radius-lg)", padding: "var(--space-8)", maxWidth: 540, width: "100%", boxShadow: "var(--shadow-lg)", display: "flex", flexDirection: "column", gap: "var(--space-6)" }}>
            <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between" }}>
              <div>
                <span style={{ fontSize: "var(--text-caption)", color: "var(--ink-subtle)", fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.04em" }}>Dossier de candidature</span>
                <h3 style={{ fontFamily: "var(--font-display)", fontSize: "var(--text-h1)", fontWeight: 400, margin: "4px 0 0", color: "var(--ink-text)" }}>
                  {activeApp.bourse?.titre || "Bourse d etudes"}
                </h3>
                {activeApp.bourse?.deadline && <div style={{ marginTop: "var(--space-2)" }}><DeadlineBadge dateStr={activeApp.bourse.deadline} /></div>}
              </div>
              <button onClick={() => setActiveApp(null)} style={{ background: "none", border: "1px solid var(--border)", borderRadius: "var(--radius-sm)", padding: "4px 8px", color: "var(--ink-subtle)", cursor: "pointer" }}><X size={14} /></button>
            </div>

            <div>
              <p style={{ fontSize: "var(--text-caption)", color: "var(--ink-subtle)", fontWeight: 600, textTransform: "uppercase", letterSpacing: "0.04em", marginBottom: "var(--space-3)" }}>
                Documents requis — * criteres eliminatoires
              </p>
              <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-2)" }}>
                {CHECKLIST_ITEMS.map((item) => {
                  const checked = (activeApp.checklist as any)?.[item.key] || false;
                  return (
                    <div key={item.key} onClick={() => toggleItem(activeApp, item.key)} style={{ display: "flex", alignItems: "center", gap: "var(--space-3)", padding: "var(--space-3) var(--space-4)", borderRadius: "var(--radius)", border: `1px solid ${checked ? "var(--accent)" : "var(--border)"}`, background: checked ? "var(--accent-light)" : "var(--warm-100)", cursor: "pointer", transition: "all var(--transition-base)" }}>
                      {checked ? <CheckSquare size={16} style={{ color: "var(--accent)", flexShrink: 0 }} /> : <Square size={16} style={{ color: "var(--ink-subtle)", flexShrink: 0 }} />}
                      <span style={{ fontSize: "var(--text-body)", fontWeight: item.is_eliminating ? 600 : 400, color: checked ? "var(--accent)" : "var(--ink-text)", flex: 1 }}>
                        {item.label}{item.is_eliminating && " *"}
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>

            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", paddingTop: "var(--space-4)", borderTop: "1px solid var(--border)" }}>
              {activeApp.bourse?.url && (
                <a href={activeApp.bourse.url} target="_blank" rel="noopener noreferrer" style={{ display: "flex", alignItems: "center", gap: "var(--space-2)", fontSize: "var(--text-caption)", color: "var(--accent)", fontWeight: 600, textDecoration: "none" }}>
                  <ExternalLink size={12} /> Voir la bourse officielle
                </a>
              )}
              <button onClick={() => setActiveApp(null)} className="btn-primary" style={{ marginLeft: "auto" }}>Enregistrer et fermer</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
