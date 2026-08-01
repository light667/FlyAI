"use client";

import { useState, useEffect, useRef } from "react";
import { ChatMessage, ChatSession, UserProfile } from "@/types";
import { Bot, Send, User as UserIcon, Plus, MessageSquare, Clock, X, Trash2, MessageCircle, Sparkles } from "lucide-react";
import FormattedText from "@/components/FormattedText";

interface Props {
  userId?: string;
  userProfile?: UserProfile | null;
}

const QUICK_PROMPTS = [
  "📄 Analyser mon CV et proposer des améliorations",
  "🎯 Vérifier mon éligibilité et postuler à une bourse",
  "✉️ Rédiger une lettre de motivation sur mesure",
  "🌍 Guide des tests de langue (TOEFL, IELTS, TCF) et visas",
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

  // Fetch all sessions for user
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

  // Fetch messages for active session
  useEffect(() => {
    if (!activeSessionId) return;
    fetch(`/api/chat?sessionId=${activeSessionId}`)
      .then((r) => r.json())
      .then((json) => {
        if (json.data) {
          const formatted = json.data.map((m: any) => ({
            id: m.id,
            sessionId: m.session_id || m.sessionId,
            sender: m.sender,
            content: m.content,
            createdAt: m.created_at || m.createdAt || new Date().toISOString(),
          }));
          setMessages(formatted);
        }
      })
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
    <div style={{ height: "calc(100vh - 120px)", width: "100%", display: "flex", flexDirection: "column", position: "relative" }}>

      {/* ── Chat Main Window ── */}
      <div style={{
        flex: 1,
        display: "flex",
        flexDirection: "column",
        background: "var(--warm-50)",
        border: "1px solid var(--border)",
        borderRadius: "16px",
        overflow: "hidden",
        width: "100%",
        height: "100%",
      }}>

        {/* Header */}
        <div style={{
          padding: "10px 16px",
          borderBottom: "1px solid var(--border)",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          background: "var(--warm-100)",
          minHeight: "56px",
        }}>
          <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
            <div style={{
              width: 36, height: 36, borderRadius: "10px",
              background: "#0f7b6c",
              display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0,
              boxShadow: "0 2px 8px rgba(15,123,108,0.3)",
            }}>
              <Bot size={20} color="white" />
            </div>
            <div>
              <h3 style={{
                fontSize: "0.95rem", fontWeight: 800,
                color: "var(--ink-text)", margin: 0, display: "flex", alignItems: "center", gap: "6px",
              }}>
                FlyAgent Copilote
                <span style={{
                  fontSize: "9px", fontWeight: 800,
                  padding: "1px 6px", borderRadius: "9999px",
                  border: "1px solid var(--accent)", color: "var(--accent)",
                  background: "var(--accent-light)", textTransform: "uppercase",
                }}>
                  Agent Autonome
                </span>
              </h3>
            </div>
          </div>

          <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
            <button
              onClick={() => { fetchSessions(); setShowHistory(!showHistory); }}
              title="Historique des discussions"
              style={{
                display: "flex", alignItems: "center", gap: "6px",
                padding: "6px 12px",
                borderRadius: "10px", border: "1px solid var(--border)",
                background: showHistory ? "var(--accent)" : "var(--warm-50)",
                color: showHistory ? "white" : "var(--ink-text)",
                cursor: "pointer", fontSize: "0.78rem", fontWeight: 700,
              }}
            >
              <Clock size={15} />
              <span className="hidden sm:inline">Historique</span>
              {sessions.length > 0 && (
                <span style={{
                  background: showHistory ? "white" : "var(--accent)",
                  color: showHistory ? "var(--accent)" : "white",
                  borderRadius: "50%", width: 18, height: 18,
                  display: "flex", alignItems: "center", justifyContent: "center",
                  fontSize: "10px", fontWeight: 800,
                }}>
                  {sessions.length}
                </span>
              )}
            </button>

            <button
              onClick={handleNewSession}
              title="Nouvelle discussion"
              className="btn-primary"
              style={{
                display: "flex", alignItems: "center", gap: "6px",
                padding: "6px 14px", borderRadius: "10px",
                fontSize: "0.78rem", fontWeight: 700, cursor: "pointer",
              }}
            >
              <Plus size={15} />
              <span className="hidden sm:inline">Nouveau</span>
            </button>
          </div>
        </div>

        {/* Messages Body */}
        <div
          className="custom-scrollbar"
          style={{ flex: 1, padding: "16px", overflowY: "auto", display: "flex", flexDirection: "column", gap: "12px" }}
        >
          {messages.length === 0 ? (
            <div style={{
              flex: 1, display: "flex", flexDirection: "column",
              alignItems: "center", justifyContent: "center", textAlign: "center",
              maxWidth: "680px", margin: "0 auto", gap: "16px", padding: "12px 0",
              width: "100%",
            }}>
              <div style={{
                width: 52, height: 52, borderRadius: "50%",
                border: "2px solid var(--accent)", background: "var(--accent-light)",
                display: "flex", alignItems: "center", justifyContent: "center",
                boxShadow: "0 4px 12px rgba(15,123,108,0.2)",
              }}>
                <Bot size={28} style={{ color: "var(--accent)" }} />
              </div>

              <div>
                <h3 style={{ fontSize: "1.15rem", fontWeight: 800, color: "var(--ink-text)", margin: "0 0 4px" }}>
                  Comment FlyAgent peut vous accompagner aujourd'hui ?
                </h3>
                <p style={{ fontSize: "0.78rem", color: "var(--ink-muted)", margin: 0 }}>
                  FlyAgent analyse votre CV, trouve les liens officiels de candidatures, et agit à votre place.
                </p>
              </div>

              <div style={{ display: "flex", flexDirection: "column", gap: "8px", width: "100%" }}>
                {QUICK_PROMPTS.map((prompt, i) => (
                  <button
                    key={i}
                    onClick={() => handleSend(prompt)}
                    className="btn-secondary"
                    style={{
                      textAlign: "left", fontSize: "0.8rem", fontWeight: 600,
                      padding: "10px 14px", lineHeight: 1.4,
                      display: "flex", alignItems: "center", gap: "10px",
                      justifyContent: "flex-start", width: "100%",
                      borderRadius: "12px",
                      border: "1px solid var(--border)",
                      background: "var(--warm-100)",
                      cursor: "pointer",
                      transition: "all 0.2s ease",
                    }}
                  >
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
                    display: "flex", gap: "10px", maxWidth: "800px",
                    flexDirection: isUser ? "row-reverse" : "row",
                    marginLeft: isUser ? "auto" : 0,
                  }}
                >
                  <div style={{
                    width: 32, height: 32, borderRadius: "8px",
                    background: isUser ? "var(--ink-800)" : "#0f7b6c",
                    border: "1px solid var(--border)",
                    display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0,
                  }}>
                    {isUser
                      ? <UserIcon size={15} color="white" />
                      : <Bot size={15} color="white" />
                    }
                  </div>
                  <div style={{
                    padding: "10px 14px", borderRadius: "14px",
                    fontSize: "0.82rem", lineHeight: 1.55, whiteSpace: "pre-line",
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

          {/* Loading Indicator */}
          {sending && (
            <div style={{ display: "flex", gap: "10px", alignItems: "center" }}>
              <div style={{
                width: 32, height: 32, borderRadius: "8px",
                background: "#0f7b6c", border: "1px solid var(--border)",
                display: "flex", alignItems: "center", justifyContent: "center",
              }}>
                <Bot size={15} color="white" />
              </div>
              <div style={{
                padding: "8px 12px", borderRadius: "14px",
                border: "1px solid var(--border)", background: "var(--warm-100)",
                display: "flex", alignItems: "center", gap: "6px",
              }}>
                {[0, 1, 2].map((i) => (
                  <span key={i} style={{
                    width: 5, height: 5, borderRadius: "50%",
                    background: "var(--accent)", display: "inline-block",
                    animation: `pulse 1.2s ease-in-out ${i * 0.2}s infinite`,
                  }} />
                ))}
                <span style={{ fontSize: "0.78rem", fontWeight: 600, color: "var(--ink-subtle)", marginLeft: "4px" }}>
                  FlyAgent recherche et analyse vos données...
                </span>
              </div>
            </div>
          )}

          <div ref={messagesEndRef} />
        </div>

        {/* Input Bar */}
        <div style={{ padding: "10px 12px", borderTop: "1px solid var(--border)", background: "var(--warm-100)" }}>
          <form
            onSubmit={(e) => { e.preventDefault(); handleSend(); }}
            style={{
              display: "flex", alignItems: "center", gap: "8px",
              background: "var(--warm-50)", border: "1.5px solid var(--border)",
              borderRadius: "14px", padding: "4px 8px 4px 14px",
              width: "100%", maxWidth: "850px", margin: "0 auto",
              boxShadow: "var(--shadow-sm)",
            }}
          >
            <input
              type="text"
              placeholder="Posez votre question à FlyAgent (analyse CV, postulation, bourses, statut)..."
              value={inputMessage}
              onChange={(e) => setInputMessage(e.target.value)}
              style={{
                flex: 1, background: "transparent", border: "none", outline: "none",
                fontSize: "0.82rem", color: "var(--ink-text)",
                padding: "6px 0", width: "100%",
              }}
            />
            <button
              type="submit"
              disabled={!inputMessage.trim() || sending}
              style={{
                width: "38px", height: "38px", borderRadius: "10px",
                display: "flex", alignItems: "center", justifyContent: "center",
                flexShrink: 0, 
                backgroundColor: "#0f7b6c",
                color: "#ffffff",
                border: "none",
                opacity: !inputMessage.trim() || sending ? 0.4 : 1,
                padding: 0, 
                cursor: !inputMessage.trim() || sending ? "not-allowed" : "pointer",
                boxShadow: "0 2px 8px rgba(15,123,108,0.3)",
              }}
              title="Envoyer le message"
            >
              <Send size={16} color="#ffffff" />
            </button>
          </form>
        </div>
      </div>

      {/* History Drawer */}
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
                sessions.map((sess) => {
                  const dateStr = sess.createdAt || (sess as any).created_at;
                  return (
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
                        {dateStr && (
                          <span style={{ fontSize: "11px", color: "var(--ink-subtle)", marginTop: 2, display: "block" }}>
                            {new Date(dateStr).toLocaleDateString("fr-FR", { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" })}
                          </span>
                        )}
                      </div>
                    </button>
                  );
                })
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