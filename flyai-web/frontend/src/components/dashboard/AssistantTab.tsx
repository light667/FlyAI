"use client";

import { useState, useEffect, useRef } from "react";
import { ChatMessage, ChatSession, UserProfile } from "@/types";
import { Sparkles, Send, User as UserIcon, Plus, MessageSquare } from "lucide-react";

interface Props {
  userId?: string;
  userProfile?: UserProfile | null;
}

// Â§8.1 â€” Amorces orientÃ©es action concrÃ¨te, vouvoiement, aucune promesse de rÃ©sultat
const QUICK_PROMPTS = [
  "Quels documents dois-je prÃ©parer pour candidater Ã  la bourse Eiffel ?",
  "Comment structurer mon projet d'Ã©tudes pour une lettre de motivation convaincante ?",
  "Quels sont les critÃ¨res Ã©liminatoires d'Erasmus Mundus pour mon niveau ?",
  "Quels tests de langue sont exigÃ©s et comment planifier leur passage ?",
];

export default function AssistantTab({ userId, userProfile }: Props) {
  const [sessions, setSessions] = useState<ChatSession[]>([]);
  const [activeSessionId, setActiveSessionId] = useState<string | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [inputMessage, setInputMessage] = useState("");
  const [sending, setSending] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });

  useEffect(() => { scrollToBottom(); }, [messages]);

  // Charger les sessions existantes
  useEffect(() => {
    if (!userId) return;
    fetch(`/api/chat?userId=${userId}`)
      .then((r) => r.json())
      .then((json) => {
        if (json.data?.length > 0) {
          setSessions(json.data);
          setActiveSessionId(json.data[0].id);
        }
      })
      .catch(console.error);
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
        if (json.sessionId && !activeSessionId) setActiveSessionId(json.sessionId);
        setMessages((prev) => [
          ...prev,
          {
            id: (Date.now() + 1).toString(),
            sessionId: json.sessionId || activeSessionId || "",
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

  const handleNewSession = () => { setActiveSessionId(null); setMessages([]); };

  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // Rendu
  // â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  const sidebarStyle: React.CSSProperties = {
    display: "flex",
    flexDirection: "column",
    width: "232px",
    flexShrink: 0,
    background: "var(--warm-100)",
    border: "1px solid var(--border)",
    borderRadius: "var(--radius-lg)",
    padding: "var(--space-4)",
    gap: "var(--space-3)",
  };

  const chatAreaStyle: React.CSSProperties = {
    flex: 1,
    display: "flex",
    flexDirection: "column",
    background: "var(--warm-50)",
    border: "1px solid var(--border)",
    borderRadius: "var(--radius-lg)",
    overflow: "hidden",
    boxShadow: "var(--shadow-sm)",
  };

  return (
    <div style={{ height: "calc(100vh - 180px)", display: "flex", gap: "var(--space-4)" }}>

      {/* â”€â”€ Sidebar sessions â”€â”€ */}
      <div className="hidden md:flex" style={sidebarStyle}>
        <button
          onClick={handleNewSession}
          className="btn-primary"
          style={{ justifyContent: "center", width: "100%", fontSize: "var(--text-body)" }}
        >
          <Plus size={14} />
          Nouvelle discussion
        </button>

        <p className="text-caption" style={{ color: "var(--ink-subtle)", paddingLeft: "4px" }}>
          Historique
        </p>

        <div className="flex-1 overflow-y-auto custom-scrollbar" style={{ display: "flex", flexDirection: "column", gap: "2px" }}>
          {sessions.length === 0 ? (
            <p style={{ fontSize: "var(--text-caption)", color: "var(--ink-subtle)", padding: "var(--space-2)", textAlign: "center" }}>
              Aucune discussion passÃ©e
            </p>
          ) : (
            sessions.map((sess) => (
              <button
                key={sess.id}
                onClick={() => setActiveSessionId(sess.id)}
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: "var(--space-2)",
                  padding: "var(--space-2) var(--space-3)",
                  borderRadius: "var(--radius)",
                  textAlign: "left",
                  background: activeSessionId === sess.id ? "var(--accent-light)" : "transparent",
                  border: activeSessionId === sess.id ? "1px solid var(--accent)" : "1px solid transparent",
                  color: activeSessionId === sess.id ? "var(--accent)" : "var(--ink-muted)",
                  fontSize: "var(--text-body)",
                  fontWeight: activeSessionId === sess.id ? 600 : 400,
                  cursor: "pointer",
                  width: "100%",
                  transition: "background var(--transition-base)",
                  overflow: "hidden",
                }}
              >
                <MessageSquare size={12} style={{ flexShrink: 0, opacity: 0.7 }} />
                <span style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                  {sess.title}
                </span>
              </button>
            ))
          )}
        </div>
      </div>

      {/* â”€â”€ Zone de chat â”€â”€ */}
      <div style={chatAreaStyle}>

        {/* Header */}
        <div
          style={{
            padding: "var(--space-4) var(--space-6)",
            borderBottom: "1px solid var(--border)",
            display: "flex",
            alignItems: "center",
            justifyContent: "space-between",
            background: "var(--warm-100)",
          }}
        >
          <div style={{ display: "flex", alignItems: "center", gap: "var(--space-3)" }}>
            <div
              style={{
                width: 36,
                height: 36,
                borderRadius: "var(--radius)",
                background: "var(--ink-800)",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                flexShrink: 0,
              }}
            >
              <Sparkles size={18} color="white" />
            </div>
            <div>
              <h3
                style={{
                  fontFamily: "var(--font-body)",
                  fontSize: "var(--text-h2)",
                  fontWeight: 600,
                  color: "var(--ink-text)",
                  margin: 0,
                  display: "flex",
                  alignItems: "center",
                  gap: "var(--space-2)",
                }}
              >
                FlyAgent
                <span
                  style={{
                    fontSize: "var(--text-caption)",
                    fontWeight: 600,
                    padding: "2px 6px",
                    borderRadius: "var(--radius-sm)",
                    border: "1px solid var(--accent)",
                    color: "var(--accent)",
                    background: "var(--accent-light)",
                    textTransform: "uppercase",
                    letterSpacing: "0.04em",
                  }}
                >
                  Copilote
                </span>
              </h3>
              <p style={{ fontSize: "var(--text-caption)", color: "var(--ink-subtle)", margin: 0 }}>
                Conseil acadÃ©mique â€” prÃ©paration de votre dossier de candidature
              </p>
            </div>
          </div>

          <button className="md:hidden btn-secondary" onClick={handleNewSession} style={{ padding: "6px 10px" }}>
            <Plus size={14} />
          </button>
        </div>

        {/* Messages */}
        <div
          className="custom-scrollbar"
          style={{ flex: 1, padding: "var(--space-6)", overflowY: "auto", display: "flex", flexDirection: "column", gap: "var(--space-4)" }}
        >
          {messages.length === 0 ? (
            <div
              style={{
                flex: 1,
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                justifyContent: "center",
                textAlign: "center",
                maxWidth: "480px",
                margin: "0 auto",
                gap: "var(--space-6)",
              }}
            >
              <div
                style={{
                  width: 56,
                  height: 56,
                  borderRadius: "50%",
                  border: "1px solid var(--border)",
                  background: "var(--warm-100)",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                }}
              >
                <Sparkles size={24} style={{ color: "var(--ink-700)" }} />
              </div>

              <div>
                <h3 style={{ fontFamily: "var(--font-display)", fontSize: "var(--text-h1)", fontWeight: 400, color: "var(--ink-text)", margin: "0 0 8px" }}>
                  Comment puis-je vous aider ?
                </h3>
                <p style={{ fontSize: "var(--text-body)", color: "var(--ink-muted)", margin: 0 }}>
                  Posez une question sur votre dossier, les critÃ¨res d'une bourse ou votre plan de candidature.
                </p>
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "var(--space-3)", width: "100%" }}>
                {QUICK_PROMPTS.map((prompt, i) => (
                  <button
                    key={i}
                    onClick={() => handleSend(prompt)}
                    className="btn-secondary"
                    style={{ textAlign: "left", fontSize: "var(--text-caption)", padding: "var(--space-3)", lineHeight: 1.4, height: "auto" }}
                  >
                    {prompt}
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
                    display: "flex",
                    gap: "var(--space-3)",
                    maxWidth: "720px",
                    flexDirection: isUser ? "row-reverse" : "row",
                    marginLeft: isUser ? "auto" : 0,
                  }}
                >
                  <div
                    style={{
                      width: 30,
                      height: 30,
                      borderRadius: "var(--radius)",
                      background: isUser ? "var(--ink-700)" : "var(--warm-200)",
                      border: "1px solid var(--border)",
                      display: "flex",
                      alignItems: "center",
                      justifyContent: "center",
                      flexShrink: 0,
                    }}
                  >
                    {isUser
                      ? <UserIcon size={14} color="white" />
                      : <Sparkles size={14} style={{ color: "var(--ink-700)" }} />
                    }
                  </div>
                  <div
                    style={{
                      padding: "var(--space-3) var(--space-4)",
                      borderRadius: "var(--radius)",
                      fontSize: "var(--text-body)",
                      lineHeight: 1.65,
                      whiteSpace: "pre-line",
                      background: isUser ? "var(--ink-800)" : "var(--warm-100)",
                      color: isUser ? "#ffffff" : "var(--ink-text)",
                      border: `1px solid ${isUser ? "var(--ink-700)" : "var(--border)"}`,
                      boxShadow: "var(--shadow-sm)",
                    }}
                  >
                    {msg.content}
                  </div>
                </div>
              );
            })
          )}

          {/* Indicateur "rÃ©flÃ©chit" Â§8.1 â€” sans emoji, sans animation criarde */}
          {sending && (
            <div style={{ display: "flex", gap: "var(--space-3)", alignItems: "center" }}>
              <div
                style={{
                  width: 30, height: 30,
                  borderRadius: "var(--radius)",
                  background: "var(--warm-200)",
                  border: "1px solid var(--border)",
                  display: "flex", alignItems: "center", justifyContent: "center",
                }}
              >
                <Sparkles size={14} style={{ color: "var(--ink-700)" }} />
              </div>
              <div
                style={{
                  padding: "var(--space-3) var(--space-4)",
                  borderRadius: "var(--radius)",
                  border: "1px solid var(--border)",
                  background: "var(--warm-100)",
                  display: "flex",
                  alignItems: "center",
                  gap: "var(--space-2)",
                }}
              >
                {/* 3 points en animation CSS â€” discrets */}
                {[0, 1, 2].map((i) => (
                  <span
                    key={i}
                    style={{
                      width: 5, height: 5,
                      borderRadius: "50%",
                      background: "var(--ink-subtle)",
                      display: "inline-block",
                      animation: `pulse 1.2s ease-in-out ${i * 0.2}s infinite`,
                    }}
                  />
                ))}
                <span style={{ fontSize: "var(--text-caption)", color: "var(--ink-subtle)", marginLeft: "var(--space-1)" }}>
                  FlyAgent prÃ©pare une rÃ©ponse
                </span>
              </div>
            </div>
          )}

          <div ref={messagesEndRef} />
        </div>

        {/* Barre de saisie */}
        <div
          style={{
            padding: "var(--space-4)",
            borderTop: "1px solid var(--border)",
            background: "var(--warm-100)",
          }}
        >
          <form
            onSubmit={(e) => { e.preventDefault(); handleSend(); }}
            style={{
              display: "flex",
              alignItems: "center",
              gap: "var(--space-3)",
              background: "var(--warm-50)",
              border: "1px solid var(--border)",
              borderRadius: "var(--radius)",
              padding: "var(--space-2)",
              transition: "border-color var(--transition-base)",
            }}
            onFocusCapture={(e) => (e.currentTarget.style.borderColor = "var(--ink-600)")}
            onBlurCapture={(e) => (e.currentTarget.style.borderColor = "var(--border)")}
          >
            <input
              type="text"
              placeholder="Posez votre question sur votre dossier de candidature..."
              value={inputMessage}
              onChange={(e) => setInputMessage(e.target.value)}
              style={{
                flex: 1,
                background: "transparent",
                border: "none",
                outline: "none",
                fontSize: "var(--text-body)",
                color: "var(--ink-text)",
                padding: "var(--space-2) var(--space-3)",
              }}
            />
            <button
              type="submit"
              disabled={!inputMessage.trim() || sending}
              className="btn-primary"
              style={{
                padding: "var(--space-2) var(--space-4)",
                opacity: !inputMessage.trim() || sending ? 0.4 : 1,
              }}
            >
              <Send size={14} />
            </button>
          </form>
          <p style={{ fontSize: "10px", color: "var(--ink-subtle)", marginTop: "var(--space-2)", textAlign: "center" }}>
            FlyAgent est un assistant de prÃ©paration. Il ne garantit aucun rÃ©sultat de sÃ©lection.
          </p>
        </div>
      </div>

      <style>{`
        @keyframes pulse {
          0%, 80%, 100% { opacity: 0.2; transform: scale(0.8); }
          40% { opacity: 1; transform: scale(1); }
        }
      `}</style>
    </div>
  );
}