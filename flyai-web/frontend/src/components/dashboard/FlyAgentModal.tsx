"use client";

import { useState, useEffect } from "react";
import { Scholarship, UserProfile } from "@/types";
import FormattedText from "@/components/FormattedText";
import { X, Sparkles, CheckCircle2, FileText, Calendar, Send, Copy, BookOpen, Bot, ShieldCheck } from "lucide-react";

interface Props {
  scholarship: Scholarship | null;
  userProfile?: UserProfile | null;
  onClose: () => void;
}

export default function FlyAgentModal({ scholarship, userProfile, onClose }: Props) {
  const [activeTab, setActiveTab] = useState<"plan" | "letter" | "checklist">("plan");
  const [loading, setLoading] = useState(true);
  const [plan, setPlan] = useState("");
  const [motivationLetter, setMotivationLetter] = useState("");
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    if (!scholarship) return;
    setLoading(true);

    // Call FlyAgent AI endpoint to generate custom application plan & cover letter
    fetch("/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        message: `Agent FlyAgent : Génère un plan de postulation étape par étape et un projet de lettre de motivation personnalisé pour la bourse "${scholarship.titre}" (${scholarship.pays_destination?.join(", ")}).`,
        userProfile,
      }),
    })
      .then((res) => res.json())
      .then((json) => {
        if (json.reply) {
          setPlan(json.reply);
          setMotivationLetter(
            `Objet : Candidature à la bourse ${scholarship.titre}\n\nMadame, Monsieur les membres du jury,\n\nActuellement étudiant en ${userProfile?.degreeLevel || "Master"} spécialité ${userProfile?.fieldOfStudy || "Informatique"}, c'est avec un grand enthousiasme que je vous adresse ma candidature pour bénéficier de la bourse d'excellence ${scholarship.titre}.\n\nMon parcours académique ainsi que mes projets de recherche s'inscrivent directement dans la continuité de cette opportunité en ${scholarship.pays_destination?.join(", ") || "destination cible"}.\n\nEn vous remerciant pour l'attention portée à mon dossier.\n\nCordialement,\n${userProfile?.fullName || "Le candidat"}`
          );
        }
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [scholarship, userProfile]);

  if (!scholarship) return null;

  const handleCopyLetter = () => {
    navigator.clipboard.writeText(motivationLetter);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-md animate-fade-in">
      <div className="relative w-full max-w-4xl max-h-[90vh] bg-white dark:bg-slate-900 border border-slate-200 dark:border-white/10 rounded-3xl shadow-2xl overflow-hidden flex flex-col">
        {/* Header */}
        <div className="p-6 bg-gradient-to-r from-indigo-600 to-violet-600 text-white flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-2xl bg-white/20 flex items-center justify-center font-bold">
              <Bot className="w-6 h-6" />
            </div>
            <div>
              <span className="text-xs uppercase font-bold text-indigo-200 tracking-wider">
                FlyAgent Application Assistant
              </span>
              <h2 className="text-xl font-extrabold line-clamp-1">{scholarship.titre}</h2>
            </div>
          </div>

          <button onClick={onClose} className="p-2 rounded-full bg-white/10 hover:bg-white/20 transition-all">
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Navigation Sub-Tabs */}
        <div className="flex border-b border-slate-200 dark:border-white/10 bg-slate-50 dark:bg-slate-950/50 px-6 pt-3 gap-4">
          {[
            { id: "plan", label: "Plan d'Action IA", icon: Sparkles },
            { id: "letter", label: "Lettre de Motivation IA", icon: FileText },
            { id: "checklist", label: "Checklist du Dossier", icon: CheckCircle2 },
          ].map((tab) => {
            const Icon = tab.icon;
            const active = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                onClick={() => setActiveTab(tab.id as any)}
                className={`flex items-center gap-2 pb-3 text-xs font-extrabold border-b-2 transition-all ${
                  active
                    ? "border-indigo-600 text-indigo-600 dark:text-indigo-400"
                    : "border-transparent text-slate-500 hover:text-slate-700 dark:hover:text-slate-300"
                }`}
              >
                <Icon className="w-4 h-4" />
                <span>{tab.label}</span>
              </button>
            );
          })}
        </div>

        {/* Content Body */}
        <div className="flex-1 p-6 overflow-y-auto space-y-6 custom-scrollbar text-slate-800 dark:text-slate-200">
          {loading ? (
            <div className="p-12 text-center space-y-3">
              <Sparkles className="w-8 h-8 text-indigo-500 animate-spin mx-auto" />
              <p className="text-xs font-bold text-slate-500 dark:text-slate-400">
                FlyAgent analyse les critères de la bourse et prépare ton plan personnalisé...
              </p>
            </div>
          ) : (
            <>
              {activeTab === "plan" && (
                <div className="space-y-4">
                  <div className="p-4 rounded-2xl bg-indigo-50 dark:bg-indigo-950/30 border border-indigo-200 dark:border-indigo-500/20 flex items-center gap-3">
                    <ShieldCheck className="w-5 h-5 text-indigo-600 shrink-0" />
                    <p className="text-xs text-indigo-900 dark:text-indigo-200">
                      Ce plan personnalisé a été conçu selon les exigences spécifiques de <strong>{scholarship.titre}</strong> et ton profil académique.
                    </p>
                  </div>
                  <FormattedText content={plan} />
                </div>
              )}

              {activeTab === "letter" && (
                <div className="space-y-4">
                  <div className="flex items-center justify-between">
                    <h3 className="font-bold text-sm text-slate-900 dark:text-white">Brouillon de Lettre Généré par FlyAgent</h3>
                    <button
                      onClick={handleCopyLetter}
                      className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-indigo-600 text-white text-xs font-bold shadow-md hover:bg-indigo-500 transition-all"
                    >
                      <Copy className="w-3.5 h-3.5" />
                      <span>{copied ? "Copié !" : "Copier le texte"}</span>
                    </button>
                  </div>

                  <textarea
                    rows={12}
                    value={motivationLetter}
                    onChange={(e) => setMotivationLetter(e.target.value)}
                    className="w-full p-4 rounded-2xl bg-slate-50 dark:bg-white/5 border border-slate-200 dark:border-white/10 text-xs leading-relaxed outline-none focus:border-indigo-500 font-mono"
                  />
                </div>
              )}

              {activeTab === "checklist" && (
                <div className="space-y-3">
                  <h3 className="font-bold text-sm text-slate-900 dark:text-white mb-2">Documents Nécessaires pour Postuler</h3>
                  {[
                    "Formulaire officiel de candidature téléversé",
                    "Relevés de notes certifiés conformes (Traduction assermentée)",
                    "Lettre de motivation personnalisée FlyAgent",
                    "Attestation de niveau de langue (TOEFL / IELTS / DELF)",
                    "Deux (2) lettres de recommandation de professeurs",
                  ].map((doc, idx) => (
                    <div key={idx} className="flex items-center gap-3 p-3.5 rounded-2xl bg-slate-50 dark:bg-white/5 border border-slate-200 dark:border-white/5">
                      <CheckCircle2 className="w-5 h-5 text-emerald-500 shrink-0" />
                      <span className="text-xs font-semibold">{doc}</span>
                    </div>
                  ))}
                </div>
              )}
            </>
          )}
        </div>

        {/* Footer */}
        <div className="p-4 border-t border-slate-200 dark:border-white/10 bg-slate-50 dark:bg-slate-950 flex justify-between items-center">
          <span className="text-xs text-slate-500">Ajouté automatiquement à tes candidatures</span>
          <button onClick={onClose} className="px-6 py-2.5 rounded-xl bg-indigo-600 text-white font-bold text-xs">
            Terminer & Fermer
          </button>
        </div>
      </div>
    </div>
  );
}
