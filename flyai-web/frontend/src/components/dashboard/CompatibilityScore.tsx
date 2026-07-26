"use client";

import { useEffect, useState } from "react";
import { ThumbsUp, ThumbsDown, ChevronDown, ChevronUp } from "lucide-react";

interface BreakdownItem {
  criterion: string;
  score: number;
  max: number;
  detail: string;
  is_hard_filter: boolean;
}

interface Props {
  bourseId: string;
  userId?: string;
  profile?: any;
  /** Si passé directement (ex: depuis DiscoverTab), pas de fetch */
  precomputed?: {
    overall_score: number;
    summary: string;
    breakdown: BreakdownItem[];
  };
}

/**
 * CompatibilityScore — §4.4
 * Affiche le score de compatibilité (0–100) avec décomposition.
 * Terminologie imposée : "Score de compatibilité", jamais "Probabilité d'admission".
 * Feedback utilisateur (pouce haut/bas) → table matching_feedback §10.2.
 */
export default function CompatibilityScore({ bourseId, userId, profile, precomputed }: Props) {
  const [data, setData] = useState(precomputed || null);
  const [loading, setLoading] = useState(!precomputed);
  const [showBreakdown, setShowBreakdown] = useState(false);
  const [feedbackSent, setFeedbackSent] = useState<"up" | "down" | null>(null);
  const [scoreId, setScoreId] = useState<string | null>(null);

  useEffect(() => {
    if (precomputed || !bourseId || !userId) return;

    setLoading(true);
    fetch("/api/matching/score", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ user_id: userId, bourse_id: bourseId, profile: profile || {} }),
    })
      .then((r) => r.json())
      .then((json) => {
        setData(json);
        setScoreId(json.score_id);
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [scholarshipId, userId, precomputed, profile]);

  const sendFeedback = async (type: "up" | "down") => {
    if (feedbackSent || !userId) return;
    setFeedbackSent(type);
    try {
      await fetch("/api/matching/feedback", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          user_id: userId,
          bourse_id: bourseId,
          score_id: scoreId,
          feedback: type,
        }),
      });
    } catch {
      // Feedback silencieux — ne pas bloquer l'UX
    }
  };

  if (loading) {
    return (
      <div className="space-y-2">
        <div className="skeleton h-3 w-32 rounded" />
        <div className="skeleton h-1.5 w-full rounded" />
        <div className="skeleton h-3 w-24 rounded" />
      </div>
    );
  }

  if (!data) return null;

  const score = data.overall_score;
  const breakdown: BreakdownItem[] = data.breakdown || [];

  // Couleur de la jauge selon le score
  const gaugeColor =
    score >= 75
      ? "var(--accent)"
      : score >= 55
      ? "#d97706"  // ambre — attention mais faisable
      : "var(--alert)";

  const hardFilterFailed = breakdown.some((b) => b.is_hard_filter && b.score === 0);

  return (
    <div className="space-y-2">
      {/* Label §4.4 — jamais "probabilité d'admission" */}
      <div className="flex items-center justify-between">
        <span
          className="text-caption"
          style={{ color: "var(--ink-subtle)", fontSize: "var(--text-caption)", fontWeight: 600 }}
        >
          Score de compatibilité
        </span>
        <span
          className="font-bold tabular-nums"
          style={{
            color: gaugeColor,
            fontSize: "var(--text-h2)",
            lineHeight: 1,
          }}
        >
          {score}
          <span style={{ fontSize: "var(--text-caption)", fontWeight: 400, color: "var(--ink-subtle)" }}>
            /100
          </span>
        </span>
      </div>

      {/* Jauge animée */}
      <div className="score-gauge">
        <div
          className="score-gauge-fill"
          style={{ width: `${score}%`, backgroundColor: gaugeColor }}
        />
      </div>

      {/* Résumé */}
      <p style={{ fontSize: "var(--text-caption)", color: "var(--ink-muted)" }}>
        {hardFilterFailed ? (
          <span style={{ color: "var(--alert)" }}>⚠ {data.summary}</span>
        ) : (
          data.summary
        )}
      </p>

      {/* Toggle décomposition */}
      {breakdown.length > 0 && (
        <button
          onClick={() => setShowBreakdown((v) => !v)}
          style={{
            display: "flex",
            alignItems: "center",
            gap: "4px",
            fontSize: "var(--text-caption)",
            color: "var(--accent)",
            fontWeight: 600,
            background: "none",
            border: "none",
            cursor: "pointer",
            padding: 0,
          }}
        >
          {showBreakdown ? <ChevronUp size={12} /> : <ChevronDown size={12} />}
          {showBreakdown ? "Masquer le détail" : "Voir le détail"}
        </button>
      )}

      {/* Décomposition critère par critère */}
      {showBreakdown && (
        <div
          style={{
            borderTop: "1px solid var(--border-subtle)",
            paddingTop: "var(--space-3)",
            marginTop: "var(--space-2)",
            display: "flex",
            flexDirection: "column",
            gap: "var(--space-2)",
          }}
        >
          {breakdown.map((b) => {
            const itemPercent = b.max > 0 ? (b.score / b.max) * 100 : 0;
            const itemColor = b.score === 0 && b.is_hard_filter ? "var(--alert)" : "var(--accent)";
            return (
              <div key={b.criterion}>
                <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "2px" }}>
                  <span
                    style={{
                      fontSize: "var(--text-caption)",
                      color: b.score === 0 && b.is_hard_filter ? "var(--alert)" : "var(--ink-muted)",
                      fontWeight: b.is_hard_filter ? 600 : 400,
                    }}
                  >
                    {b.criterion}
                    {b.is_hard_filter && " *"}
                  </span>
                  <span style={{ fontSize: "var(--text-caption)", color: itemColor, fontWeight: 600 }}>
                    {b.score}/{b.max}
                  </span>
                </div>
                <div className="score-gauge" style={{ height: "2px" }}>
                  <div
                    className="score-gauge-fill"
                    style={{ width: `${itemPercent}%`, backgroundColor: itemColor }}
                  />
                </div>
                <p style={{ fontSize: "10px", color: "var(--ink-subtle)", marginTop: "2px" }}>{b.detail}</p>
              </div>
            );
          })}
          <p style={{ fontSize: "10px", color: "var(--ink-subtle)", fontStyle: "italic" }}>
            * Critères éliminatoires — un score de 0 plafonne la compatibilité globale.
          </p>
          <p style={{ fontSize: "10px", color: "var(--ink-subtle)", marginTop: "var(--space-1)" }}>
            Ce score mesure l'adéquation de votre profil avec les critères de la bourse.
            Il ne constitue pas une prédiction d'admission.
          </p>

          {/* Feedback §10.2 */}
          {userId && (
            <div style={{ display: "flex", alignItems: "center", gap: "var(--space-2)", marginTop: "var(--space-1)" }}>
              <span style={{ fontSize: "10px", color: "var(--ink-subtle)" }}>Ce score est-il pertinent ?</span>
              <button
                onClick={() => sendFeedback("up")}
                disabled={!!feedbackSent}
                title="Pertinent"
                style={{
                  background: feedbackSent === "up" ? "var(--accent-light)" : "transparent",
                  border: "1px solid var(--border)",
                  borderRadius: "var(--radius-sm)",
                  padding: "2px 6px",
                  cursor: feedbackSent ? "default" : "pointer",
                  color: feedbackSent === "up" ? "var(--accent)" : "var(--ink-subtle)",
                  display: "flex",
                  alignItems: "center",
                }}
              >
                <ThumbsUp size={10} />
              </button>
              <button
                onClick={() => sendFeedback("down")}
                disabled={!!feedbackSent}
                title="Non pertinent"
                style={{
                  background: feedbackSent === "down" ? "var(--alert-light)" : "transparent",
                  border: "1px solid var(--border)",
                  borderRadius: "var(--radius-sm)",
                  padding: "2px 6px",
                  cursor: feedbackSent ? "default" : "pointer",
                  color: feedbackSent === "down" ? "var(--alert)" : "var(--ink-subtle)",
                  display: "flex",
                  alignItems: "center",
                }}
              >
                <ThumbsDown size={10} />
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
