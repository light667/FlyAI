"use client";

import { useState, useEffect } from "react";
import { Scholarship, UserProfile } from "@/types";
import FormattedText from "@/components/FormattedText";
import { X, Sparkles, CheckCircle2, FileText, Calendar, Send, Copy, BookOpen, Bot, ShieldCheck, Clock, AlertCircle } from "lucide-react";

// Checklist item component
interface ChecklistItemProps {
  item: any;
  index: number;
}

function ChecklistItem({ item, index }: ChecklistItemProps) {
  const [completed, setCompleted] = useState(item.completed || false);
  
  return (
    <div className={`flex items-center gap-3 p-3.5 rounded-2xl border transition-all ${
      completed 
        ? 'bg-emerald-500/10 border-emerald-500/20' 
        : 'bg-slate-50 dark:bg-white/5 border-slate-200 dark:border-white/5 hover:border-indigo-500'
    }`}>
      <button 
        onClick={() => setCompleted(!completed)}
        className={`w-5 h-5 rounded-full flex items-center justify-center shrink-0 transition-all ${
          completed 
            ? 'bg-emerald-500 text-white' 
            : 'bg-white dark:bg-slate-800 border-2 border-slate-300 dark:border-slate-600'
        }`}
      >
        {completed ? <CheckCircle2 className="w-3.5 h-3.5" /> : <div className="w-3.5 h-3.5" />}
      </button>
      <div className="flex-1 min-w-0">
        <h4 className="font-semibold text-xs text-slate-900 dark:text-white">{item.label}</h4>
        <p className="text-[11px] text-slate-500 dark:text-slate-400 mt-0.5">{item.description}</p>
        {item.estimatedTime && (
          <p className="text-[10px] text-slate-400 dark:text-slate-500 mt-0.5 flex items-center gap-1">
            <Clock className="w-3 h-3" /> {item.estimatedTime}
          </p>
        )}
      </div>
      {item.required && (
        <span className="text-[10px] font-black text-rose-500 bg-rose-500/10 px-2 py-0.5 rounded-full uppercase">Requis</span>
      )}
    </div>
  );
}

// Checklist items list component
function ChecklistItems({ scholarship, userProfile }: { scholarship: any; userProfile: any }) {
  const [checklist, setChecklist] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!scholarship || !userProfile) return;
    
    setLoading(true);
    // Fetch checklist from API
    fetch("/api/apply", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        userId: userProfile?.id,
        scholarshipId: scholarship.id,
        userProfile,
      }),
    })
      .then((res) => res.json())
      .then((json) => {
        if (json.success && json.checklist) {
          setChecklist(json.checklist);
        }
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [scholarship, userProfile]);

  if (loading) {
    return (
      <div className="p-8 text-center">
        <Sparkles className="w-6 h-6 text-indigo-500 animate-spin mx-auto" />
        <p className="text-xs text-slate-400 mt-2">Génération de la checklist...</p>
      </div>
    );
  }

  if (checklist.length === 0) {
    // Fallback to generic checklist
    return (
      <>
        {[
          { label: "Formulaire officiel de candidature", description: "Formulaire rempli et signé", required: true, estimatedTime: "30 min" },
          { label: "Relevés de notes certifiés", description: "Avec traduction assermentée si nécessaire", required: true, estimatedTime: "1-2 semaines" },
          { label: "Lettre de motivation", description: "Personnalisée pour cette bourse", required: true, estimatedTime: "2-3 heures" },
          { label: "CV académique", description: "Format international", required: true, estimatedTime: "1-2 heures" },
          { label: "Certificat de langue", description: scholarship.langues_requises?.join(" ou ") || "TOEFL/IELTS/DELF", required: true, estimatedTime: "1-4 semaines" },
          { label: "Lettre de recommandation #1", description: "D'un professeur ou employeur", required: true, estimatedTime: "1-2 semaines" },
          { label: "Lettre de recommandation #2", description: "D'un second professeur", required: true, estimatedTime: "1-2 semaines" },
        ].map((item, index) => (
          <ChecklistItem key={index} item={item} index={index} />
        ))}
      </>
    );
  }

  return (
    <>
      {checklist.map((item, index) => (
        <ChecklistItem key={item.key || index} item={item} index={index} />
      ))}
    </>
  );
}

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
    if (!scholarship || !userProfile) return;
    setLoading(true);

    // Call dedicated API endpoint to generate application checklist and letter
    fetch("/api/apply", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        userId: userProfile?.id,
        scholarshipId: scholarship.id,
        userProfile,
      }),
    })
      .then((res) => res.json())
      .then((json) => {
        if (json.success) {
          // Set plan from checklist
          if (json.checklist && json.checklist.length > 0) {
            const planContent = generatePlanFromChecklist(json.checklist, scholarship);
            setPlan(planContent);
          }
          
          // Set motivation letter
          if (json.motivationLetter) {
            setMotivationLetter(json.motivationLetter);
          } else {
            // Fallback to generic letter
            setMotivationLetter(
              `Objet : Candidature à la bourse ${scholarship.titre}\n\nMadame, Monsieur les membres du jury,\n\nActuellement étudiant en ${userProfile?.degreeLevel || "Master"} spécialité ${userProfile?.fieldOfStudy || "Informatique"}, c'est avec un grand enthousiasme que je vous adresse ma candidature pour bénéficier de la bourse d'excellence ${scholarship.titre}.\n\nMon parcours académique ainsi que mes projets de recherche s'inscrivent directement dans la continuité de cette opportunité en ${scholarship.pays_destination?.join(", ") || "destination cible"}.\n\nEn vous remerciant pour l'attention portée à mon dossier.\n\nCordialement,\n${userProfile?.fullName || "Le candidat"}`
            );
          }
        } else {
          // Fallback to original behavior
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
            .catch(console.error);
        }
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [scholarship, userProfile]);

  // Helper function to generate plan from checklist
  function generatePlanFromChecklist(checklist: any[], scholarship: any): string {
    if (!checklist || checklist.length === 0) {
      return "Plan de postulation en cours de génération...";
    }

    let plan = `# Plan d'Action Personnalisé pour ${scholarship.titre}\n\n`;
    plan += `**Date limite :** ${scholarship.deadline ? new Date(scholarship.deadline).toLocaleDateString('fr-FR') : 'Non spécifiée'}\n\n`;
    plan += `**Progression :** ${checklist.filter((item: any) => item.completed).length}/${checklist.length} éléments complets (${Math.round((checklist.filter((item: any) => item.completed).length / checklist.length) * 100)}%)\n\n`;
    
    plan += `## Étapes à suivre\n\n`;
    
    // Group by category
    const categories: Record<string, any[]> = {};
    checklist.forEach((item: any) => {
      if (!categories[item.category]) {
        categories[item.category] = [];
      }
      categories[item.category].push(item);
    });
    
    Object.entries(categories).forEach(([category, items]) => {
      plan += `### ${category}\n\n`;
      items.forEach((item: any, index: number) => {
        const status = item.completed ? '✅' : '⬜';
        plan += `${index + 1}. ${status} **${item.label}**\n`;
        plan += `   - ${item.description}\n`;
        plan += `   - Temps estimé : ${item.estimatedTime || 'Non spécifié'}\n`;
        plan += `   - Statut : ${item.completed ? 'Complété' : 'À faire'}\n\n`;
      });
    });
    
    plan += `## Conseils FlyAgent\n\n`;
    plan += `- Commencez par les documents qui prennent le plus de temps (traductions, lettres de recommandation)\n`;
    plan += `- Vérifiez les dates limites de chaque pièce requise\n`;
    plan += `- Utilisez les modèles de lettres disponibles dans votre espace Documents\n`;
    
    return plan;
  }

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
                  <div className="flex items-center justify-between">
                    <h3 className="font-bold text-sm text-slate-900 dark:text-white">Checklist des Documents pour {scholarship?.titre}</h3>
                    <span className="text-[10px] font-bold text-emerald-600 bg-emerald-500/10 px-2 py-1 rounded-full">
                      {plan.includes('%') ? plan.match(/\d+%/)?.[0] : '0%'}
                    </span>
                  </div>
                  <ChecklistItems scholarship={scholarship} userProfile={userProfile} />
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
