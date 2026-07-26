"use client";

import { Scholarship } from "@/types";
import { X, ExternalLink, Calendar, MapPin, Award, CheckCircle2, DollarSign, Sparkles, BookOpen, ShieldCheck } from "lucide-react";

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
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-md animate-fade-in">
      <div className="relative w-full max-w-3xl max-h-[90vh] bg-slate-900 border border-white/10 rounded-3xl shadow-2xl overflow-hidden flex flex-col">
        {/* Header Banner */}
        <div className="relative p-6 md:p-8 bg-gradient-to-r from-indigo-900/40 via-purple-900/30 to-slate-900 border-b border-white/10">
          <button
            onClick={onClose}
            className="absolute top-5 right-5 p-2 rounded-full bg-white/10 hover:bg-white/20 text-slate-300 transition-all"
          >
            <X className="w-5 h-5" />
          </button>

          <div className="flex flex-wrap items-center gap-2 mb-3">
            <span className="px-3 py-1 text-xs font-bold rounded-full bg-indigo-500/20 text-indigo-300 border border-indigo-500/30 flex items-center gap-1.5">
              <Sparkles className="w-3.5 h-3.5 text-indigo-400" />
              Match {score}%
            </span>
            <span className="px-3 py-1 text-xs font-bold rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 flex items-center gap-1">
              <DollarSign className="w-3.5 h-3.5" />
              Financement {scholarship.financement}
            </span>
          </div>

          <h2 className="text-2xl md:text-3xl font-extrabold text-white leading-tight">
            {scholarship.titre}
          </h2>

          <div className="flex flex-wrap gap-4 mt-4 text-xs font-medium text-slate-300">
            {scholarship.pays_destination && scholarship.pays_destination.length > 0 && (
              <div className="flex items-center gap-1.5 bg-white/5 px-3 py-1.5 rounded-xl border border-white/5">
                <MapPin className="w-4 h-4 text-indigo-400" />
                <span>{scholarship.pays_destination.join(", ")}</span>
              </div>
            )}

            {scholarship.deadline && (
              <div className="flex items-center gap-1.5 bg-white/5 px-3 py-1.5 rounded-xl border border-white/5">
                <Calendar className="w-4 h-4 text-amber-400" />
                <span>Date limite : {new Date(scholarship.deadline).toLocaleDateString("fr-FR")}</span>
              </div>
            )}
          </div>
        </div>

        {/* Modal Scrollable Body */}
        <div className="flex-1 p-6 md:p-8 space-y-6 overflow-y-auto custom-scrollbar">
          {/* Match Score Decomposition */}
          {breakdown && (
            <div className="p-5 rounded-2xl bg-indigo-950/30 border border-indigo-500/20 space-y-3">
              <h4 className="text-xs font-bold uppercase tracking-wider text-indigo-400 flex items-center gap-2">
                <ShieldCheck className="w-4 h-4" /> Analyse de compatibilité avec ton profil
              </h4>
              <div className="grid grid-cols-2 md:grid-cols-4 gap-3 text-xs">
                <div className="p-2.5 rounded-xl bg-white/5 border border-white/5">
                  <div className="text-slate-400">Niveau d'étude</div>
                  <div className="font-bold text-white">{breakdown.degreeMatch ? "✅ Compatible" : "⚠️ Partiel"}</div>
                </div>
                <div className="p-2.5 rounded-xl bg-white/5 border border-white/5">
                  <div className="text-slate-400">Spécialité / Domaine</div>
                  <div className="font-bold text-white">{breakdown.domainMatch ? "✅ Correspondant" : "⚠️ Proche"}</div>
                </div>
                <div className="p-2.5 rounded-xl bg-white/5 border border-white/5">
                  <div className="text-slate-400">Pays cible</div>
                  <div className="font-bold text-white">{breakdown.countryMatch ? "✅ Destination cible" : "🌍 International"}</div>
                </div>
                <div className="p-2.5 rounded-xl bg-white/5 border border-white/5">
                  <div className="text-slate-400">Financement</div>
                  <div className="font-bold text-emerald-400">{breakdown.fundingMatch ? "100% Prise en charge" : "Partiel"}</div>
                </div>
              </div>

              {breakdown.reasons && breakdown.reasons.length > 0 && (
                <div className="space-y-1 pt-1">
                  {breakdown.reasons.map((reason, idx) => (
                    <div key={idx} className="flex items-center gap-2 text-xs text-indigo-200">
                      <CheckCircle2 className="w-3.5 h-3.5 text-indigo-400 shrink-0" />
                      <span>{reason}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* Description */}
          <div>
            <h3 className="text-sm font-bold text-slate-300 uppercase tracking-wider mb-2 flex items-center gap-2">
              <BookOpen className="w-4 h-4 text-indigo-400" /> Description de la Bourse
            </h3>
            <p className="text-sm leading-relaxed text-slate-300 bg-white/5 p-4 rounded-2xl border border-white/5 whitespace-pre-line">
              {scholarship.description || "Aucune description détaillée disponible."}
            </p>
          </div>

          {/* Domaines & Niveaux */}
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            {scholarship.domaines && scholarship.domaines.length > 0 && (
              <div>
                <h4 className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-2">Domaines d'études</h4>
                <div className="flex flex-wrap gap-1.5">
                  {scholarship.domaines.map((d, i) => (
                    <span key={i} className="px-2.5 py-1 text-xs rounded-lg bg-indigo-500/10 text-indigo-300 border border-indigo-500/20">
                      {d}
                    </span>
                  ))}
                </div>
              </div>
            )}

            {scholarship.niveau_etude && scholarship.niveau_etude.length > 0 && (
              <div>
                <h4 className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-2">Niveaux requis</h4>
                <div className="flex flex-wrap gap-1.5">
                  {scholarship.niveau_etude.map((n, i) => (
                    <span key={i} className="px-2.5 py-1 text-xs rounded-lg bg-purple-500/10 text-purple-300 border border-purple-500/20 uppercase font-semibold">
                      {n}
                    </span>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Footer Actions */}
        <div className="p-5 md:p-6 bg-slate-950 border-t border-white/10 flex flex-col sm:flex-row items-center justify-between gap-4">
          <button
            onClick={onClose}
            className="w-full sm:w-auto px-6 py-3 rounded-xl border border-white/10 text-slate-300 hover:bg-white/5 text-sm font-semibold transition-all"
          >
            Fermer
          </button>

          <div className="flex flex-wrap items-center gap-3 w-full sm:w-auto">
            {onOpenFlyAgent && (
              <button
                onClick={() => {
                  onClose();
                  onOpenFlyAgent(scholarship);
                }}
                className="w-full sm:w-auto flex items-center justify-center gap-2 px-5 py-3 rounded-xl bg-gradient-to-r from-purple-600 to-indigo-600 hover:from-purple-500 hover:to-indigo-500 text-white font-bold text-xs shadow-lg shadow-purple-500/25 transition-all"
              >
                <Sparkles className="w-4 h-4 text-amber-300" />
                <span>Postuler avec FlyAgent</span>
              </button>
            )}

            {scholarship.lien_candidature || scholarship.url ? (
              <a
                href={scholarship.lien_candidature || scholarship.url}
                target="_blank"
                rel="noopener noreferrer"
                className="w-full sm:w-auto flex items-center justify-center gap-2 px-5 py-3 rounded-xl bg-slate-800 hover:bg-slate-700 text-white font-bold text-xs border border-white/10 transition-all"
              >
                <span>Site officiel</span>
                <ExternalLink className="w-3.5 h-3.5" />
              </a>
            ) : null}
          </div>
        </div>
      </div>
    </div>
  );
}
