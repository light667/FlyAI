"use client";

import { useState, useEffect } from "react";
import { ForumPost, DirectMessage, UserProfile } from "@/types";
import { supabase } from "@/lib/supabase";
import { MessageSquare, Heart, Send, Plus, Users, User as UserIcon, Tag, Sparkles, MessageCircle } from "lucide-react";

interface Props {
  userId?: string;
  userProfile?: UserProfile | null;
}

export default function CommunityTab({ userId, userProfile }: Props) {
  const [posts, setPosts] = useState<ForumPost[]>([]);
  const [loading, setLoading] = useState(true);
  const [newPostContent, setNewPostContent] = useState("");
  const [newPostTag, setNewPostTag] = useState("France");
  const [showNewPostModal, setShowNewPostModal] = useState(false);

  // Direct Student Chat state
  const [activeChatPeer, setActiveChatPeer] = useState<{ id: string; name: string } | null>(null);
  const [directMessages, setDirectMessages] = useState<DirectMessage[]>([]);
  const [dmContent, setDmContent] = useState("");

  // Load Forum Posts
  const fetchPosts = async () => {
    setLoading(true);
    try {
      const res = await fetch(`/api/community?type=posts&userId=${userId || ""}`);
      const json = await res.json();
      if (json.data) {
        setPosts(json.data);
      }
    } catch (e) {
      console.error("Failed to load community posts", e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchPosts();

    // Supabase Realtime Subscription for new posts
    const postsChannel = supabase
      .channel("public:posts")
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "posts" },
        (payload) => {
          const newPost = payload.new;
          setPosts((prev) => [
            {
              id: newPost.id,
              userId: newPost.user_id,
              authorName: newPost.author_name,
              authorAvatar: newPost.author_avatar || "",
              content: newPost.content,
              tags: newPost.tags || [],
              likesCount: newPost.likes_count || 0,
              commentsCount: newPost.comments_count || 0,
              userHasLiked: false,
              createdAt: newPost.created_at,
            },
            ...prev,
          ]);
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(postsChannel);
    };
  }, [userId]);

  // Load & Subscribe Direct Messages
  useEffect(() => {
    if (!activeChatPeer || !userId) return;

    fetch(`/api/community?type=direct_messages&userId=${userId}&otherId=${activeChatPeer.id}`)
      .then((res) => res.json())
      .then((json) => {
        if (json.data) setDirectMessages(json.data);
      });

    const dmChannel = supabase
      .channel(`dm:${userId}:${activeChatPeer.id}`)
      .on(
        "postgres_changes",
        { event: "INSERT", schema: "public", table: "direct_messages" },
        (payload) => {
          const msg = payload.new;
          if (
            (msg.sender_id === userId && msg.receiver_id === activeChatPeer.id) ||
            (msg.sender_id === activeChatPeer.id && msg.receiver_id === userId)
          ) {
            setDirectMessages((prev) => [...prev, msg]);
          }
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(dmChannel);
    };
  }, [activeChatPeer, userId]);

  const handleCreatePost = async () => {
    if (!newPostContent.trim() || !userId) return;
    try {
      await fetch("/api/community", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action: "create_post",
          userId,
          authorName: userProfile?.fullName || "Étudiant FlyAI",
          authorAvatar: userProfile?.photoUrl || "",
          content: newPostContent,
          tags: [newPostTag],
        }),
      });

      setNewPostContent("");
      setShowNewPostModal(false);
      fetchPosts();
    } catch (e) {
      console.error("Error creating post", e);
    }
  };

  const handleLikePost = async (postId: string) => {
    if (!userId) return;

    // Optimistic UI toggle
    setPosts((prev) =>
      prev.map((p) => {
        if (p.id === postId) {
          const newLiked = !p.userHasLiked;
          return {
            ...p,
            userHasLiked: newLiked,
            likesCount: newLiked ? p.likesCount + 1 : Math.max(0, p.likesCount - 1),
          };
        }
        return p;
      })
    );

    try {
      await fetch("/api/community", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action: "like_post",
          userId,
          postId,
        }),
      });
    } catch (e) {
      console.error("Error liking post", e);
    }
  };

  const handleSendDM = async () => {
    if (!dmContent.trim() || !activeChatPeer || !userId) return;
    const msgText = dmContent;
    setDmContent("");

    try {
      await fetch("/api/community", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          action: "send_dm",
          senderId: userId,
          receiverId: activeChatPeer.id,
          content: msgText,
        }),
      });
    } catch (e) {
      console.error("Error sending DM", e);
    }
  };

  return (
    <div className="space-y-6">
      {/* Community Header Banner */}
      <div className="bg-slate-900/60 backdrop-blur-xl border border-white/5 p-6 rounded-3xl flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-2xl font-extrabold text-white flex items-center gap-2">
            <Users className="w-6 h-6 text-indigo-400" /> Communauté & Forum Étudiant
          </h2>
          <p className="text-sm text-slate-400 mt-1">
            Échange avec des candidats et boursiers du monde entier en temps réel.
          </p>
        </div>

        <button
          onClick={() => setShowNewPostModal(true)}
          className="flex items-center gap-2 px-5 py-3 bg-gradient-to-r from-indigo-600 to-violet-600 hover:from-indigo-500 hover:to-violet-500 text-white font-bold text-sm rounded-2xl shadow-lg shadow-indigo-500/25 transition-all"
        >
          <Plus className="w-4 h-4" />
          <span>Nouveau Message</span>
        </button>
      </div>

      {/* Main Feed Container */}
      {loading ? (
        <div className="space-y-4">
          {[1, 2, 3].map((i) => (
            <div key={i} className="h-40 bg-white/5 rounded-3xl animate-pulse" />
          ))}
        </div>
      ) : posts.length === 0 ? (
        <div className="p-12 text-center bg-slate-900/40 border border-white/5 rounded-3xl space-y-3">
          <MessageSquare className="w-12 h-12 text-slate-500 mx-auto" />
          <h3 className="text-lg font-bold text-white">Sois le premier à publier un message !</h3>
          <p className="text-sm text-slate-400">Pose une question ou partage ton expérience de candidature.</p>
        </div>
      ) : (
        <div className="space-y-4">
          {posts.map((post) => (
            <div
              key={post.id}
              className="bg-slate-900/60 backdrop-blur-xl border border-white/5 p-6 rounded-3xl space-y-4 shadow-lg hover:border-white/10 transition-all"
            >
              {/* Author & Header */}
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-full bg-gradient-to-tr from-indigo-500 to-violet-600 flex items-center justify-center text-white font-bold text-sm">
                    {post.authorName[0].toUpperCase()}
                  </div>
                  <div>
                    <h4 className="font-bold text-sm text-white">{post.authorName}</h4>
                    <div className="text-[11px] text-slate-500">
                      {new Date(post.createdAt).toLocaleDateString("fr-FR", {
                        day: "numeric",
                        month: "short",
                        hour: "2-digit",
                        minute: "2-digit",
                      })}
                    </div>
                  </div>
                </div>

                {/* Direct Message button */}
                {post.userId !== userId && (
                  <button
                    onClick={() => setActiveChatPeer({ id: post.userId, name: post.authorName })}
                    className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-white/5 hover:bg-white/10 text-xs font-semibold text-indigo-300 border border-white/5 transition-all"
                  >
                    <MessageCircle className="w-3.5 h-3.5" />
                    <span>Discuter</span>
                  </button>
                )}
              </div>

              {/* Content */}
              <p className="text-sm text-slate-200 leading-relaxed whitespace-pre-line">
                {post.content}
              </p>

              {/* Footer Tags & Like Button */}
              <div className="flex items-center justify-between pt-3 border-t border-white/5">
                <div className="flex flex-wrap gap-1.5">
                  {post.tags.map((tag, i) => (
                    <span key={i} className="px-2.5 py-1 text-[11px] font-semibold rounded-lg bg-indigo-500/10 text-indigo-300 border border-indigo-500/20">
                      #{tag}
                    </span>
                  ))}
                </div>

                <button
                  onClick={() => handleLikePost(post.id)}
                  className={`flex items-center gap-1.5 px-3.5 py-1.5 rounded-xl text-xs font-bold transition-all ${
                    post.userHasLiked
                      ? "bg-rose-500/20 text-rose-400 border border-rose-500/30"
                      : "bg-white/5 text-slate-400 hover:text-white border border-white/5"
                  }`}
                >
                  <Heart className={`w-4 h-4 ${post.userHasLiked ? "fill-rose-400" : ""}`} />
                  <span>{post.likesCount}</span>
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* New Post Modal */}
      {showNewPostModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-md">
          <div className="bg-slate-900 border border-white/10 p-6 md:p-8 rounded-3xl max-w-lg w-full space-y-4">
            <h3 className="text-xl font-extrabold text-white">Publier dans la communauté</h3>

            <textarea
              rows={4}
              placeholder="Ex: Quelqu'un a-t-il reçu le retour pour la bourse Eiffel 2026 ?"
              value={newPostContent}
              onChange={(e) => setNewPostContent(e.target.value)}
              className="w-full p-4 bg-white/5 border border-white/10 rounded-2xl text-sm text-white placeholder:text-slate-500 outline-none focus:border-indigo-500"
            />

            <div>
              <label className="text-xs font-bold uppercase text-slate-400 mb-1.5 block">Thématique / Tag</label>
              <select
                value={newPostTag}
                onChange={(e) => setNewPostTag(e.target.value)}
                className="w-full p-3 bg-white/5 border border-white/10 text-sm text-slate-200 rounded-xl outline-none"
              >
                <option value="France" className="bg-slate-900">France (Eiffel, CROUS)</option>
                <option value="Allemagne" className="bg-slate-900">Allemagne (DAAD)</option>
                <option value="Erasmus" className="bg-slate-900">Erasmus Mundus</option>
                <option value="Canada" className="bg-slate-900">Canada / Amériques</option>
                <option value="Conseils" className="bg-slate-900">Conseils & Lettres</option>
              </select>
            </div>

            <div className="flex justify-end gap-3 pt-4">
              <button
                onClick={() => setShowNewPostModal(false)}
                className="px-5 py-2.5 rounded-xl border border-white/10 text-slate-300 hover:bg-white/5 text-sm font-semibold"
              >
                Annuler
              </button>
              <button
                onClick={handleCreatePost}
                disabled={!newPostContent.trim()}
                className="px-6 py-2.5 rounded-xl bg-gradient-to-r from-indigo-600 to-violet-600 text-white font-bold text-sm shadow-lg shadow-indigo-500/25 disabled:opacity-50"
              >
                Publier
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Direct Student Chat Modal Drawer */}
      {activeChatPeer && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/80 backdrop-blur-md">
          <div className="bg-slate-900 border border-white/10 rounded-3xl max-w-md w-full h-[500px] flex flex-col overflow-hidden shadow-2xl">
            <div className="p-4 border-b border-white/10 bg-slate-950 flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="w-8 h-8 rounded-full bg-indigo-600 text-white font-bold text-xs flex items-center justify-center">
                  {activeChatPeer.name[0]}
                </div>
                <span className="font-bold text-sm text-white">{activeChatPeer.name}</span>
              </div>
              <button onClick={() => setActiveChatPeer(null)} className="text-slate-400 hover:text-white">✕</button>
            </div>

            {/* DM Messages */}
            <div className="flex-1 p-4 overflow-y-auto space-y-3">
              {directMessages.map((dm) => {
                const isMe = dm.sender_id === userId;
                return (
                  <div key={dm.id} className={`flex ${isMe ? "justify-end" : "justify-start"}`}>
                    <div className={`p-3 rounded-2xl text-xs max-w-[80%] ${isMe ? "bg-indigo-600 text-white" : "bg-white/10 text-slate-200"}`}>
                      {dm.content}
                    </div>
                  </div>
                );
              })}
            </div>

            {/* Input */}
            <div className="p-3 border-t border-white/10 bg-slate-950 flex gap-2">
              <input
                type="text"
                placeholder="Écris un message privé..."
                value={dmContent}
                onChange={(e) => setDmContent(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleSendDM()}
                className="flex-1 bg-white/5 border border-white/10 rounded-xl px-3 text-xs text-white outline-none"
              />
              <button onClick={handleSendDM} className="px-4 py-2 bg-indigo-600 text-white rounded-xl font-bold text-xs">
                <Send className="w-3.5 h-3.5" />
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
