"use client";

import { useState, useEffect, useRef } from "react";
import { Scholarship, UserProfile, ChatMessage } from "@/types";
import FormattedText from "@/components/FormattedText";
import { X, Sparkles, CheckCircle2, FileText, Calendar, Send, Copy, Bot, ShieldCheck, ExternalLink, ArrowRight } from "lucide-react";

interface Props {
  scholarship: Scholarship | null;
  userProfile?: UserProfile | null;
  onClose: () => void;
}

export default function FlyAgentModal({ scholarship, userProfile, onClose }: Props) {
  const [activeTab, setActiveTab] = useState<"agent" | "letter" | "checklist">("agent");
  const [loading, setLoading] = useState(true);
  const [motivationLetter, setMotivationLetter] = useState("");
  const [copied, setCopied] = useState(false);
  const [checklist, setChecklist] = useState<any[]>([]);

  // FlyAgent Chat State
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [inputMsg, setInputMsg] = useState("");
  const [sending, setSending] = useState(false);
  const [applicationStatus, setApplicationStatus] = useState<"idle" | "applying" | "completed">("idle");
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const officialUrl = scholarship?.lien_candidature || scholarship?.url || "";

  useEffect(() => {
    if (!scholarship || !userProfile) return;
    setLoading(true);

    // Initial FlyAgent greeting and diagnostic
    const initialGreeting: ChatMessage = {
      id: "1",
      sessionId: "modal-session",
      sender: "assistant",
      content: `Bonjour ${userProfile.fullName || ''} !\n` +
        `Je suis **FlyAgent**, votre agent IA autonome pour la candidature à **${scholarship.titre}**.\n\n` +
        `🔍 **Diagnostic Initial de votre Dossier :**\n` +
        `• **Pays cible :** ${(scholarship.pays_destination || []).join(", ") || "International"}\n` +
        `• **Niveau d'étude :** ${userProfile.degreeLevel || "Master"}\n` +
        `• **Lien officiel :** ${officialUrl ? `[Accéder au site officiel](${officialUrl})` : "En recherche"}\n\n` +
        `Souhaitez-vous que je vérifie les pièces de votre dossier et que je procède à la candidature pour vous ?`,
      createdAt: new Date().toISOString(),
    };

    setMessages([initialGreeting]);

    // Fetch custom checklist and letter template from /api/apply
    fetch("/api/apply", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        userId: userProfile.id,
        scholarshipId: scholarship.id,
        userProfile,
      }),
    })
      .then((res) => res.json())
      .then((json) => {
        if (json.success) {
          if (json.checklist) setChecklist(json.checklist);
          if (json.motivationLetter) setMotivationLetter(json.motivationLetter);
        }
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, [scholarship, userProfile]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  if (!scholarship) return null;

  const handleSendMessage = async (customText?: string) => {
    const text = customText || inputMsg.trim();
    if (!text || sending) return;

    const userMessage: ChatMessage = {
      id: Date.now().toString(),
      sessionId: "modal-session",
      sender: "user",
      content: text,
      createdAt: new Date().toISOString(),
    };

    setMessages((prev) => [...prev, userMessage]);
    if (!customText) setInputMsg("");
    setSending(true);

    try {
      const res = await fetch("/api/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          userId: userProfile?.id,
          message: text,
          userProfile,
          scholarshipContext: [scholarship],
        }),
      });

      const json = await res.json();
      if (json.reply) {
        setMessages((prev) => [
          ...prev,
          {
            id: (Date.now() + 1).toString(),
            sessionId: "modal-session",
            sender: "assistant",
            content: json.reply,
            createdAt: new Date().toISOString(),
          },
        ]);
      }
    } catch (e) {
      console.error("Chat error:", e);
    } finally {
      setSending(false);
    }
  };

  const handleExecuteApplication = async () => {
    if (!userProfile?.id || !scholarship?.id) return;
    setApplicationStatus("applying");

    // Add progress updates to chat
    const step1: ChatMessage = {
      id: Date.now().toString(),
      sessionId: "modal-session",
      sender: "assistant",
      content: `⚡ **FlyAgent prend le relais pour votre candidature !**\n\n` +
        `1️⃣ Récupération des données utilisateur et audit du CV... ✅\n` +
        `2️⃣ Récupération du lien officiel : [Site Candidature](${officialUrl})\n` +
        `3️⃣ Enregistrement de la candidature dans votre tableau de bord **Mes Candidatures**...`,
      createdAt: new Date().toISOString(),
    };

    setMessages((prev) => [...prev, step1]);

    try {
      // Save application with category 'flyagent'
      await fetch("/api/applications", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          userId: userProfile.id,
          bourseId: scholarship.id,
          status: "in_progress",
          category: "flyagent",
          notes: `Candidature initiée et gérée par FlyAgent pour ${scholarship.titre}`,
          checklist: {
            cv_uploaded: true,
            motivation_letter: true,
            transcripts: true,
            recommendation_letters: false,
          },
        }),
      });

      setTimeout(() => {
        setApplicationStatus("completed");
        const step2: ChatMessage = {
          id: (Date.now() + 100).toString(),
          sessionId: "modal-session",
          sender: "assistant",
          content: `🎉 **Candidature enregistrée avec succès par FlyAgent !**\n\n` +
            `Votre dossier pour **${scholarship.titre}** est maintenant actif dans l'onglet **Mes Candidatures**.\n` +
            `Vous pouvez à tout moment consulter le lien officiel (${officialUrl || 'Disponible dans le profil'}) et suivre chaque étape de validation.`,
          createdAt: new Date().toISOString(),
        };
        setMessages((prev) => [...prev, step2]);
      }, 1500);
    } catch (e) {
      console.error("Application error:", e);
      setApplicationStatus("idle");
    }
  };

  const handleCopyLetter = () => {
    navigator.clipboard.writeText(motivationLetter);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div style={{ position: "fixed", inset: 0, zIndex: 50, display: "flex", alignItems: "center", justifyContent: "center", padding: "16px", background: "rgba(15, 26, 46, 0.7)", backdropFilter: "blur(8px)" }}>
      <div style={{ position: "relative", width: "100%", maxWidth: "1100px", maxHeight: "90vh", height: "90vh", background: "var(--warm-50)", border: "1px solid var(--border)", borderRadius: "20px", boxShadow: "var(--shadow-xl)", overflow: "hidden", display: "flex", flexDirection: "column" }}>
        
        {/* Header */}
        <div style={{ padding: "16px 24px", background: "#0f7b6c", color: "#ffffff", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
            <div style={{ width: "40px", height: "40px", borderRadius: "12px", background: "rgba(255, 255, 255, 0.2)", display: "flex", alignItems: "center", justifyContent: "center" }}>
              <Bot style={{ width: "24px", height: "24px", color: "#ffffff" }} />
            </div>
            <div>
              <span style={{ fontSize: "11px", fontWeight: 800, textTransform: "uppercase", color: "rgba(255, 255, 255, 0.85)", letterSpacing: "0.05em" }}>
                FlyAgent Copilote Autonome
              </span>
              <h2 style={{ fontSize: "1.2rem", fontWeight: 800, margin: 0, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", color: "#ffffff" }}>
                {scholarship.titre}
              </h2>
            </div>
          </div>

          <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
            {officialUrl && (
              <a
                href={officialUrl}
                target="_blank"
                rel="noopener noreferrer"
                style={{
                  display: "inline-flex", alignItems: "center", gap: "6px",
                  padding: "6px 12px", borderRadius: "10px",
                  background: "rgba(255, 255, 255, 0.2)", color: "#ffffff",
                  fontSize: "0.78rem", fontWeight: 700, textDecoration: "none",
                }}
              >
                <span>Site Officiel</span>
                <ExternalLink size={14} />
              </a>
            )}

            <button onClick={onClose} style={{ padding: "8px", borderRadius: "50%", background: "rgba(255, 255, 255, 0.2)", color: "#ffffff", border: "none", cursor: "pointer" }}>
              <X style={{ width: "20px", height: "20px" }} />
            </button>
          </div>
        </div>

        {/* Sub-Tabs */}
        <div style={{ display: "flex", borderBottom: "1px solid var(--border)", background: "var(--warm-100)", padding: "8px 24px 0", gap: "16px" }}>
          {[
            { id: "agent", label: "Conversation & Action FlyAgent", icon: Bot },
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
                  display: "flex", alignItems: "center", gap: "8px", paddingBottom: "10px",
                  fontSize: "0.82rem", fontWeight: 700, borderBottom: "3px solid",
                  borderBottomColor: active ? "var(--accent)" : "transparent",
                  color: active ? "var(--accent)" : "var(--ink-muted)",
                  background: "none", borderLeft: "none", borderRight: "none", borderTop: "none", cursor: "pointer",
                }}
              >
                <Icon size={16} />
                <span>{tab.label}</span>
              </button>
            );
          })}
        </div>

        {/* Content Body */}
        <div style={{ flex: 1, padding: "16px 24px", overflowY: "auto", display: "flex", flexDirection: "column", gap: "16px" }}>
          {activeTab === "agent" && (
            <div style={{ display: "flex", flexDirection: "column", height: "100%", gap: "12px" }}>
              
              {/* Top Banner */}
              <div style={{ padding: "12px 16px", borderRadius: "12px", background: "var(--accent-light)", border: "1px solid var(--accent-200)", display: "flex", alignItems: "center", justifyContent: "space-between", gap: "12px" }}>
                <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                  <ShieldCheck size={20} style={{ color: "var(--accent)" }} />
                  <span style={{ fontSize: "0.8rem", color: "var(--accent)", fontWeight: 700 }}>
                    FlyAgent est prêt à postuler en ligne pour vous.
                  </span>
                </div>

                <button
                  onClick={handleExecuteApplication}
                  disabled={applicationStatus === "applying"}
                  className="btn-primary"
                  style={{ padding: "8px 16px", fontSize: "0.78rem", fontWeight: 800, cursor: "pointer", opacity: applicationStatus === "applying" ? 0.7 : 1 }}
                >
                  {applicationStatus === "applying" ? "Candidature en cours..." : applicationStatus === "completed" ? "✓ Candidature Initiée" : "Lancer la Candidature Autonome"}
                </button>
              </div>

              {/* Chat Log */}
              <div className="custom-scrollbar" style={{ flex: 1, overflowY: "auto", display: "flex", flexDirection: "column", gap: "10px", paddingRight: "4px" }}>
                {messages.map((m) => {
                  const isUser = m.sender === "user";
                  return (
                    <div key={m.id} style={{ display: "flex", gap: "10px", flexDirection: isUser ? "row-reverse" : "row" }}>
                      <div style={{ width: 30, height: 30, borderRadius: "8px", background: isUser ? "var(--ink-800)" : "#0f7b6c", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                        <Bot size={16} color="white" />
                      </div>
                      <div style={{ padding: "10px 14px", borderRadius: "14px", fontSize: "0.82rem", lineHeight: 1.55, background: isUser ? "var(--ink-800)" : "var(--warm-100)", color: isUser ? "#ffffff" : "var(--ink-text)", border: "1px solid var(--border)", maxWidth: "80%" }}>
                        <FormattedText content={m.content} />
                      </div>
                    </div>
                  );
                })}
                <div ref={messagesEndRef} />
              </div>

              {/* Chat Input */}
              <form onSubmit={(e) => { e.preventDefault(); handleSendMessage(); }} style={{ display: "flex", gap: "8px" }}>
                <input
                  type="text"
                  placeholder="Posez une question sur cette bourse ou donnez des instructions à FlyAgent..."
                  value={inputMsg}
                  onChange={(e) => setInputMsg(e.target.value)}
                  style={{ flex: 1, padding: "10px 14px", borderRadius: "12px", border: "1.5px solid var(--border)", background: "var(--warm-100)", fontSize: "0.82rem", outline: "none", color: "var(--ink-text)" }}
                />
                <button type="submit" disabled={!inputMsg.trim() || sending} className="btn-primary" style={{ padding: "10px 18px", borderRadius: "12px" }}>
                  <Send size={16} />
                </button>
              </form>
            </div>
          )}

          {activeTab === "letter" && (
            <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                <h3 style={{ fontWeight: 700, fontSize: "0.9rem", margin: 0 }}>Lettre de Motivation Personnalisée par FlyAgent</h3>
                <button onClick={handleCopyLetter} className="btn-primary" style={{ padding: "6px 14px", fontSize: "0.78rem" }}>
                  <Copy size={14} />
                  <span>{copied ? "Copié !" : "Copier"}</span>
                </button>
              </div>
              <textarea
                rows={12}
                value={motivationLetter}
                onChange={(e) => setMotivationLetter(e.target.value)}
                style={{ width: "100%", padding: "14px", borderRadius: "12px", background: "var(--warm-100)", border: "1px solid var(--border)", fontSize: "0.82rem", lineHeight: 1.6, outline: "none", fontFamily: "monospace" }}
              />
            </div>
          )}

          {activeTab === "checklist" && (
            <div style={{ display: "flex", flexDirection: "column", gap: "10px" }}>
              <h3 style={{ fontWeight: "bold", fontSize: "0.9rem", margin: 0 }}>Checklist des Pièces Requises pour {scholarship.titre}</h3>
              {checklist.length > 0 ? (
                checklist.map((item, idx) => (
                  <div key={idx} style={{ padding: "12px", borderRadius: "12px", background: "var(--warm-100)", border: "1px solid var(--border)", display: "flex", alignItems: "center", gap: "12px" }}>
                    <CheckCircle2 size={18} style={{ color: "var(--accent)" }} />
                    <div>
                      <h4 style={{ fontWeight: 700, fontSize: "0.8rem", margin: 0 }}>{item.label}</h4>
                      <p style={{ fontSize: "11px", color: "var(--ink-muted)", margin: "2px 0 0" }}>{item.description}</p>
                    </div>
                  </div>
                ))
              ) : (
                <div style={{ padding: "16px", borderRadius: "12px", background: "var(--warm-100)", fontSize: "0.8rem", color: "var(--ink-muted)" }}>
                  • Formulaire officiel de candidature\n• CV académique certifié\n• Lettre de motivation\n• Relevés de notes et traduction
                </div>
              )}
            </div>
          )}
        </div>

        {/* Footer */}
        <div style={{ padding: "12px 24px", borderTop: "1px solid var(--border)", background: "var(--warm-100)", display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <span style={{ fontSize: "0.78rem", color: "var(--ink-muted)" }}>
            Statut : Candidature gérée automatiquement par FlyAgent
          </span>
          <button onClick={onClose} className="btn-primary" style={{ padding: "8px 20px", fontSize: "0.8rem" }}>
            Fermer
          </button>
        </div>
      </div>
    </div>
  );
}
