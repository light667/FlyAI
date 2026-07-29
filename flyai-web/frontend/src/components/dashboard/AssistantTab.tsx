"use client";

import { useState, useEffect, useRef } from "react";
import { ChatMessage, ChatSession, UserProfile } from "@/types";
import { Sparkles, Send, User as UserIcon, Plus, MessageSquare, Clock, X, MessageCircle } from "lucide-react";
import FormattedText from "@/components/FormattedText";

interface Props {
  userId?: string;
  userProfile?: UserProfile | null;
}

const QUICK_PROMPTS = [
  "Analyse mon CV et donne des améliorations",
  "Écris-moi une lettre de motivation pour une opportunité",
  "Quels sont les différents tests de langues qui existent, combien ils coûtent et où les faire ?",
  "Comment avoir un passeport, quels sont les dossiers à fournir ?",
  "Comment avoir un visa d'études pour un pays spécifique ?",
];

export default function AssistantTab({ userId, userProfile }: Props) {
  const [sessions, setSessions] = useState<ChatSession[]>([]);
  const [activeSessionId, setActiveSessionId] = useState<string | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [inputMessage, setInputMessage] = useState("");
  const [sending, setSending] = useState(false);
  const [showHistory, setShowHistory] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  useEffect(() => { scrollToBottom(); }, [messages]);

  // Charger les sessions de l'utilisateur
  const fetchSessions = async () => {
    if (!userId) return;
    try {
      const res = await fetch(`/api/chat?userId=${userId}`);
      const json = await res.json();
      if (json.data) {
        setSessions(json.data);
      }
    } catch (e) {
      console.error("Error fetching sessions:", e);
    }
  };

  useEffect(() => {
    fetchSessions();
  }, [userId]);

  // Charger les messages de la session active
  useEffect(() => {
    if (!activeSessionId) return;
    fetch(`/api/chat?sessionId=${activeSessionId}`)
      .then((r) => r.json())
      .then((json) => { if (json.data) setMessages(json.data); })
      .catch(console.error);
  }, [activeSessionId]);

  const handleSend = async (text?: string) => {
    const msg = text || inputMessage.trim();
    if (!msg || sending) return;

    const tempMsg: ChatMessage = {
      id: Date.now().toString(),
      sessionId: activeSessionId || "",
      sender: "user",
      content: msg,
      createdAt: new Date().toISOString(),
    };

    setMessages((prev) => [...prev, tempMsg]);
    if (!text) setInputMessage("");
    setSending(true);

    try {
      const res = await fetch("/api/chat", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ userId, sessionId: activeSessionId, message: msg, userProfile }),
      });
      const json = await res.json();
      if (json.reply) {
        const newSessId = json.sessionId || activeSessionId;
        if (newSessId && newSessId !== activeSessionId) {
          setActiveSessionId(newSessId);
        }
        await fetchSessions();
        setMessages((prev) => [
          ...prev,
          {
            id: (Date.now() + 1).toString(),
            sessionId: newSessId || "",
            sender: "assistant",
            content: json.reply,
            createdAt: new Date().toISOString(),
          },
        ]);
      }
    } catch (err) {
      console.error("FlyAgent error", err);
    } finally {
      setSending(false);
    }
  };

  const handleNewSession = () => {
    setActiveSessionId(null);
    setMessages([]);
    setShowHistory(false);
  };

  const handleSelectSession = (sessionId: string) => {
    setActiveSessionId(sessionId);
    setShowHistory(false);
  };

  return (
    <div style={{ height: "calc(100vh - 90px)", width: "100%", display: "flex", flexDirection: "column", position: "relative" }}>

      {/* ── Chat Container (Plein Écran sous la barre) ── */}
      <div style={{
        flex: 1,
        display: "flex",
        flexDirection: "column",
        background: "var(--warm-50)",
        border: "1px solid var(--border)",
        borderRadius: "var(--radius-xl)",
        overflow: "hidden",
        width: "100%",
        height: "100%",
      }}>

        {/* Header avec boutons agrandis et tooltips sur hover */}
        <div style={{
          padding: "var(--space-3) var(--space-6)",
          borderBottom: "1px solid var(--border)",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          background: "var(--warm-100)",
          minHeight: "64px",
        }}>
          <div style={{ display: "flex", alignItems: "center", gap: "var(--space-3)" }}>
            <div style={{
              width: 40, height: 40, borderRadius: "var(--radius-lg)",
              background: "var(--accent)",
              display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0,
              boxShadow: "0 2px 8px rgba(15,123,108,0.3)",
            }}>
              <Sparkles size={20} color="white" />
            </div>
            <div>
              <h3 style={{
                fontFamily: "var(--font-body)", fontSize: "1.1rem", fontWeight: 700,
                color: "var(--ink-text)", margin: 0, display: "flex", alignItems: "center", gap: "var(--space-2)",
              }}>
                FlyAgent
                <span style={{
                  fontSize: "10px", fontWeight: 700,
                  padding: "2px 8px", borderRadius: "var(--radius-full)",
                  border: "1px solid var(--accent)", color: "var(--accent)",
                  background: "var(--accent-light)", textTransform: "uppercase", letterSpacing: "0.04em",
                }}>
                  Copilote
                </span>
              </h3>
            </div>
          </div>

          {/* ✅ FIX: Boutons Historique et Nouvelle discussion plus grands avec icônes + tooltips */}
          <div style={{ display: "flex", alignItems: "center", gap: "var(--space-3)" }}>
            {/* Bouton Historique */}
            <button
              onClick={() => { fetchSessions(); setShowHistory(!showHistory); }}
              title="Historique des discussions (cliquer pour ouvrir)"
              style={{
                display: "flex", alignItems: "center", gap: "var(--space-2)",
                padding: "10px 16px",
                borderRadius: "var(--radius-xl)", border: "1px solid var(--border)",
                background: showHistory ? "var(--accent)" : "var(--warm-50)",
                color: showHistory ? "white" : "var(--ink-text)",
                cursor: "pointer", fontSize: "var(--text-body)", fontWeight: 700,
                transition: "all var(--transition-base)",
                boxShadow: "var(--shadow-sm)",
              }}
            >
              <Clock size={18} />
              <span>Historique</span>
              {sessions.length > 0 && (
                <span style={{
                  background: showHistory ? "white" : "var(--accent)",
                  color: showHistory ? "var(--accent)" : "white",
                  borderRadius: "50%", width: 20, height: 20,
                  display: "flex", alignItems: "center", justifyContent: "center",
                  fontSize: "11px", fontWeight: 800,
                }}>
                  {sessions.length}
                </span>
              )}
            </button>

            {/* Bouton Nouvelle discussion */}
            <button
              onClick={handleNewSession}
              title="Nouvelle discussion (démarrer un nouveau sujet)"
              className="btn-primary"
              style={{
                display: "flex", alignItems: "center", gap: "var(--space-2)",
                padding: "10px 18px", borderRadius: "var(--radius-xl)",
                fontSize: "var(--text-body)", fontWeight: 700, cursor: "pointer",
                boxShadow: "var(--shadow-md)",
              }}
            >
              <Plus size={18} />
              <span>Nouvelle discussion</span>
            </button>
          </div>
        </div>

        {/* Messages Body */}
        <div
          className="custom-scrollbar"
          style={{ flex: 1, padding: "var(--space-6)", overflowY: "auto", display: "flex", flexDirection: "column", gap: "var(--space-4)" }}
        >
          {messages.length === 0 ? (
            <div style={{
              flex: 1, display: "flex", flexDirection: "column",
              alignItems: "center", justifyContent: "center", textAlign: "center",
              maxWidth: "750px", margin: "0 auto", gap: "var(--space-6)", padding: "var(--space-6) 0",
              width: "100%",
            }}>
              <div style={{
                width: 64, height: 64, borderRadius: "50%",
                border: "2px solid var(--accent)", background: "var(--accent-light)",
                display: "flex", alignItems: "center", justifyContent: "center",
                boxShadow: "0 4px 16px rgba(15,123,108,0.2)",
              }}>
                <Sparkles size={32} style={{ color: "var(--accent)" }} />
              </div>

              <div>
                <h3 style={{ fontFamily: "var(--font-body)", fontSize: "1.4rem", fontWeight: 800, color: "var(--ink-text)", margin: "0 0 8px" }}>
                  Comment puis-je vous aider aujourd'hui ?
                </h3>
                <p style={{ fontSize: "var(--text-body)", color: "var(--ink-muted)", margin: 0 }}>
                  Sélectionnez une suggestion ci-dessous ou écrivez directement votre question.
                </p>
              </div>

              {/* ✅ FIX: Espace augmenté entre les propositions de questions (gap-4) */}
              <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-3.5)", width: "100%" }}>
                {QUICK_PROMPTS.map((prompt, i) => (
                  <button
                    key={i}
                    onClick={() => handleSend(prompt)}
                    className="btn-secondary"
                    style={{
                      textAlign: "left", fontSize: "var(--text-body)", fontWeight: 600,
                      padding: "var(--space-4) var(--space-5)", lineHeight: 1.5,
                      display: "flex", alignItems: "center", gap: "var(--space-3)",
                      justifyContent: "flex-start", width: "100%",
                      borderRadius: "var(--radius-xl)",
                      border: "1px solid var(--border)",
                      background: "var(--warm-100)",
                      cursor: "pointer",
                      transition: "all var(--transition-base)",
                      boxShadow: "var(--shadow-sm)",
                    }}
                    onMouseEnter={(e) => {
                      (e.currentTarget as HTMLButtonElement).style.borderColor = "var(--accent)";
                      (e.currentTarget as HTMLButtonElement).style.transform = "translateY(-2px)";
                    }}
                    onMouseLeave={(e) => {
                      (e.currentTarget as HTMLButtonElement).style.borderColor = "var(--border)";
                      (e.currentTarget as HTMLButtonElement).style.transform = "translateY(0)";
                    }}
                  >
                    <Sparkles size={16} style={{ color: "var(--accent)", flexShrink: 0 }} />
                    <span>{prompt}</span>
                  </button>
                ))}
              </div>
            </div>
          ) : (
            messages.map((msg) => {
              const isUser = msg.sender === "user";
              return (
                <div
                  key={msg.id}
                  style={{
                    display: "flex", gap: "var(--space-3)", maxWidth: "850px",
                    flexDirection: isUser ? "row-reverse" : "row",
                    marginLeft: isUser ? "auto" : 0,
                  }}
                >
                  <div style={{
                    width: 34, height: 34, borderRadius: "var(--radius-lg)",
                    background: isUser ? "var(--ink-800)" : "var(--accent)",
                    border: "1px solid var(--border)",
                    display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0,
                  }}>
                    {isUser
                      ? <UserIcon size={16} color="white" />
                      : <Sparkles size={16} color="white" />
                    }
                  </div>
                  <div style={{
                    padding: "var(--space-4) var(--space-5)", borderRadius: "var(--radius-2xl)",
                    fontSize: "var(--text-body)", lineHeight: 1.65, whiteSpace: "pre-line",
                    background: isUser ? "var(--ink-800)" : "var(--warm-100)",
                    color: isUser ? "#ffffff" : "var(--ink-text)",
                    border: `1px solid ${isUser ? "var(--ink-700)" : "var(--border)"}`,
                    boxShadow: "var(--shadow-sm)",
                  }}>
                    <FormattedText content={msg.content} />
                  </div>
                </div>
              );
            })
          )}

          {/* Indicateur de chargement */}
          {sending && (
            <div style={{ display: "flex", gap: "var(--space-3)", alignItems: "center" }}>
              <div style={{
                width: 34, height: 34, borderRadius: "var(--radius-lg)",
                background: "var(--accent)", border: "1px solid var(--border)",
                display: "flex", alignItems: "center", justifyContent: "center",
              }}>
                <Sparkles size={16} color="white" />
              </div>
              <div style={{
                padding: "var(--space-3) var(--space-5)", borderRadius: "var(--radius-2xl)",
                border: "1px solid var(--border)", background: "var(--warm-100)",
                display: "flex", alignItems: "center", gap: "var(--space-2)",
              }}>
                {[0, 1, 2].map((i) => (
                  <span key={i} style={{
                    width: 6, height: 6, borderRadius: "50%",
                    background: "var(--accent)", display: "inline-block",
                    animation: `pulse 1.2s ease-in-out ${i * 0.2}s infinite`,
                  }} />
                ))}
                <span style={{ fontSize: "var(--text-body)", fontWeight: 600, color: "var(--ink-subtle)", marginLeft: "var(--space-1)" }}>
                  FlyAgent prépare une réponse...
                </span>
              </div>
            </div>
          )}

          <div ref={messagesEndRef} />
        </div>

        {/* ✅ FIX: Barre de message élargie en largeur avec bouton d'envoi parfaitement intégré */}
        <div style={{ padding: "var(--space-4) var(--space-6)", borderTop: "1px solid var(--border)", background: "var(--warm-100)" }}>
          <form
            onSubmit={(e) => { e.preventDefault(); handleSend(); }}
            style={{
              display: "flex", alignItems: "center", gap: "var(--space-3)",
              background: "var(--warm-50)", border: "1.5px solid var(--border)",
              borderRadius: "var(--radius-2xl)", padding: "8px 12px 8px 20px",
              width: "100%", maxWidth: "900px", margin: "0 auto",
              boxShadow: "var(--shadow-md)",
              transition: "border-color var(--transition-base)",
            }}
            onFocusCapture={(e) => (e.currentTarget.style.borderColor = "var(--accent)")}
            onBlurCapture={(e) => (e.currentTarget.style.borderColor = "var(--border)")}
          >
            <input
              type="text"
              placeholder="Posez votre question à FlyAgent (dossier, visa, tests de langue, CV...)..."
              value={inputMessage}
              onChange={(e) => setInputMessage(e.target.value)}
              style={{
                flex: 1, background: "transparent", border: "none", outline: "none",
                fontSize: "var(--text-body)", color: "var(--ink-text)",
                padding: "6px 0", width: "100%",
              }}
            />
            <button
              type="submit"
              disabled={!inputMessage.trim() || sending}
              className="btn-primary"
              style={{
                width: "44px", height: "44px", borderRadius: "var(--radius-xl)",
                display: "flex", alignItems: "center", justifyContent: "center",
                flexShrink: 0, opacity: !inputMessage.trim() || sending ? 0.4 : 1,
                padding: 0, cursor: !inputMessage.trim() || sending ? "not-allowed" : "pointer",
                boxShadow: "0 2px 8px rgba(15,123,108,0.3)",
              }}
              title="Envoyer le message"
            >
              <Send size={18} color="white" />
            </button>
          </form>
        </div>
      </div>

      {/* ✅ FIX: Panneau Historique fonctionnel permettant d'ouvrir et continuer une ancienne discussion */}
      {showHistory && (
        <div
          style={{
            position: "absolute", top: 0, left: 0, right: 0, bottom: 0,
            background: "rgba(0,0,0,0.5)", zIndex: 50, borderRadius: "var(--radius-xl)",
            display: "flex", alignItems: "flex-start", justifyContent: "flex-end",
          }}
          onClick={() => setShowHistory(false)}
        >
          <div
            style={{
              width: "min(360px, 90%)", height: "100%",
              background: "var(--warm-50)", borderLeft: "1px solid var(--border)",
              borderRadius: "0 var(--radius-xl) var(--radius-xl) 0",
              display: "flex", flexDirection: "column",
              boxShadow: "var(--shadow-xl)",
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div style={{
              padding: "var(--space-4) var(--space-5)",
              borderBottom: "1px solid var(--border)",
              display: "flex", alignItems: "center", justifyContent: "space-between",
              background: "var(--warm-100)",
            }}>
              <div style={{ display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
                <Clock size={18} style={{ color: "var(--accent)" }} />
                <span style={{ fontWeight: 700, fontSize: "var(--text-body)", color: "var(--ink-text)" }}>
                  Historique des discussions ({sessions.length})
                </span>
              </div>
              <button
                onClick={() => setShowHistory(false)}
                style={{ background: "none", border: "none", cursor: "pointer", color: "var(--ink-subtle)", padding: 4 }}
              >
                <X size={18} />
              </button>
            </div>

            <div style={{ padding: "var(--space-3) var(--space-4)", borderBottom: "1px solid var(--border)" }}>
              <button
                onClick={handleNewSession}
                className="btn-primary"
                style={{ justifyContent: "center", width: "100%", fontSize: "var(--text-body)", fontWeight: 700, padding: "10px" }}
              >
                <Plus size={16} />
                Démarrer une nouvelle discussion
              </button>
            </div>

            <div className="custom-scrollbar flex-1 overflow-y-auto" style={{ padding: "var(--space-3)" }}>
              {sessions.length === 0 ? (
                <div style={{ padding: "var(--space-8)", textAlign: "center", color: "var(--ink-muted)" }}>
                  <MessageCircle size={32} style={{ margin: "0 auto var(--space-2)", opacity: 0.5 }} />
                  <p style={{ fontSize: "var(--text-body)", margin: 0 }}>Aucune discussion passée</p>
                </div>
              ) : (
                sessions.map((sess) => (
                  <button
                    key={sess.id}
                    onClick={() => handleSelectSession(sess.id)}
                    style={{
                      display: "flex", alignItems: "center", gap: "var(--space-3)",
                      padding: "var(--space-3.5)",
                      borderRadius: "var(--radius-xl)", textAlign: "left",
                      background: activeSessionId === sess.id ? "var(--accent-light)" : "var(--warm-100)",
                      border: activeSessionId === sess.id ? "1.5px solid var(--accent)" : "1px solid var(--border)",
                      color: activeSessionId === sess.id ? "var(--accent)" : "var(--ink-text)",
                      fontSize: "var(--text-body)",
                      fontWeight: activeSessionId === sess.id ? 700 : 500,
                      cursor: "pointer", width: "100%",
                      marginBottom: "var(--space-2)",
                      transition: "all var(--transition-base)",
                    }}
                  >
                    <MessageSquare size={16} style={{ flexShrink: 0, opacity: 0.8 }} />
                    <div style={{ overflow: "hidden", flex: 1 }}>
                      <span style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", display: "block" }}>
                        {sess.title}
                      </span>
                      <span style={{ fontSize: "11px", color: "var(--ink-subtle)", marginTop: 2, display: "block" }}>
                        {new Date(sess.createdAt).toLocaleDateString("fr-FR", { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" })}
                      </span>
                    </div>
                  </button>
                ))
              )}
            </div>
          </div>
        </div>
      )}

      <style>{`
        @keyframes pulse {
          0%, 80%, 100% { opacity: 0.2; transform: scale(0.8); }
          40% { opacity: 1; transform: scale(1); }
        }
      `}</style>
    </div>
  );
}