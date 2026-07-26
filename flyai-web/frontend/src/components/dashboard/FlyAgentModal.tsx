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
    <div style={{
      display: "flex", alignItems: "center", gap: "var(--space-3)", padding: "var(--space-3.5)", borderRadius: "var(--radius-xl)", border: "1px solid", transition: "all var(--transition-base)",
      background: completed ? "var(--success-light)" : "var(--warm-50)",
      borderColor: completed ? "var(--success-200)" : "var(--border)",
      cursor: "pointer"
    }} onMouseEnter={(e) => { if (!completed) (e.currentTarget as HTMLDivElement).style.borderColor = "var(--accent)"; }}
      onMouseLeave={(e) => { if (!completed) (e.currentTarget as HTMLDivElement).style.borderColor = "var(--border)"; }}
    >
      <button 
        onClick={() => setCompleted(!completed)}
        style={{
          width: "20px", height: "20px", borderRadius: "var(--radius-full)", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0, transition: "all var(--transition-base)",
          background: completed ? "var(--success)" : "var(--warm-100)",
          color: completed ? "var(--accent-text)" : "var(--ink-muted)",
          border: completed ? "none" : "2px solid var(--border)"
        }}
      >
        {completed ? <CheckCircle2 style={{ width: "14px", height: "14px", color: "var(--accent-text)" }} /> : <div style={{ width: "14px", height: "14px" }} />}
      </button>
      <div style={{ flex: 1, minWidth: 0 }}>
        <h4 style={{ fontWeight: 600, fontSize: "var(--text-caption)", color: "var(--ink-text)", margin: 0 }}>{item.label}</h4>
        <p style={{ fontSize: "11px", color: "var(--ink-muted)", marginTop: "4px" }}>{item.description}</p>
        {item.estimatedTime && (
          <p style={{ fontSize: "10px", color: "var(--ink-subtle)", marginTop: "4px", display: "flex", alignItems: "center", gap: "var(--space-1)" }}>
            <Clock style={{ width: "12px", height: "12px", color: "var(--ink-subtle)" }} /> {item.estimatedTime}
          </p>
        )}
      </div>
      {item.required && (
        <span style={{ fontSize: "10px", fontWeight: 700, color: "var(--alert)", background: "var(--alert-light)", padding: "2px 8px", borderRadius: "var(--radius-full)", textTransform: "uppercase" }}>Requis</span>
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
      <div style={{ padding: "var(--space-8)", textAlign: "center" }}>
        <Sparkles style={{ width: "24px", height: "24px", color: "var(--accent)", margin: "0 auto", animation: "spin 1s linear infinite" }} />
        <p style={{ fontSize: "var(--text-caption)", color: "var(--ink-muted)", marginTop: "var(--space-2)" }}>Génération de la checklist...</p>
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
    <div style={{ position: "fixed", inset: 0, zIndex: 50, display: "flex", alignItems: "center", justifyContent: "center", padding: "var(--space-4)", background: "rgba(15, 26, 46, 0.6)", backdropFilter: "blur(8px)" }}>
      <div style={{ position: "relative", width: "100%", maxWidth: "1200px", maxHeight: "90vh", height: "90vh", background: "var(--warm-50)", border: "1px solid var(--border)", borderRadius: "var(--radius-2xl)", boxShadow: "var(--shadow-xl)", overflow: "hidden", display: "flex", flexDirection: "column" }}>
        {/* Header */}
        <div style={{ padding: "var(--space-6)", background: "var(--gradient-accent)", color: "var(--accent-text)", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div style={{ display: "flex", alignItems: "center", gap: "var(--space-3)" }}>
            <div style={{ width: "40px", height: "40px", borderRadius: "var(--radius-xl)", background: "rgba(255, 255, 255, 0.2)", display: "flex", alignItems: "center", justifyContent: "center", fontWeight: 700 }}>
              <Bot style={{ width: "24px", height: "24px" }} />
            </div>
            <div>
              <span style={{ fontSize: "var(--text-caption)", fontWeight: 700, textTransform: "uppercase", color: "rgba(255, 255, 255, 0.8)", letterSpacing: "0.04em" }}>
                FlyAgent Application Assistant
              </span>
              <h2 style={{ fontSize: "var(--text-h1)", fontWeight: 700, margin: 0, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{scholarship.titre}</h2>
            </div>
          </div>

          <button onClick={onClose} style={{ padding: "8px", borderRadius: "var(--radius-full)", background: "rgba(255, 255, 255, 0.1)", color: "var(--accent-text)", cursor: "pointer", transition: "all var(--transition-base)" }} onMouseEnter={(e) => { (e.currentTarget as HTMLButtonElement).style.background = "rgba(255, 255, 255, 0.2)"; }} onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.background = "rgba(255, 255, 255, 0.1)"; }}>
            <X style={{ width: "20px", height: "20px" }} />
          </button>
        </div>

        {/* Navigation Sub-Tabs */}
        <div style={{ display: "flex", borderBottom: "1px solid var(--border)", background: "var(--warm-100)", paddingLeft: "var(--space-6)", paddingTop: "var(--space-3)", gap: "var(--space-4)", paddingRight: "var(--space-6)" }}>
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
                style={{
                  display: "flex", alignItems: "center", gap: "var(--space-2)", paddingBottom: "var(--space-3)", fontSize: "var(--text-caption)", fontWeight: 700, borderBottom: "2px solid", transition: "all var(--transition-base)",
                  borderBottomColor: active ? "var(--accent)" : "transparent",
                  color: active ? "var(--accent)" : "var(--ink-muted)"
                }}
                onMouseEnter={(e) => { if (!active) (e.currentTarget as HTMLButtonElement).style.color = "var(--ink-text)"; }}
                onMouseLeave={(e) => { if (!active) (e.currentTarget as HTMLButtonElement).style.color = "var(--ink-muted)"; }}
              >
                <Icon style={{ width: "16px", height: "16px", color: active ? "var(--accent)" : "var(--ink-subtle)" }} />
                <span>{tab.label}</span>
              </button>
            );
          })}
        </div>

        {/* Content Body */}
        <div style={{ flex: 1, padding: "var(--space-6)", overflowY: "auto", display: "flex", flexDirection: "column", gap: "var(--space-6)", color: "var(--ink-text)" }}>
          {loading ? (
            <div style={{ padding: "var(--space-12)", textAlign: "center", display: "flex", flexDirection: "column", gap: "var(--space-3)" }}>
              <Sparkles style={{ width: "32px", height: "32px", color: "var(--accent)", margin: "0 auto", animation: "spin 1s linear infinite" }} />
              <p style={{ fontSize: "var(--text-caption)", fontWeight: 700, color: "var(--ink-muted)" }}>
                FlyAgent analyse les critères de la bourse et prépare ton plan personnalisé...
              </p>
            </div>
          ) : (
            <>
              {activeTab === "plan" && (
                <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-4)" }}>
                  <div style={{ padding: "var(--space-4)", borderRadius: "var(--radius-xl)", background: "var(--accent-50)", border: "1px solid var(--accent-200)", display: "flex", alignItems: "center", gap: "var(--space-3)" }}>
                    <ShieldCheck style={{ width: "20px", height: "20px", color: "var(--accent)", flexShrink: 0 }} />
                    <p style={{ fontSize: "var(--text-caption)", color: "var(--accent)" }}>
                      Ce plan personnalisé a été conçu selon les exigences spécifiques de <strong>{scholarship.titre}</strong> et ton profil académique.
                    </p>
                  </div>
                  <FormattedText content={plan} />
                </div>
              )}

              {activeTab === "letter" && (
                <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-4)" }}>
                  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                    <h3 style={{ fontWeight: 700, fontSize: "var(--text-body)", color: "var(--ink-text)" }}>Brouillon de Lettre Généré par FlyAgent</h3>
                    <button
                      onClick={handleCopyLetter}
                      className="btn-primary"
                      style={{ padding: "var(--space-1.5) var(--space-3)", borderRadius: "var(--radius-xl)", fontWeight: 700, fontSize: "var(--text-caption)", boxShadow: "var(--shadow-md)" }}
                    >
                      <Copy style={{ width: "14px", height: "14px" }} />
                      <span>{copied ? "Copié !" : "Copier le texte"}</span>
                    </button>
                  </div>

                  <textarea
                    rows={12}
                    value={motivationLetter}
                    onChange={(e) => setMotivationLetter(e.target.value)}
                    style={{ width: "100%", padding: "var(--space-4)", borderRadius: "var(--radius-xl)", background: "var(--warm-100)", border: "1px solid var(--border)", fontSize: "var(--text-caption)", lineHeight: 1.65, outline: "none", fontFamily: "monospace" }}
                  />
                </div>
              )}

              {activeTab === "checklist" && (
                <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-3)" }}>
                  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                    <h3 style={{ fontWeight: 700, fontSize: "var(--text-body)", color: "var(--ink-text)" }}>Checklist des Documents pour {scholarship?.titre}</h3>
                    <span style={{ fontSize: "10px", fontWeight: 700, color: "var(--success)", background: "var(--success-light)", padding: "4px 8px", borderRadius: "var(--radius-full)" }}>
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
        <div style={{ padding: "var(--space-4)", borderTop: "1px solid var(--border)", background: "var(--warm-100)", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <span style={{ fontSize: "var(--text-caption)", color: "var(--ink-muted)" }}>Ajouté automatiquement à tes candidatures</span>
          <button onClick={onClose} className="btn-primary" style={{ padding: "var(--space-2.5) var(--space-6)", borderRadius: "var(--radius-xl)", fontWeight: 700, fontSize: "var(--text-caption)" }}>
            Terminer & Fermer
          </button>
        </div>
      </div>
    </div>
  );
}
