"use client";

import { Scholarship } from "@/types";
import { X, ExternalLink, Calendar, MapPin, CheckCircle2, Sparkles, BookOpen, ShieldCheck, DollarSign } from "lucide-react";

interface Props {
  scholarship: Scholarship | null;
  onClose: () => void;
  onApply?: (scholarship: Scholarship) => void;
  onOpenFlyAgent?: (scholarship: Scholarship) => void;
}

export default function ScholarshipDetailModal({ scholarship, onClose, onApply, onOpenFlyAgent }: Props) {
  if (!scholarship) return null;

  const score = scholarship.matchScore || 85;
  const breakdown = scholarship.matchBreakdown;

  return (
    <div style={{
      position: "fixed",
      inset: 0,
      zIndex: 50,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      padding: "16px",
      background: "rgba(0, 0, 0, 0.65)",
    }}>
      <div style={{
        position: "relative",
        width: "100%",
        maxWidth: "720px",
        maxHeight: "88vh",
        background: "var(--warm-50)",
        border: "1px solid var(--border)",
        borderRadius: "20px",
        boxShadow: "var(--shadow-xl)",
        overflow: "hidden",
        display: "flex",
        flexDirection: "column",
        color: "var(--ink-text)",
      }}>
        {/* Header */}
        <div style={{
          padding: "20px 24px",
          background: "var(--warm-100)",
          borderBottom: "1px solid var(--border)",
          display: "flex",
          alignItems: "flex-start",
          justifyContent: "space-between",
          gap: "16px"
        }}>
          <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
            <div style={{ display: "flex", alignItems: "center", gap: "8px", flexWrap: "wrap" }}>
              <span style={{
                padding: "3px 10px",
                fontSize: "0.72rem",
                fontWeight: 800,
                borderRadius: "9999px",
                background: "var(--accent-light)",
                color: "var(--accent)",
                border: "1px solid var(--accent-200)"
              }}>
                Compatibilité {score}%
              </span>

              <span style={{
                padding: "3px 10px",
                fontSize: "0.72rem",
                fontWeight: 700,
                borderRadius: "9999px",
                background: "var(--success-light)",
                color: "var(--success)",
                border: "1px solid var(--success-200)",
                textTransform: "uppercase"
              }}>
                {scholarship.financement === "TOTAL" ? "Financement Total" : "Financement Partiel"}
              </span>
            </div>

            <h2 style={{ fontSize: "1.25rem", fontWeight: 800, color: "var(--ink-text)", margin: 0, lineHeight: 1.3 }}>
              {scholarship.titre}
            </h2>

            <div style={{ display: "flex", alignItems: "center", gap: "12px", fontSize: "0.75rem", color: "var(--ink-muted)", flexWrap: "wrap" }}>
              {scholarship.pays_destination && scholarship.pays_destination.length > 0 && (
                <span>📍 {scholarship.pays_destination.join(", ")}</span>
              )}
              {scholarship.deadline && (
                <span style={{ color: "var(--warning)", fontWeight: 700 }}>
                  ⏳ Date limite : {new Date(scholarship.deadline).toLocaleDateString("fr-FR")}
                </span>
              )}
            </div>
          </div>

          <button
            onClick={onClose}
            style={{
              padding: "8px",
              borderRadius: "50%",
              background: "var(--warm-200)",
              color: "var(--ink-text)",
              border: "none",
              cursor: "pointer",
              flexShrink: 0
            }}
            title="Fermer"
          >
            <X size={18} />
          </button>
        </div>

        {/* Modal Scrollable Content Body */}
        <div className="custom-scrollbar" style={{ flex: 1, padding: "20px 24px", overflowY: "auto", display: "flex", flexDirection: "column", gap: "20px" }}>
          
          {/* Match Score Decomposition */}
          {breakdown && (
            <div style={{
              padding: "16px",
              borderRadius: "14px",
              background: "var(--warm-100)",
              border: "1px solid var(--border)",
              display: "flex",
              flexDirection: "column",
              gap: "10px"
            }}>
              <h4 style={{ fontSize: "0.75rem", fontWeight: 800, textTransform: "uppercase", letterSpacing: "0.04em", color: "var(--accent)", margin: 0, display: "flex", alignItems: "center", gap: "6px" }}>
                <ShieldCheck size={16} /> Audit d'éligibilité avec votre profil
              </h4>
              
              <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(130px, 1fr))", gap: "8px", fontSize: "0.75rem" }}>
                <div style={{ padding: "8px 10px", borderRadius: "10px", background: "var(--warm-50)", border: "1px solid var(--border)" }}>
                  <div style={{ color: "var(--ink-subtle)", fontSize: "0.68rem" }}>Niveau d'étude</div>
                  <div style={{ fontWeight: 700, color: "var(--ink-text)" }}>{breakdown.degreeMatch ? "✓ Compatible" : "⚠️ Différent"}</div>
                </div>
                <div style={{ padding: "8px 10px", borderRadius: "10px", background: "var(--warm-50)", border: "1px solid var(--border)" }}>
                  <div style={{ color: "var(--ink-subtle)", fontSize: "0.68rem" }}>Domaine / Spécialité</div>
                  <div style={{ fontWeight: 700, color: "var(--ink-text)" }}>{breakdown.domainMatch ? "✓ Correspondant" : "✓ Proche"}</div>
                </div>
                <div style={{ padding: "8px 10px", borderRadius: "10px", background: "var(--warm-50)", border: "1px solid var(--border)" }}>
                  <div style={{ color: "var(--ink-subtle)", fontSize: "0.68rem" }}>Pays destination</div>
                  <div style={{ fontWeight: 700, color: "var(--ink-text)" }}>{breakdown.countryMatch ? "✓ Destination cible" : "🌍 Ouvert"}</div>
                </div>
                <div style={{ padding: "8px 10px", borderRadius: "10px", background: "var(--warm-50)", border: "1px solid var(--border)" }}>
                  <div style={{ color: "var(--ink-subtle)", fontSize: "0.68rem" }}>Financement</div>
                  <div style={{ fontWeight: 700, color: "var(--success)" }}>{breakdown.fundingMatch ? "100% Inclus" : "Partiel"}</div>
                </div>
              </div>

              {breakdown.reasons && breakdown.reasons.length > 0 && (
                <div style={{ display: "flex", flexDirection: "column", gap: "4px", paddingTop: "4px" }}>
                  {breakdown.reasons.map((reason, idx) => (
                    <div key={idx} style={{ display: "flex", alignItems: "center", gap: "6px", fontSize: "0.75rem", color: "var(--accent)" }}>
                      <CheckCircle2 size={14} style={{ flexShrink: 0 }} />
                      <span>{reason}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* Description Section */}
          <div>
            <h3 style={{ fontSize: "0.8rem", fontWeight: 800, textTransform: "uppercase", letterSpacing: "0.04em", color: "var(--ink-subtle)", margin: "0 0 8px 0" }}>
              Description officielle de l'opportunité
            </h3>
            <p style={{
              fontSize: "0.85rem",
              lineHeight: 1.6,
              color: "var(--ink-text)",
              background: "var(--warm-100)",
              padding: "16px",
              borderRadius: "14px",
              border: "1px solid var(--border)",
              margin: 0,
              whiteSpace: "pre-line"
            }}>
              {scholarship.description || "Aucune description détaillée disponible pour cette opportunité."}
            </p>
          </div>

          {/* Domains & Required Degrees */}
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "16px" }}>
            {scholarship.domaines && scholarship.domaines.length > 0 && (
              <div>
                <h4 style={{ fontSize: "0.75rem", fontWeight: 800, textTransform: "uppercase", color: "var(--ink-subtle)", margin: "0 0 6px 0" }}>Domaines d'études</h4>
                <div style={{ display: "flex", flexWrap: "wrap", gap: "4px" }}>
                  {scholarship.domaines.map((d, i) => (
                    <span key={i} style={{ padding: "4px 8px", fontSize: "0.72rem", borderRadius: "6px", background: "var(--warm-100)", border: "1px solid var(--border)", color: "var(--ink-text)", fontWeight: 600 }}>
                      {d}
                    </span>
                  ))}
                </div>
              </div>
            )}

            {scholarship.niveau_etude && scholarship.niveau_etude.length > 0 && (
              <div>
                <h4 style={{ fontSize: "0.75rem", fontWeight: 800, textTransform: "uppercase", color: "var(--ink-subtle)", margin: "0 0 6px 0" }}>Niveaux requis</h4>
                <div style={{ display: "flex", flexWrap: "wrap", gap: "4px" }}>
                  {scholarship.niveau_etude.map((n, i) => (
                    <span key={i} style={{ padding: "4px 8px", fontSize: "0.72rem", borderRadius: "6px", background: "var(--warm-100)", border: "1px solid var(--border)", color: "var(--ink-text)", fontWeight: 700, textTransform: "uppercase" }}>
                      {n}
                    </span>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Footer Action Buttons */}
        <div style={{
          padding: "16px 24px",
          background: "var(--warm-100)",
          borderTop: "1px solid var(--border)",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          gap: "12px",
          flexWrap: "wrap"
        }}>
          <button
            onClick={onClose}
            className="btn-secondary"
            style={{ padding: "8px 16px", fontSize: "0.8rem" }}
          >
            Fermer
          </button>

          <div style={{ display: "flex", alignItems: "center", gap: "8px", flexWrap: "wrap" }}>
            {onOpenFlyAgent && (
              <button
                onClick={() => {
                  onClose();
                  onOpenFlyAgent(scholarship);
                }}
                className="btn-primary"
                style={{ padding: "8px 16px", fontSize: "0.8rem" }}
              >
                <span>Postuler avec FlyAgent</span>
              </button>
            )}

            {(scholarship.lien_candidature || scholarship.url) && (
              <a
                href={scholarship.lien_candidature || scholarship.url}
                target="_blank"
                rel="noopener noreferrer"
                className="btn-secondary"
                style={{ padding: "8px 14px", fontSize: "0.8rem", display: "inline-flex", alignItems: "center", gap: "6px", textDecoration: "none" }}
              >
                <span>Site officiel</span>
                <ExternalLink size={14} />
              </a>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
