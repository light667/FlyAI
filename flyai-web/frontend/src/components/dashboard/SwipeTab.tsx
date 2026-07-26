"use client";

import { useState, useEffect } from "react";
import { Scholarship, UserProfile } from "@/types";
import { motion, useMotionValue, useTransform, AnimatePresence } from "framer-motion";
import { Heart, X, Star, Sparkles, MapPin, Calendar, BookOpen, ExternalLink, RefreshCcw, ShieldCheck, CheckCircle2 } from "lucide-react";
import ScholarshipDetailModal from "./ScholarshipDetailModal";

interface Props {
  userId?: string;
  userProfile?: UserProfile | null;
  onOpenFlyAgent?: (scholarship: Scholarship) => void;
}

export default function SwipeTab({ userId, userProfile, onOpenFlyAgent }: Props) {
  const [deck, setDeck] = useState<Scholarship[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [loading, setLoading] = useState(true);
  const [lastMatch, setLastMatch] = useState<Scholarship | null>(null);
  const [inspectScholarship, setInspectScholarship] = useState<Scholarship | null>(null);

  // Motion drag values for top card
  const x = useMotionValue(0);
  const rotate = useTransform(x, [-200, 200], [-12, 12]);
  const opacityLike = useTransform(x, [10, 100], [0, 1]);
  const opacitySkip = useTransform(x, [-10, -100], [0, 1]);

  const loadDeck = async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams();
      if (userId) params.append("userId", userId);
      params.append("limit", "50");

      const res = await fetch(`/api/scholarships?${params.toString()}`);
      const json = await res.json();
      if (json.data) {
        // Filter & rank by high matching score for the Matching Deck
        const highMatches = json.data.sort((a: Scholarship, b: Scholarship) => (b.matchScore || 0) - (a.matchScore || 0));
        setDeck(highMatches);
        setCurrentIndex(0);
      }
    } catch (e) {
      console.error("Failed to load matching deck", e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadDeck();
  }, [userId]);

  const handleSwipe = async (direction: "right" | "left" | "superlike") => {
    const currentCard = deck[currentIndex];
    if (!currentCard) return;

    setCurrentIndex((prev) => prev + 1);
    x.set(0);

    if (direction === "right" || direction === "superlike") {
      setLastMatch(currentCard);
    }

    if (userId) {
      try {
        await fetch("/api/swipes", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            userId,
            bourseId: currentCard.id,
            direction,
            score: currentCard.matchScore || 85,
          }),
        });
      } catch (err) {
        console.error("Error saving swipe:", err);
      }
    }
  };

  const currentCard = deck[currentIndex];

  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", minHeight: "75vh", position: "relative", padding: "var(--space-4)", color: "var(--ink-text)", width: "100%", maxWidth: "1200px", margin: "0 auto" }}>
      {/* Title */}
      <div style={{ textAlign: "center", marginBottom: "var(--space-6)", display: "flex", flexDirection: "column", gap: "var(--space-1)" }}>
        <h2 style={{ fontFamily: "var(--font-body)", fontSize: "var(--text-h2)", fontWeight: 700, color: "var(--ink-text)", display: "flex", alignItems: "center", justifyContent: "center", gap: "var(--space-2)", margin: 0 }}>
          <Sparkles style={{ width: "var(--space-6)", height: "var(--space-6)", color: "var(--accent)" }} /> Deck de Matching Avancé
        </h2>
        <p style={{ fontSize: "var(--text-caption)", color: "var(--ink-muted)", margin: 0 }}>
          Les opportunités classées par compatibilité directe avec ton profil académique.
        </p>
      </div>

      {/* Match Animation Modal Overlay */}
      <AnimatePresence>
        {lastMatch && (
          <motion.div
            initial={{ opacity: 0, scale: 0.8 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.8 }}
            style={{ position: "fixed", inset: 0, zIndex: 50, display: "flex", alignItems: "center", justifyContent: "center", padding: "var(--space-4)", background: "rgba(15, 26, 46, 0.6)", backdropFilter: "blur(8px)" }}
          >
            <div style={{ background: "var(--warm-50)", border: "1px solid var(--border)", borderRadius: "var(--radius-2xl)", padding: "var(--space-8)", maxWidth: "448px", width: "100%", textAlign: "center", display: "flex", flexDirection: "column", gap: "var(--space-6)", boxShadow: "var(--shadow-xl)" }}>
              <div style={{ width: "var(--space-20)", height: "var(--space-20)", margin: "0 auto", borderRadius: "var(--radius-full)", background: "var(--gradient-accent)", display: "flex", alignItems: "center", justifyContent: "center", animation: "bounce 1s infinite", boxShadow: "var(--shadow-lg)", color: "var(--accent-text)" }}>
                <Sparkles style={{ width: "var(--space-10)", height: "var(--space-10)" }} />
              </div>

              <div>
                <h3 style={{ fontFamily: "var(--font-body)", fontSize: "var(--text-h1)", fontWeight: 700, color: "var(--ink-text)", margin: 0 }}>Compatible à {lastMatch.matchScore || 90}% !</h3>
                <p style={{ fontSize: "var(--text-body)", color: "var(--ink-muted)", marginTop: "var(--space-2)" }}>
                  <span style={{ fontWeight: 700, color: "var(--accent)" }}>{lastMatch.titre}</span> a été ajoutée à tes candidatures.
                </p>
              </div>

              <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-3)" }}>
                {onOpenFlyAgent && (
                  <button
                    onClick={() => {
                      const m = lastMatch;
                      setLastMatch(null);
                      onOpenFlyAgent(m);
                    }}
                    className="btn-primary"
                    style={{ padding: "var(--space-3.5) var(--space-6)", borderRadius: "var(--radius-2xl)", boxShadow: "var(--shadow-lg)" }}
                  >
                    <Sparkles style={{ width: "var(--space-4)", height: "var(--space-4)", color: "var(--accent-text)" }} />
                    <span>Postuler avec FlyAgent</span>
                  </button>
                )}

                <button
                  onClick={() => setLastMatch(null)}
                  className="btn-secondary"
                  style={{ padding: "var(--space-3) var(--space-6)", borderRadius: "var(--radius-2xl)", fontWeight: 700 }}
                >
                  Continuer le Matching
                </button>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Main Matching Deck Container */}
      <div style={{ position: "relative", width: "100%", maxWidth: "448px", height: "520px", display: "flex", alignItems: "center", justifyContent: "center" }}>
        {loading ? (
          <div style={{ width: "100%", height: "100%", borderRadius: "var(--radius-2xl)", background: "var(--warm-50)", border: "1px solid var(--border)", animation: "pulse 2s ease-in-out infinite", display: "flex", alignItems: "center", justifyContent: "center", color: "var(--ink-muted)", fontSize: "var(--text-caption)", fontWeight: 700 }}>
            Calcul des scores de matching...
          </div>
        ) : !currentCard ? (
          <div style={{ width: "100%", padding: "var(--space-8)", textAlign: "center", background: "var(--warm-50)", border: "1px solid var(--border)", borderRadius: "var(--radius-2xl)", display: "flex", flexDirection: "column", gap: "var(--space-4)", alignItems: "center", justifyContent: "center", boxShadow: "var(--shadow-lg)" }}>
            <Sparkles style={{ width: "var(--space-12)", height: "var(--space-12)", color: "var(--accent)", margin: "0 auto" }} />
            <h3 style={{ fontFamily: "var(--font-body)", fontSize: "var(--text-h1)", fontWeight: 700, color: "var(--ink-text)", margin: 0 }}>Toutes les bourses ont été examinées !</h3>
            <button
              onClick={loadDeck}
              className="btn-primary"
              style={{ padding: "var(--space-3) var(--space-6)", borderRadius: "var(--radius-2xl)", boxShadow: "var(--shadow-lg)" }}
            >
              Recharger le Deck
            </button>
          </div>
        ) : (
          <div style={{ position: "relative", width: "100%", height: "100%" }}>
            {/* Card Preview behind */}
            {deck[currentIndex + 1] && (
              <div style={{ position: "absolute", inset: 0, background: "var(--warm-100)", border: "1px solid var(--border)", borderRadius: "var(--radius-2xl)", transform: "scale(0.95) translateY(12px)", opacity: 0.5, pointerEvents: "none", boxShadow: "var(--shadow-md)" }} />
            )}

            {/* Top Interactive Card */}
            <motion.div
              style={{ x, rotate, position: "absolute", inset: 0, background: "var(--warm-50)", border: "1px solid var(--border)", borderRadius: "var(--radius-2xl)", padding: "var(--space-6)", display: "flex", flexDirection: "column", justifyContent: "space-between", cursor: "grab", boxShadow: "var(--shadow-xl)", overflow: "hidden" }}
              drag="x"
              dragConstraints={{ left: 0, right: 0 }}
              onDragEnd={(_, info) => {
                if (info.offset.x > 120) {
                  handleSwipe("right");
                } else if (info.offset.x < -120) {
                  handleSwipe("left");
                }
              }}
            >
              {/* Swipe Badges */}
              <motion.div
                style={{ opacity: opacityLike, position: "absolute", top: "var(--space-6)", left: "var(--space-6)", zIndex: 20, padding: "var(--space-4) var(--space-10)", background: "var(--success)", color: "var(--accent-text)", fontWeight: 700, fontSize: "var(--text-body)", textTransform: "uppercase", borderRadius: "var(--radius-2xl)", boxShadow: "var(--shadow-xl)", transform: "rotate(-12deg)" }}
              >
                LIKE
              </motion.div>

              <motion.div
                style={{ opacity: opacitySkip, position: "absolute", top: "var(--space-6)", right: "var(--space-6)", zIndex: 20, padding: "var(--space-4) var(--space-10)", background: "var(--alert)", color: "var(--accent-text)", fontWeight: 700, fontSize: "var(--text-body)", textTransform: "uppercase", borderRadius: "var(--radius-2xl)", boxShadow: "var(--shadow-xl)", transform: "rotate(12deg)" }}
              >
                SKIP
              </motion.div>

              {/* Card Body */}
              <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-3)" }}>
                <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                  <span style={{ padding: "var(--space-3.5) var(--space-9)", fontSize: "var(--text-caption)", fontWeight: 700, borderRadius: "var(--radius-full)", background: "var(--accent-50)", color: "var(--accent)", border: "1px solid var(--accent-200)", display: "flex", alignItems: "center", gap: "var(--space-1.5)" }}>
                    <Sparkles style={{ width: "var(--space-3.5)", height: "var(--space-3.5)", color: "var(--accent)" }} />
                    Match Score {currentCard.matchScore || 85}%
                  </span>

                  <span style={{ padding: "var(--space-3) var(--space-9)", fontSize: "11px", fontWeight: 700, borderRadius: "var(--radius-full)", background: "var(--success-light)", color: "var(--success)", border: "1px solid var(--success-200)", textTransform: "uppercase" }}>
                    {currentCard.financement === "TOTAL" ? "100% Financé" : "Partiel"}
                  </span>
                </div>

                <h3 style={{ fontFamily: "var(--font-body)", fontSize: "var(--text-h1)", fontWeight: 700, color: "var(--ink-text)", margin: 0, lineHeight: 1.2 }}>
                  {currentCard.titre}
                </h3>

                <div style={{ display: "flex", flexWrap: "wrap", gap: "var(--space-2)", fontSize: "var(--text-caption)", fontWeight: 600, color: "var(--ink-muted)" }}>
                  <div style={{ display: "flex", alignItems: "center", gap: "var(--space-1)", background: "var(--warm-100)", padding: "var(--space-2.5) var(--space-6)", borderRadius: "var(--radius)" }}>
                    <MapPin style={{ width: "var(--space-3.5)", height: "var(--space-3.5)", color: "var(--accent)" }} />
                    <span>{currentCard.pays_destination?.join(", ") || "International"}</span>
                  </div>

                  {currentCard.deadline && (
                    <div style={{ display: "flex", alignItems: "center", gap: "var(--space-1)", background: "var(--warning-light)", padding: "var(--space-2.5) var(--space-6)", borderRadius: "var(--radius)", color: "var(--warning)" }}>
                      <Calendar style={{ width: "var(--space-3.5)", height: "var(--space-3.5)" }} />
                      <span>{new Date(currentCard.deadline).toLocaleDateString("fr-FR")}</span>
                    </div>
                  )}
                </div>

                {/* Score Reasons */}
                {currentCard.matchBreakdown?.reasons && (
                  <div style={{ padding: "var(--space-3)", borderRadius: "var(--radius-2xl)", background: "var(--accent-50)", border: "1px solid var(--accent-100)", display: "flex", flexDirection: "column", gap: "var(--space-1)" }}>
                    {currentCard.matchBreakdown.reasons.slice(0, 2).map((r, i) => (
                      <div key={i} style={{ display: "flex", alignItems: "center", gap: "var(--space-1.5)", fontSize: "11px", fontWeight: 600, color: "var(--accent)" }}>
                        <CheckCircle2 style={{ width: "var(--space-3.5)", height: "var(--space-3.5)", color: "var(--accent)", flexShrink: 0 }} />
                        <span style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{r}</span>
                      </div>
                    ))}
                  </div>
                )}

                <p style={{ fontSize: "var(--text-body)", color: "var(--ink-muted)", overflow: "hidden", display: "-webkit-box", WebkitLineClamp: 3, WebkitBoxOrient: "vertical", lineHeight: 1.65 }}>
                  {currentCard.description}
                </p>
              </div>

              {/* Card Footer */}
              <div style={{ paddingTop: "var(--space-3)", borderTop: "1px solid var(--border)", display: "flex", alignItems: "center", justifyContent: "space-between", fontSize: "var(--text-caption)" }}>
                <button
                  onClick={() => setInspectScholarship(currentCard)}
                  style={{ color: "var(--accent)", fontWeight: 700, textDecoration: "underline", textUnderlineOffset: 4 }}
                >
                  Détails complets
                </button>

                {onOpenFlyAgent && (
                  <button
                    onClick={() => onOpenFlyAgent(currentCard)}
                    className="btn-primary"
                    style={{ padding: "var(--space-1.5) var(--space-3)", borderRadius: "var(--radius-xl)", fontSize: "11px", boxShadow: "var(--shadow-sm)" }}
                  >
                    <Sparkles style={{ width: "var(--space-3)", height: "var(--space-3)", color: "var(--accent-text)" }} />
                    <span>FlyAgent</span>
                  </button>
                )}
              </div>
            </motion.div>
          </div>
        )}
      </div>

      {/* Control Buttons */}
      {currentCard && (
        <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: "var(--space-6)", marginTop: "var(--space-6)" }}>
          <button
            onClick={() => handleSwipe("left")}
            style={{ width: "56px", height: "56px", borderRadius: "var(--radius-full)", background: "var(--warm-50)", border: "2px solid var(--alert)", color: "var(--alert)", display: "flex", alignItems: "center", justifyContent: "center", fontWeight: 700, cursor: "pointer", boxShadow: "var(--shadow-lg)", transition: "all var(--transition-base)" }}
            onMouseEnter={(e) => { e.currentTarget.style.background = "var(--alert-light)"; e.currentTarget.style.transform = "scale(1.1)"; }}
            onMouseLeave={(e) => { e.currentTarget.style.background = "var(--warm-50)"; e.currentTarget.style.transform = "scale(1)"; }}
            title="Passer"
          >
            <X style={{ width: "24px", height: "24px" }} />
          </button>

          <button
            onClick={() => handleSwipe("superlike")}
            style={{ width: "48px", height: "48px", borderRadius: "var(--radius-full)", background: "var(--warm-50)", border: "2px solid var(--warning)", color: "var(--warning)", display: "flex", alignItems: "center", justifyContent: "center", fontWeight: 700, cursor: "pointer", boxShadow: "var(--shadow-lg)", transition: "all var(--transition-base)" }}
            onMouseEnter={(e) => { e.currentTarget.style.background = "var(--warning-light)"; e.currentTarget.style.transform = "scale(1.1)"; }}
            onMouseLeave={(e) => { e.currentTarget.style.background = "var(--warm-50)"; e.currentTarget.style.transform = "scale(1)"; }}
            title="Super Match"
          >
            <Star style={{ width: "20px", height: "20px" }} />
          </button>

          <button
            onClick={() => handleSwipe("right")}
            className="btn-primary"
            style={{ width: "56px", height: "56px", borderRadius: "var(--radius-full)", display: "flex", alignItems: "center", justifyContent: "center", boxShadow: "var(--shadow-lg), 0 4px 12px rgba(15, 123, 108, 0.3)", transition: "transform var(--transition-base)" }}
            onMouseEnter={(e) => { (e.currentTarget as HTMLButtonElement).style.transform = "scale(1.1)"; }}
            onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.transform = "scale(1)"; }}
            title="Aimer"
          >
            <Heart style={{ width: "24px", height: "24px", fill: "rgba(255, 255, 255, 0.2)", color: "var(--accent-text)" }} />
          </button>
        </div>
      )}

      {/* Inspection Modal */}
      {inspectScholarship && (
        <ScholarshipDetailModal
          scholarship={inspectScholarship}
          onClose={() => setInspectScholarship(null)}
          onOpenFlyAgent={onOpenFlyAgent}
        />
      )}
    </div>
  );
}
