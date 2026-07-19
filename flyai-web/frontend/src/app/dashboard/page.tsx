"use client";

import { useEffect, useState } from "react";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { onAuthStateChanged, User, signOut } from "firebase/auth";
import { auth } from "@/lib/firebase";
import {
  Compass,
  MessageSquare,
  Sparkles,
  Briefcase,
  User as UserIcon,
  Heart,
  Bookmark,
  Calendar,
  LogOut,
  ChevronRight,
  TrendingUp,
  Award,
  Bell,
  Search,
} from "lucide-react";

// Mock Scholarships Matching the Onboarding/Ambitions
const MOCK_SCHOLARSHIPS = [
  {
    id: 1,
    title: "Erasmus Mundus Joint Master Degree",
    university: "Université de Bologne & Sorbonne",
    country: "Italie / France",
    score: 96,
    deadline: "Dans 14 jours",
    image: "/logo.png",
    amount: "24 000 € / an",
  },
  {
    id: 2,
    title: "Bourse d'Excellence Eiffel",
    university: "Écoles d'Ingénieurs & Universités Françaises",
    country: "France",
    score: 89,
    deadline: "Dans 30 jours",
    image: "/logo.png",
    amount: "17 000 € / an + Vols",
  },
  {
    id: 3,
    title: "Bourse d'Études DAAD",
    university: "TU Berlin & Heidelberg",
    country: "Allemagne",
    score: 85,
    deadline: "Dans 45 jours",
    image: "/logo.png",
    amount: "12 000 € / an + Assurance",
  },
];

export default function Dashboard() {
  const router = useRouter();
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState("discover");

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      if (user) {
        setCurrentUser(user);
      } else {
        router.replace("/auth/login");
      }
      setLoading(false);
    });

    return () => unsubscribe();
  }, [router]);

  const handleLogout = async () => {
    try {
      await signOut(auth);
      router.replace("/auth/login");
    } catch (error) {
      console.error("Error logging out:", error);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-[#0A0F1C] flex items-center justify-center">
        <div className="relative">
          <div className="absolute inset-0 rounded-full bg-indigo-500/20 blur-xl scale-150 animate-pulse" />
          <Image src="/logo.png" alt="Loading..." width={64} height={64} className="animate-spin rounded-full" />
        </div>
      </div>
    );
  }

  const firstName = currentUser?.displayName?.split(" ")[0] || "Scholar";

  return (
    <div className="min-h-screen bg-[#0A0F1C] text-slate-100 flex flex-col md:flex-row font-sans overflow-hidden">
      {/* Background radial glows */}
      <div className="absolute top-0 left-0 w-96 h-96 bg-indigo-600/10 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute bottom-0 right-0 w-96 h-96 bg-violet-600/10 rounded-full blur-3xl pointer-events-none" />

      {/* ── Desktop Sidebar ────────────────────────────────────────── */}
      <aside className="hidden md:flex flex-col w-64 bg-slate-900/40 backdrop-blur-xl border-r border-white/5 p-6 z-20 shrink-0">
        <div className="flex items-center gap-3 mb-10">
          <Image src="/logo.png" alt="FlyAI" width={36} height={36} className="rounded-xl" />
          <span className="font-extrabold text-xl tracking-tight text-white">
            Fly<span className="text-indigo-400">AI</span>
          </span>
        </div>

        <nav className="flex-1 space-y-2">
          {[
            { id: "discover", label: "Découvrir", icon: Compass },
            { id: "community", label: "Communauté", icon: MessageSquare },
            { id: "assistant", label: "FlyAgent AI", icon: Sparkles, badge: "Coach" },
            { id: "applications", label: "Candidatures", icon: Briefcase },
            { id: "profile", label: "Mon Profil", icon: UserIcon },
          ].map((item) => {
            const Icon = item.icon;
            const active = activeTab === item.id;
            return (
              <button
                key={item.id}
                onClick={() => setActiveTab(item.id)}
                className={`w-full flex items-center gap-3.5 px-4 py-3.5 rounded-2xl text-sm font-semibold transition-all duration-200 ${
                  active
                    ? "bg-gradient-to-r from-indigo-600 to-violet-600 text-white shadow-lg shadow-indigo-500/25"
                    : "text-slate-400 hover:bg-white/5 hover:text-white"
                }`}
              >
                <Icon className={`w-5 h-5 ${active ? "text-white" : "text-slate-400"}`} />
                <span>{item.label}</span>
                {item.badge && (
                  <span className="ml-auto text-[10px] uppercase font-black bg-indigo-500/20 text-indigo-300 border border-indigo-500/30 px-2 py-0.5 rounded-full">
                    {item.badge}
                  </span>
                )}
              </button>
            );
          })}
        </nav>

        {/* User Card / Logout */}
        <div className="border-t border-white/5 pt-6 mt-6 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-full bg-gradient-to-tr from-indigo-500 to-violet-500 flex items-center justify-center text-white font-bold font-sans text-sm">
              {firstName[0].toUpperCase()}
            </div>
            <div>
              <div className="font-semibold text-sm max-w-[120px] truncate">{firstName}</div>
              <div className="text-xs text-slate-500 truncate">En ligne</div>
            </div>
          </div>
          <button
            onClick={handleLogout}
            className="p-2 rounded-xl hover:bg-red-500/10 text-slate-400 hover:text-red-400 transition-all"
            title="Se déconnecter"
          >
            <LogOut className="w-5 h-5" />
          </button>
        </div>
      </aside>

      {/* ── Main Panel ────────────────────────────────────────────── */}
      <main className="flex-1 flex flex-col z-10 overflow-y-auto max-h-screen">
        {/* Header toolbar */}
        <header className="flex items-center justify-between px-6 md:px-8 py-5 border-b border-white/5 bg-slate-950/20 backdrop-blur-xl">
          <div className="flex items-center gap-4 bg-white/5 px-4 py-2 rounded-2xl w-full max-w-md border border-white/5">
            <Search className="w-4 h-4 text-slate-500" />
            <input
              type="text"
              placeholder="Rechercher des bourses, pays, universités..."
              className="bg-transparent border-none outline-none text-sm w-full text-slate-200 placeholder:text-slate-500"
            />
          </div>

          <div className="flex items-center gap-4 ml-4">
            <button className="relative p-2.5 rounded-xl bg-white/5 hover:bg-white/10 transition-all border border-white/5 text-slate-300">
              <Bell className="w-5 h-5" />
              <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-indigo-500 rounded-full" />
            </button>
          </div>
        </header>

        {/* Dynamic contents based on tabs */}
        <div className="flex-1 p-6 md:p-8 space-y-8 max-w-5xl">
          {/* Welcome widget */}
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
            <div>
              <h1 className="text-3xl font-extrabold text-white tracking-tight">
                Bonjour, {firstName} 👋
              </h1>
              <p className="text-slate-400 text-sm mt-1">
                Voici ton statut académique et tes correspondances du jour.
              </p>
            </div>
            <button
              onClick={() => setActiveTab("assistant")}
              className="flex items-center gap-2 px-5 py-3 rounded-2xl bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-semibold transition-all hover:shadow-lg hover:shadow-indigo-500/25 shrink-0"
            >
              <Sparkles className="w-4 h-4" />
              Lancer le Coach IA
            </button>
          </div>

          {/* Stats Bar (like Flutter _MiniStat) */}
          <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
            {[
              { label: "Bourses Validées", value: "12", icon: Heart, color: "text-emerald-400 bg-emerald-500/10 border-emerald-500/20" },
              { label: "Sauvegardées", value: "3", icon: Bookmark, color: "text-indigo-400 bg-indigo-500/10 border-indigo-500/20" },
              { label: "Dossiers Actifs", value: "2", icon: Briefcase, color: "text-cyan-400 bg-cyan-500/10 border-cyan-500/20" },
              { label: "Compatibilité Moyenne", value: "90%", icon: Award, color: "text-pink-400 bg-pink-500/10 border-pink-500/20" },
            ].map((stat, i) => {
              const Icon = stat.icon;
              return (
                <div
                  key={i}
                  className={`p-5 rounded-2xl border transition-all duration-300 hover:scale-[1.02] flex flex-col gap-3 bg-slate-900/30 ${stat.color}`}
                >
                  <Icon className="w-5 h-5" />
                  <div>
                    <div className="text-2xl font-black">{stat.value}</div>
                    <div className="text-xs text-slate-400 mt-0.5">{stat.label}</div>
                  </div>
                </div>
              );
            })}
          </div>

          {/* Core content: Scholarship Feed */}
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="text-xl font-bold text-white tracking-tight">Vos bourses correspondantes</h2>
              <span className="text-xs text-indigo-400 hover:underline cursor-pointer font-semibold">Voir tout</span>
            </div>

            <div className="space-y-4">
              {MOCK_SCHOLARSHIPS.map((item) => (
                <div
                  key={item.id}
                  className="p-5 rounded-2xl bg-slate-900/25 border border-white/5 transition-all duration-300 hover:bg-slate-900/50 hover:border-white/10 flex flex-col md:flex-row items-start md:items-center justify-between gap-4 group"
                >
                  <div className="flex items-center gap-4">
                    {/* Thumbnail representation */}
                    <div className="w-14 h-14 rounded-2xl bg-indigo-500/10 flex items-center justify-center text-indigo-400 font-extrabold text-lg border border-indigo-500/20 shrink-0">
                      🎓
                    </div>
                    <div>
                      <h3 className="font-bold text-slate-100 group-hover:text-white transition-colors">
                        {item.title}
                      </h3>
                      <p className="text-sm text-slate-400 mt-0.5">
                        {item.university} &middot; {item.country}
                      </p>
                      <div className="flex flex-wrap items-center gap-3 mt-2">
                        <span className="inline-flex items-center gap-1 text-[11px] font-semibold text-emerald-400 bg-emerald-400/10 px-2 py-0.5 rounded-full">
                          {item.amount}
                        </span>
                        <span className="inline-flex items-center gap-1.5 text-[11px] font-medium text-slate-500">
                          <Calendar className="w-3 h-3" />
                          {item.deadline}
                        </span>
                      </div>
                    </div>
                  </div>

                  {/* Compatibility score badge (Matches Flutter UI) */}
                  <div
                    className="w-12 h-12 rounded-full flex flex-col items-center justify-center text-white shrink-0 shadow-lg"
                    style={{
                      background:
                        item.score >= 90
                          ? "linear-gradient(135deg, #10B981, #059669)"
                          : "linear-gradient(135deg, #6366F1, #4F46E5)",
                    }}
                  >
                    <span className="text-[13px] font-black">{item.score}</span>
                    <span className="text-[8px] uppercase tracking-wider text-white/70 font-semibold">%</span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </main>

      {/* ── Mobile Bottom Navigation Bar (matches Flutter _FlyNavBar) ── */}
      <div className="md:hidden fixed bottom-0 left-0 right-0 bg-[#0A0F1C]/90 backdrop-blur-2xl border-t border-white/5 py-4 px-6 z-20 flex justify-between items-center">
        {[
          { id: "discover", label: "Explorer", icon: Compass },
          { id: "community", label: "Forums", icon: MessageSquare },
          { id: "assistant", label: "Assistant", icon: Sparkles },
          { id: "applications", label: "Dossiers", icon: Briefcase },
          { id: "profile", label: "Profil", icon: UserIcon },
        ].map((tab) => {
          const Icon = tab.icon;
          const active = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className="flex flex-col items-center gap-1 text-xs font-semibold select-none"
            >
              <div
                className={`p-2 rounded-xl transition-all duration-300 ${
                  active ? "bg-indigo-600/20 text-indigo-400" : "text-slate-500"
                }`}
              >
                <Icon className="w-5 h-5" />
              </div>
              <span className={active ? "text-indigo-400 font-bold" : "text-slate-500"}>
                {tab.label}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
