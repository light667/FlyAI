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
    <div className="flex flex-col items-center justify-center min-h-[75vh] relative px-4 text-slate-800 dark:text-slate-100">
      {/* Title */}
      <div className="text-center mb-6 space-y-1">
        <h2 className="text-2xl font-black text-slate-900 dark:text-white flex items-center justify-center gap-2">
          <Sparkles className="w-6 h-6 text-blue-600 dark:text-indigo-400" /> Deck de Matching Avancé
        </h2>
        <p className="text-xs text-slate-500 dark:text-slate-400">
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
            className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-lg"
          >
            <div className="bg-white dark:bg-slate-900 border border-slate-200 dark:border-indigo-500/40 p-8 rounded-3xl max-w-md w-full text-center space-y-6 shadow-2xl">
              <div className="w-20 h-20 mx-auto rounded-full bg-gradient-to-tr from-blue-600 to-violet-600 flex items-center justify-center animate-bounce shadow-lg text-white">
                <Sparkles className="w-10 h-10" />
              </div>

              <div>
                <h3 className="text-2xl font-extrabold text-slate-900 dark:text-white">Compatible à {lastMatch.matchScore || 90}% ! 🎉</h3>
                <p className="text-xs text-slate-600 dark:text-slate-300 mt-2">
                  <span className="font-bold text-blue-600 dark:text-indigo-300">{lastMatch.titre}</span> a été ajoutée à tes candidatures.
                </p>
              </div>

              <div className="flex flex-col gap-3">
                {onOpenFlyAgent && (
                  <button
                    onClick={() => {
                      const m = lastMatch;
                      setLastMatch(null);
                      onOpenFlyAgent(m);
                    }}
                    className="w-full py-3.5 rounded-2xl bg-blue-600 hover:bg-blue-500 text-white font-bold text-xs shadow-lg transition-all flex items-center justify-center gap-2"
                  >
                    <Sparkles className="w-4 h-4 text-amber-300" />
                    <span>Postuler avec FlyAgent</span>
                  </button>
                )}

                <button
                  onClick={() => setLastMatch(null)}
                  className="w-full py-3 rounded-2xl border border-slate-200 dark:border-white/10 text-slate-600 dark:text-slate-400 text-xs font-bold"
                >
                  Continuer le Matching
                </button>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Main Matching Deck Container */}
      <div className="relative w-full max-w-md h-[520px] flex items-center justify-center">
        {loading ? (
          <div className="w-full h-full rounded-3xl bg-white dark:bg-slate-900/60 border border-slate-200 dark:border-white/10 animate-pulse flex items-center justify-center text-slate-400 text-xs font-bold">
            Calcul des scores de matching...
          </div>
        ) : !currentCard ? (
          <div className="w-full p-8 text-center bg-white dark:bg-slate-900/60 border border-slate-200 dark:border-white/10 rounded-3xl space-y-4 shadow-lg">
            <Sparkles className="w-12 h-12 text-blue-600 dark:text-indigo-400 mx-auto" />
            <h3 className="text-xl font-black text-slate-900 dark:text-white">Toutes les bourses ont été examinées ! 🚀</h3>
            <button
              onClick={loadDeck}
              className="px-6 py-3 bg-blue-600 text-white font-bold rounded-2xl text-xs shadow-lg hover:bg-blue-500 transition-all"
            >
              Recharger le Deck
            </button>
          </div>
        ) : (
          <div className="relative w-full h-full">
            {/* Card Preview behind */}
            {deck[currentIndex + 1] && (
              <div className="absolute inset-0 bg-slate-100 dark:bg-slate-900 border border-slate-200 dark:border-white/5 rounded-3xl scale-95 opacity-50 translate-y-3 pointer-events-none shadow-md" />
            )}

            {/* Top Interactive Card */}
            <motion.div
              style={{ x, rotate }}
              drag="x"
              dragConstraints={{ left: 0, right: 0 }}
              onDragEnd={(_, info) => {
                if (info.offset.x > 120) {
                  handleSwipe("right");
                } else if (info.offset.x < -120) {
                  handleSwipe("left");
                }
              }}
              className="absolute inset-0 bg-white dark:bg-slate-900 border border-slate-200 dark:border-white/10 rounded-3xl p-6 shadow-xl flex flex-col justify-between cursor-grab active:cursor-grabbing select-none overflow-hidden"
            >
              {/* Swipe Badges */}
              <motion.div
                style={{ opacity: opacityLike }}
                className="absolute top-6 left-6 z-20 px-4 py-2 bg-emerald-500 text-white font-black text-base uppercase rounded-2xl shadow-xl rotate-[-12deg]"
              >
                LIKE ❤️
              </motion.div>

              <motion.div
                style={{ opacity: opacitySkip }}
                className="absolute top-6 right-6 z-20 px-4 py-2 bg-rose-500 text-white font-black text-base uppercase rounded-2xl shadow-xl rotate-[12deg]"
              >
                SKIP ✕
              </motion.div>

              {/* Card Body */}
              <div className="space-y-3">
                <div className="flex items-center justify-between">
                  <span className="px-3.5 py-1.5 text-xs font-black rounded-full bg-blue-50 dark:bg-indigo-500/20 text-blue-600 dark:text-indigo-300 border border-blue-200 dark:border-indigo-500/30 flex items-center gap-1.5">
                    <Sparkles className="w-3.5 h-3.5 text-blue-600 dark:text-indigo-400" />
                    Match Score {currentCard.matchScore || 85}%
                  </span>

                  <span className="px-3 py-1 text-[11px] font-extrabold rounded-full bg-emerald-50 dark:bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 border border-emerald-200 dark:border-emerald-500/20 uppercase">
                    {currentCard.financement === "TOTAL" ? "100% Financé" : "Partiel"}
                  </span>
                </div>

                <h3 className="text-xl font-black text-slate-900 dark:text-white leading-tight">
                  {currentCard.titre}
                </h3>

                <div className="flex flex-wrap gap-2 text-xs font-medium text-slate-500 dark:text-slate-400">
                  <div className="flex items-center gap-1 bg-slate-100 dark:bg-white/5 px-2.5 py-1 rounded-lg">
                    <MapPin className="w-3.5 h-3.5 text-blue-600 dark:text-indigo-400" />
                    <span>{currentCard.pays_destination?.join(", ") || "International"}</span>
                  </div>

                  {currentCard.deadline && (
                    <div className="flex items-center gap-1 bg-slate-100 dark:bg-white/5 px-2.5 py-1 rounded-lg text-amber-600 dark:text-amber-400">
                      <Calendar className="w-3.5 h-3.5" />
                      <span>{new Date(currentCard.deadline).toLocaleDateString("fr-FR")}</span>
                    </div>
                  )}
                </div>

                {/* Score Reasons */}
                {currentCard.matchBreakdown?.reasons && (
                  <div className="p-3 rounded-2xl bg-blue-50/60 dark:bg-indigo-950/30 border border-blue-100 dark:border-indigo-500/20 space-y-1">
                    {currentCard.matchBreakdown.reasons.slice(0, 2).map((r, i) => (
                      <div key={i} className="flex items-center gap-1.5 text-[11px] font-semibold text-blue-900 dark:text-indigo-200">
                        <CheckCircle2 className="w-3.5 h-3.5 text-blue-600 dark:text-indigo-400 shrink-0" />
                        <span className="truncate">{r}</span>
                      </div>
                    ))}
                  </div>
                )}

                <p className="text-xs text-slate-600 dark:text-slate-300 line-clamp-3 leading-relaxed">
                  {currentCard.description}
                </p>
              </div>

              {/* Card Footer */}
              <div className="pt-3 border-t border-slate-100 dark:border-white/5 flex items-center justify-between text-xs">
                <button
                  onClick={() => setInspectScholarship(currentCard)}
                  className="text-blue-600 dark:text-indigo-400 font-extrabold hover:underline"
                >
                  Détails complets &rarr;
                </button>

                {onOpenFlyAgent && (
                  <button
                    onClick={() => onOpenFlyAgent(currentCard)}
                    className="px-3 py-1.5 rounded-xl bg-blue-600 text-white font-bold text-[11px] flex items-center gap-1 shadow-sm"
                  >
                    <Sparkles className="w-3 h-3 text-amber-300" />
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
        <div className="flex items-center justify-center gap-6 mt-6">
          <button
            onClick={() => handleSwipe("left")}
            className="w-14 h-14 rounded-full bg-white dark:bg-slate-900 border border-rose-200 dark:border-rose-500/30 text-rose-500 hover:bg-rose-50 dark:hover:bg-rose-500/20 hover:scale-110 transition-all flex items-center justify-center shadow-lg"
            title="Passer"
          >
            <X className="w-6 h-6" />
          </button>

          <button
            onClick={() => handleSwipe("superlike")}
            className="w-12 h-12 rounded-full bg-white dark:bg-slate-900 border border-amber-200 dark:border-amber-500/30 text-amber-500 hover:bg-amber-50 dark:hover:bg-amber-500/20 hover:scale-110 transition-all flex items-center justify-center shadow-lg"
            title="Super Match"
          >
            <Star className="w-5 h-5 fill-amber-400/20" />
          </button>

          <button
            onClick={() => handleSwipe("right")}
            className="w-14 h-14 rounded-full bg-blue-600 text-white hover:scale-110 transition-all flex items-center justify-center shadow-lg shadow-blue-600/30"
            title="Aimer"
          >
            <Heart className="w-6 h-6 fill-white/20" />
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
