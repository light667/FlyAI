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
        // Déterminer la catégorie en fonction de la direction
        let category = "standard";
        if (direction === "right") category = "favoris";
        if (direction === "superlike") category = "flyagent";
        
        await fetch("/api/swipes", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            userId,
            bourseId: currentCard.id,
            direction,
            score: currentCard.matchScore || 85,
            category,
          }),
        });
      } catch (err) {
        console.error("Error saving swipe:", err);
      }
    }
  };

  const currentCard = deck[currentIndex];
  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", width: "100%", maxWidth: "1200px", margin: "0 auto", padding: "12px 16px", color: "var(--ink-text)", gap: "16px" }}>
      
      {/* Title Header */}
      <div style={{ textAlign: "center", display: "flex", flexDirection: "column", gap: "4px" }}>
        <h2 style={{ fontSize: "1.15rem", fontWeight: 800, color: "var(--ink-text)", margin: 0 }}>
          Opportunités Recommandées
        </h2>
        <p style={{ fontSize: "0.75rem", color: "var(--ink-muted)", margin: 0 }}>
          Classées par score de compatibilité décroissant avec votre profil académique.
        </p>
      </div>

      {/* ── Horizontal Scrollable List / Carousel (Ordre Décroissant de Score) ── */}
      {deck.length > 0 && (
        <div style={{ width: "100%", display: "flex", flexDirection: "column", gap: "8px" }}>
          <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", px: "4px" }}>
            <span style={{ fontSize: "0.75rem", fontWeight: 700, color: "var(--accent)", textTransform: "uppercase", letterSpacing: "0.04em" }}>
              Toutes les bourses ({deck.length})
            </span>
            <span style={{ fontSize: "0.7rem", color: "var(--ink-subtle)" }}>Défiler à gauche →</span>
          </div>

          <div 
            className="no-scrollbar"
            style={{ 
              display: "flex", 
              gap: "12px", 
              overflowX: "auto", 
              paddingBottom: "8px",
              scrollSnapType: "x mandatory",
              width: "100%"
            }}
          >
            {deck.map((sch, idx) => {
              const isActive = idx === currentIndex;
              const score = sch.matchScore || 85;
              return (
                <div
                  key={sch.id || idx}
                  onClick={() => setCurrentIndex(idx)}
                  style={{
                    flexShrink: 0,
                    width: "220px",
                    scrollSnapAlign: "start",
                    background: isActive ? "var(--accent-light)" : "var(--warm-50)",
                    border: isActive ? "2px solid var(--accent)" : "1px solid var(--border)",
                    borderRadius: "14px",
                    padding: "12px",
                    cursor: "pointer",
                    display: "flex",
                    flexDirection: "column",
                    justify: "space-between",
                    gap: "8px",
                    boxShadow: isActive ? "0 4px 12px rgba(15,123,108,0.2)" : "var(--shadow-sm)",
                    transition: "all 0.2s ease"
                  }}
                >
                  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                    <span style={{ 
                      fontSize: "0.68rem", 
                      fontWeight: 800, 
                      padding: "2px 8px", 
                      borderRadius: "9999px",
                      background: score >= 80 ? "var(--success-light)" : "var(--warm-100)",
                      color: score >= 80 ? "var(--success)" : "var(--accent)",
                      border: "1px solid var(--border)"
                    }}>
                      Score : {score}%
                    </span>
                    <span style={{ fontSize: "0.65rem", fontWeight: 600, color: "var(--ink-subtle)" }}>
                      #{idx + 1}
                    </span>
                  </div>

                  <h4 style={{ 
                    fontSize: "0.82rem", 
                    fontWeight: 700, 
                    color: "var(--ink-text)", 
                    margin: 0, 
                    lineHeight: 1.3,
                    display: "-webkit-box",
                    WebkitLineClamp: 2,
                    WebkitBoxOrient: "vertical",
                    overflow: "hidden"
                  }}>
                    {sch.titre}
                  </h4>

                  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", fontSize: "0.68rem", color: "var(--ink-muted)" }}>
                    <span style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", maxWidth: "120px" }}>
                      {sch.pays_destination?.join(", ") || "International"}
                    </span>
                    {sch.deadline && (
                      <span style={{ fontWeight: 600, color: "var(--warning)" }}>
                        {new Date(sch.deadline).toLocaleDateString("fr-FR", { month: "numeric", day: "numeric" })}
                      </span>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Match Animation Modal Overlay */}
      <AnimatePresence>
        {lastMatch && (
          <motion.div
            initial={{ opacity: 0, scale: 0.8 }}
            animate={{ opacity: 1, scale: 1 }}
            exit={{ opacity: 0, scale: 0.8 }}
            style={{ position: "fixed", inset: 0, zIndex: 50, display: "flex", alignItems: "center", justifyContent: "center", padding: "var(--space-4)", background: "rgba(15, 26, 46, 0.6)", backdropFilter: "blur(8px)" }}
          >
            <div style={{ background: "var(--warm-50)", border: "1px solid var(--border)", borderRadius: "var(--radius-2xl)", padding: "var(--space-6)", maxWidth: "400px", width: "100%", textAlign: "center", display: "flex", flexDirection: "column", gap: "16px", boxShadow: "var(--shadow-xl)" }}>
              <div style={{ width: "56px", height: "56px", margin: "0 auto", borderRadius: "var(--radius-full)", background: "var(--gradient-accent)", display: "flex", alignItems: "center", justifyContent: "center", color: "var(--accent-text)" }}>
                <Sparkles style={{ width: "28px", height: "28px" }} />
              </div>

              <div>
                <h3 style={{ fontSize: "1.1rem", fontWeight: 800, color: "var(--ink-text)", margin: 0 }}>Compatible à {lastMatch.matchScore || 90}% !</h3>
                <p style={{ fontSize: "0.82rem", color: "var(--ink-muted)", marginTop: "6px" }}>
                  <span style={{ fontWeight: 700, color: "var(--accent)" }}>{lastMatch.titre}</span> a été ajoutée à vos favoris.
                </p>
              </div>

              <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
                {onOpenFlyAgent && (
                  <button
                    onClick={() => {
                      const m = lastMatch;
                      setLastMatch(null);
                      onOpenFlyAgent(m);
                    }}
                    className="btn-primary"
                    style={{ padding: "10px 18px", borderRadius: "14px" }}
                  >
                    <span>Postuler avec FlyAgent</span>
                  </button>
                )}

                <button
                  onClick={() => setLastMatch(null)}
                  className="btn-secondary"
                  style={{ padding: "8px 16px", borderRadius: "14px", fontSize: "0.8rem", fontWeight: 700 }}
                >
                  Continuer
                </button>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* ── Main Interactive Swiping Card ── */}
      <div style={{ position: "relative", width: "100%", maxWidth: "448px", minHeight: "380px", maxHeight: "460px", height: "420px", display: "flex", alignItems: "center", justifyContent: "center" }}>
        {loading ? (
          <div style={{ width: "100%", height: "100%", borderRadius: "20px", background: "var(--warm-50)", border: "1px solid var(--border)", animation: "pulse 2s ease-in-out infinite", display: "flex", alignItems: "center", justifyContent: "center", color: "var(--ink-muted)", fontSize: "0.8rem", fontWeight: 700 }}>
            Calcul des meilleures bourses...
          </div>
        ) : !currentCard ? (
          <div style={{ width: "100%", padding: "24px", textAlign: "center", background: "var(--warm-50)", border: "1px solid var(--border)", borderRadius: "20px", display: "flex", flexDirection: "column", gap: "14px", alignItems: "center", justifyContent: "center", boxShadow: "var(--shadow-lg)" }}>
            <h3 style={{ fontSize: "1.1rem", fontWeight: 800, color: "var(--ink-text)", margin: 0 }}>Toutes les bourses ont été explorées !</h3>
            <button
              onClick={loadDeck}
              className="btn-primary"
              style={{ padding: "10px 20px", borderRadius: "14px" }}
            >
              Recharger la liste
            </button>
          </div>
        ) : (
          <div style={{ position: "relative", width: "100%", height: "100%" }}>
            {/* Card Preview behind */}
            {deck[currentIndex + 1] && (
              <div style={{ position: "absolute", inset: 0, background: "var(--warm-100)", border: "1px solid var(--border)", borderRadius: "20px", transform: "scale(0.96) translateY(8px)", opacity: 0.6, pointerEvents: "none" }} />
            )}

            {/* Top Interactive Card */}
            <motion.div
              style={{ 
                x, rotate, 
                position: "absolute", inset: 0, 
                background: "var(--warm-50)", 
                border: "1px solid var(--border)", 
                borderRadius: "20px", 
                padding: "16px 20px", 
                display: "flex", 
                flexDirection: "column", 
                justify: "space-between", 
                cursor: "grab", 
                boxShadow: "var(--shadow-lg)", 
                overflow: "hidden" 
              }}
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
                style={{ opacity: opacityLike, position: "absolute", top: "16px", left: "16px", zIndex: 20, padding: "6px 16px", background: "var(--success)", color: "#fff", fontWeight: 800, fontSize: "0.8rem", textTransform: "uppercase", borderRadius: "12px", transform: "rotate(-10deg)" }}
              >
                AJOUTER
              </motion.div>

              <motion.div
                style={{ opacity: opacitySkip, position: "absolute", top: "16px", right: "16px", zIndex: 20, padding: "6px 16px", background: "var(--alert)", color: "#fff", fontWeight: 800, fontSize: "0.8rem", textTransform: "uppercase", borderRadius: "12px", transform: "rotate(10deg)" }}
              >
                PASSER
              </motion.div>

              {/* Card Content Header */}
              <div style={{ display: "flex", flexDirection: "column", gap: "10px" }}>
                {/* Badges line without heavy icons */}
                <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", flexWrap: "wrap", gap: "6px" }}>
                  <span style={{ padding: "3px 10px", fontSize: "0.72rem", fontWeight: 800, borderRadius: "9999px", background: "var(--accent-light)", color: "var(--accent)", border: "1px solid var(--accent-200)" }}>
                    Compatibilité {currentCard.matchScore || 85}%
                  </span>

                  <span style={{ padding: "3px 10px", fontSize: "0.68rem", fontWeight: 700, borderRadius: "9999px", background: "var(--success-light)", color: "var(--success)", border: "1px solid var(--success-200)", textTransform: "uppercase" }}>
                    {currentCard.financement === "TOTAL" ? "Financement Total" : "Financement Partiel"}
                  </span>
                </div>

                {/* Title (compact font size to avoid overflow) */}
                <h3 style={{ fontSize: "1.05rem", fontWeight: 800, color: "var(--ink-text)", margin: 0, lineHeight: 1.3, display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical", overflow: "hidden" }}>
                  {currentCard.titre}
                </h3>

                {/* Target & Deadline Tags */}
                <div style={{ display: "flex", flexWrap: "wrap", gap: "6px", fontSize: "0.72rem", fontWeight: 600, color: "var(--ink-muted)" }}>
                  <span style={{ background: "var(--warm-100)", padding: "3px 8px", borderRadius: "6px" }}>
                    📍 {currentCard.pays_destination?.join(", ") || "International"}
                  </span>

                  {currentCard.deadline && (
                    <span style={{ background: "var(--warning-light)", padding: "3px 8px", borderRadius: "6px", color: "var(--warning)", fontWeight: 700 }}>
                      ⏳ Clôture : {new Date(currentCard.deadline).toLocaleDateString("fr-FR")}
                    </span>
                  )}
                </div>

                {/* Score Reasons (Concise) */}
                {currentCard.matchBreakdown?.reasons && (
                  <div style={{ padding: "8px 10px", borderRadius: "10px", background: "var(--warm-100)", border: "1px solid var(--border)", display: "flex", flexDirection: "column", gap: "2px" }}>
                    {currentCard.matchBreakdown.reasons.slice(0, 2).map((r, i) => (
                      <span key={i} style={{ fontSize: "0.68rem", fontWeight: 600, color: "var(--accent)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                        ✓ {r}
                      </span>
                    ))}
                  </div>
                )}

                {/* Description */}
                <p style={{ fontSize: "0.78rem", color: "var(--ink-muted)", margin: 0, overflow: "hidden", display: "-webkit-box", WebkitLineClamp: 2, WebkitBoxOrient: "vertical", lineHeight: 1.5 }}>
                  {currentCard.description}
                </p>
              </div>

              {/* Card Footer (Cleanly placed inside card without overflow) */}
              <div style={{ paddingTop: "10px", borderTop: "1px solid var(--border)", display: "flex", alignItems: "center", justifyContent: "space-between", gap: "8px" }}>
                <button
                  onClick={() => setInspectScholarship(currentCard)}
                  style={{ color: "var(--accent)", fontWeight: 700, fontSize: "0.75rem", background: "none", border: "none", cursor: "pointer", padding: "4px 0", textDecoration: "underline" }}
                >
                  Détails complets
                </button>

                {onOpenFlyAgent && (
                  <button
                    onClick={() => onOpenFlyAgent(currentCard)}
                    className="btn-primary"
                    style={{
                      padding: "6px 14px",
                      borderRadius: "12px",
                      fontSize: "0.75rem",
                      fontWeight: 700,
                      whiteSpace: "nowrap",
                      flexShrink: 0,
                    }}
                  >
                    <span>Postuler avec FlyAgent</span>
                  </button>
                )}
              </div>
            </motion.div>
          </div>
        )}
      </div>

      {/* Control Buttons */}
      {currentCard && (
        <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: "20px", marginTop: "4px" }}>
          <button
            onClick={() => handleSwipe("left")}
            style={{ width: "48px", height: "48px", borderRadius: "9999px", background: "var(--warm-50)", border: "2px solid var(--alert)", color: "var(--alert)", display: "flex", alignItems: "center", justifyContent: "center", fontWeight: 700, cursor: "pointer", boxShadow: "var(--shadow-sm)", transition: "all 0.2s" }}
            title="Passer"
          >
            <X style={{ width: "20px", height: "20px" }} />
          </button>

          <button
            onClick={() => handleSwipe("superlike")}
            style={{ width: "42px", height: "42px", borderRadius: "9999px", background: "var(--warm-50)", border: "2px solid var(--warning)", color: "var(--warning)", display: "flex", alignItems: "center", justifyContent: "center", fontWeight: 700, cursor: "pointer", boxShadow: "var(--shadow-sm)", transition: "all 0.2s" }}
            title="Super Match"
          >
            <Star style={{ width: "18px", height: "18px" }} />
          </button>

          <button
            onClick={() => handleSwipe("right")}
            className="btn-primary"
            style={{
              width: "48px",
              height: "48px",
              borderRadius: "9999px",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              boxShadow: "0 4px 14px rgba(15, 123, 108, 0.4)",
              cursor: "pointer",
              padding: 0,
            }}
            title="Aimer et ajouter aux favoris"
          >
            <Heart style={{ width: "22px", height: "22px", fill: "#ffffff", color: "#ffffff" }} />
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
