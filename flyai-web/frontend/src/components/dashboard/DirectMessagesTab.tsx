"use client";

import { useState, useEffect } from "react";
import { UserProfile, DirectMessage } from "@/types";
import { supabase } from "@/lib/supabase";
import { MessageCircle, Search, Send, User as UserIcon, MapPin, GraduationCap, Sparkles } from "lucide-react";

interface Props {
  userId?: string;
  userProfile?: UserProfile | null;
}

export default function DirectMessagesTab({ userId, userProfile }: Props) {
  const [profiles, setProfiles] = useState<UserProfile[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [selectedUser, setSelectedUser] = useState<UserProfile | null>(null);
  const [messages, setMessages] = useState<DirectMessage[]>([]);
  const [inputMessage, setInputMessage] = useState("");

  // Load all registered profiles
  useEffect(() => {
    supabase
      .from("profiles")
      .select("*")
      .limit(30)
      .then(({ data }) => {
        if (data) {
          const formatted = data.map((p) => ({
            id: p.id,
            fullName: p.full_name || "Étudiant FlyAI",
            email: p.email || "",
            degreeLevel: p.degree_level || "master",
            fieldOfStudy: p.field_of_study || "Informatique",
            nationality: p.nationality || "International",
            targetCountries: p.target_countries || ["France"],
            budgetMax: p.budget_max || 15000,
            gpa: p.gpa || 3.5,
            languages: p.languages || {},
            skills: p.skills || [],
          }));
          setProfiles(formatted.filter((u) => u.id !== userId));
        }
        setLoading(false);
      });
  }, [userId]);

  // Load & subscribe direct messages for selected user
  useEffect(() => {
    if (!selectedUser || !userId) return;

    fetch(`/api/community?type=direct_messages&userId=${userId}&otherId=${selectedUser.id}`)
      .then((res) => res.json())
      .then((json) => {
        if (json.data) setMessages(json.data);
      });

    const dmChannel = supabase
      .channel(`dm:${userId}:${selectedUser.id}`)
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "direct_messages" },
        (payload) => {
          const msg = payload.new;
          if (
            (msg.sender_id === userId && msg.receiver_id === selectedUser.id) ||
            (msg.sender_id === selectedUser.id && msg.receiver_id === userId)
          ) {
            setMessages((prev) => [...prev, msg]);
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(dmChannel);
    };
  }, [selectedUser, userId]);

  const handleSend = async () => {
    if (!inputMessage.trim() || !selectedUser || !userId) return;
    const msgText = inputMessage;
    setInputMessage("");

    try {
      await fetch("/api/community", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action: "send_dm",
          senderId: userId,
          receiverId: selectedUser.id,
          content: msgText,
        }),
      });
    } catch (e) {
      console.error("Error sending DM", e);
    }
  };

  const filteredProfiles = profiles.filter(
    (p) =>
      p.fullName.toLowerCase().includes(search.toLowerCase()) ||
      p.fieldOfStudy.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="h-[calc(100vh-180px)] flex flex-col md:flex-row gap-6">
      {/* Student Directory List */}
      <div className="w-full md:w-80 bg-white dark:bg-slate-900/60 backdrop-blur-xl border border-slate-200 dark:border-white/5 rounded-3xl p-4 flex flex-col shrink-0">
        <h3 className="font-extrabold text-slate-900 dark:text-white text-base mb-3 flex items-center gap-2">
          <MessageCircle className="w-5 h-5 text-indigo-500" /> Réseau Étudiants
        </h3>

        <div className="relative mb-3">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
          <input
            type="text"
            placeholder="Rechercher un membre..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-9 pr-3 py-2 bg-slate-100 dark:bg-white/5 border border-slate-200 dark:border-white/10 rounded-xl text-xs outline-none text-slate-800 dark:text-slate-200"
          />
        </div>

        <div className="flex-1 overflow-y-auto space-y-2 custom-scrollbar">
          {loading ? (
            <div className="text-xs text-slate-400 text-center py-6">Chargement des membres...</div>
          ) : filteredProfiles.length === 0 ? (
            <div className="text-xs text-slate-400 text-center py-6">Aucun membre trouvé</div>
          ) : (
            filteredProfiles.map((p) => {
              const active = selectedUser?.id === p.id;
              return (
                <div
                  key={p.id}
                  onClick={() => setSelectedUser(p)}
                  className={`p-3 rounded-2xl cursor-pointer transition-all border flex items-center gap-3 ${
                    active
                      ? "bg-indigo-600 text-white border-indigo-500 shadow-md"
                      : "bg-slate-50 dark:bg-white/5 hover:bg-slate-100 dark:hover:bg-white/10 border-slate-200 dark:border-white/5 text-slate-800 dark:text-slate-200"
                  }`}
                >
                  <div className="w-9 h-9 rounded-full bg-gradient-to-tr from-indigo-500 to-violet-500 flex items-center justify-center font-bold text-white text-xs shrink-0">
                    {p.fullName[0]?.toUpperCase()}
                  </div>
                  <div className="truncate flex-1">
                    <div className="font-bold text-xs truncate">{p.fullName}</div>
                    <div className="text-[10px] opacity-75 truncate">{p.fieldOfStudy} • {p.degreeLevel}</div>
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>

      {/* Main Chat Drawer Area */}
      <div className="flex-1 bg-white dark:bg-slate-900/60 backdrop-blur-xl border border-slate-200 dark:border-white/5 rounded-3xl flex flex-col overflow-hidden">
        {selectedUser ? (
          <>
            {/* Header */}
            <div className="p-4 border-b border-slate-200 dark:border-white/5 bg-slate-50 dark:bg-slate-950/40 flex items-center gap-3">
              <div className="w-10 h-10 rounded-full bg-indigo-600 text-white font-bold text-sm flex items-center justify-center">
                {selectedUser.fullName[0]}
              </div>
              <div>
                <h4 className="font-bold text-slate-900 dark:text-white text-sm">{selectedUser.fullName}</h4>
                <div className="text-xs text-slate-500 flex items-center gap-2">
                  <span>{selectedUser.fieldOfStudy}</span>
                  <span>•</span>
                  <span>Cible : {selectedUser.targetCountries?.join(", ")}</span>
                </div>
              </div>
            </div>

            {/* Messages */}
            <div className="flex-1 p-4 overflow-y-auto space-y-3 custom-scrollbar">
              {messages.length === 0 ? (
                <div className="h-full flex items-center justify-center text-xs text-slate-400">
                  Démarre la discussion avec {selectedUser.fullName} !
                </div>
              ) : (
                messages.map((dm) => {
                  const isMe = dm.sender_id === userId;
                  return (
                    <div key={dm.id} className={`flex ${isMe ? "justify-end" : "justify-start"}`}>
                      <div className={`p-3 rounded-2xl text-xs max-w-[75%] ${isMe ? "bg-indigo-600 text-white rounded-tr-none shadow-md" : "bg-slate-100 dark:bg-white/10 text-slate-800 dark:text-slate-200 rounded-tl-none"}`}>
                        {dm.content}
                      </div>
                    </div>
                  );
                })
              )}
            </div>

            {/* Input */}
            <div className="p-4 border-t border-slate-200 dark:border-white/5 bg-slate-50 dark:bg-slate-950/40 flex gap-2">
              <input
                type="text"
                placeholder={`Envoyer un message privé à ${selectedUser.fullName}...`}
                value={inputMessage}
                onChange={(e) => setInputMessage(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleSend()}
                className="flex-1 bg-white dark:bg-white/5 border border-slate-200 dark:border-white/10 rounded-2xl px-4 text-xs outline-none text-slate-800 dark:text-slate-200"
              />
              <button
                onClick={handleSend}
                disabled={!inputMessage.trim()}
                className="px-5 py-2.5 rounded-2xl bg-indigo-600 hover:bg-indigo-500 text-white font-bold text-xs disabled:opacity-50 transition-all"
              >
                <Send className="w-4 h-4" />
              </button>
            </div>
          </>
        ) : (
          <div className="h-full flex flex-col items-center justify-center p-8 text-center space-y-3 text-slate-400">
            <MessageCircle className="w-12 h-12 text-slate-400 mx-auto" />
            <h4 className="text-base font-bold text-slate-900 dark:text-white">Sélectionne un membre du réseau</h4>
            <p className="text-xs max-w-sm">
              Clique sur un étudiant dans la liste de gauche pour échanger des conseils, partager des expériences ou collaborer.
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
