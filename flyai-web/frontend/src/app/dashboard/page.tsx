"use client";

import { useEffect, useState } from "react";
import Image from "next/image";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { onAuthStateChanged, User, signOut } from "firebase/auth";
import { auth } from "@/lib/firebase";
import { UserProfile, Scholarship } from "@/types";
import DiscoverTab from "@/components/dashboard/DiscoverTab";
import ApplicationsTab from "@/components/dashboard/ApplicationsTab";
import AssistantTab from "@/components/dashboard/AssistantTab";
import ProfileTab from "@/components/dashboard/ProfileTab";
import DocumentsTab from "@/components/dashboard/DocumentsTab";
import FlyAgentModal from "@/components/dashboard/FlyAgentModal";
import {
  Compass,
  Sparkles,
  Briefcase,
  User as UserIcon,
  FileText,
  Sun,
  Moon,
  LogOut,
  Bell,
  Search,
} from "lucide-react";

export default function Dashboard() {
  const router = useRouter();
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);
  const [activeTab, setActiveTab] = useState("discover");

  // Default Light mode with toggle
  const [theme, setTheme] = useState<"light" | "dark">("light");

  // Active FlyAgent modal target
  const [agentScholarship, setAgentScholarship] = useState<Scholarship | null>(null);

  useEffect(() => {
    // Theme initialization
    const savedTheme = (localStorage.getItem("flyai_theme") as "light" | "dark") || "light";
    setTheme(savedTheme);
    if (savedTheme === "dark") {
      document.documentElement.classList.add("dark");
    } else {
      document.documentElement.classList.remove("dark");
    }

    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      if (user) {
        setCurrentUser(user);

        try {
          const res = await fetch(`/api/profile?userId=${user.uid}`);
          const json = await res.json();
          if (json.data) {
            setProfile(json.data);
          }
        } catch (e) {
          console.error("Error fetching profile:", e);
        }
      } else {
        router.replace("/auth/login");
      }
      setLoading(false);
    });

    return () => unsubscribe();
  }, [router]);

  const toggleTheme = () => {
    const nextTheme = theme === "light" ? "dark" : "light";
    setTheme(nextTheme);
    localStorage.setItem("flyai_theme", nextTheme);
    if (nextTheme === "dark") {
      document.documentElement.classList.add("dark");
    } else {
      document.documentElement.classList.remove("dark");
    }
  };

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
      <div className="min-h-screen bg-slate-50 dark:bg-[#0A0F1C] flex items-center justify-center transition-colors">
        <div className="relative flex flex-col items-center gap-4">
          <div className="relative">
            <Image src="/logo.png" alt="Loading..." width={64} height={64} className="animate-spin rounded-full" />
          </div>
          <span className="text-xs font-bold text-slate-500 uppercase tracking-widest animate-pulse">
            Chargement de FlyAI...
          </span>
        </div>
      </div>
    );
  }

  const firstName = profile?.fullName?.split(" ")[0] || currentUser?.displayName?.split(" ")[0] || "Scholar";

  return (
    <div className={`min-h-screen ${theme === "dark" ? "dark" : ""} bg-slate-50 dark:bg-[#0A0F1C] text-slate-800 dark:text-slate-100 flex flex-col md:flex-row font-sans overflow-hidden transition-colors duration-200`}>
      {/* ── Desktop Sidebar ────────────────────────────────────────── */}
      <aside className="hidden md:flex flex-col w-64 bg-white dark:bg-slate-900/60 backdrop-blur-xl border-r border-slate-200 dark:border-white/5 p-6 z-20 shrink-0">
        <div className="flex items-center gap-3 mb-8">
          <Image src="/logo.png" alt="FlyAI" width={36} height={36} className="rounded-xl shadow-md" />
          <span className="font-extrabold text-xl tracking-tight text-slate-900 dark:text-white">
            Fly<span className="text-indigo-600 dark:text-indigo-400">AI</span>
          </span>
        </div>

        <nav className="flex-1 space-y-1 overflow-y-auto custom-scrollbar pr-1">
          {[
            { id: "discover", label: "Mes meilleures options", icon: Compass },
            { id: "applications", label: "Mes candidatures", icon: Briefcase },
            { id: "flyagent", label: "FlyAgent", icon: Sparkles, badge: "Copilote" },
            { id: "documents", label: "Documents", icon: FileText },
            { id: "profile", label: "Mon Profil", icon: UserIcon },
          ].map((item) => {
            const Icon = item.icon;
            const active = activeTab === item.id;
            return (
              <button
                key={item.id}
                onClick={() => setActiveTab(item.id)}
                className={`w-full flex items-center gap-3.5 px-4 py-3 rounded-2xl text-sm font-extrabold transition-all duration-200 ${
                  active
                    ? "bg-blue-600 text-white shadow-lg shadow-blue-600/25"
                    : "text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-white/5 hover:text-slate-900 dark:hover:text-white"
                }`}
              >
                <Icon className={`w-4.5 h-4.5 ${active ? "text-white" : "text-slate-400"}`} />
                <span className="truncate">{item.label}</span>
                {item.badge && (
                  <span className="ml-auto text-[9px] uppercase font-black bg-blue-500/10 text-blue-600 dark:text-indigo-300 border border-blue-500/20 px-2 py-0.5 rounded-full">
                    {item.badge}
                  </span>
                )}
              </button>
            );
          })}
        </nav>

        {/* Theme Switcher & Logout */}
        <div className="border-t border-slate-200 dark:border-white/5 pt-4 mt-4 space-y-3">
          <button
            onClick={toggleTheme}
            className="w-full flex items-center justify-between p-2.5 rounded-xl bg-slate-100 dark:bg-white/5 text-xs font-semibold text-slate-700 dark:text-slate-300"
          >
            <span className="flex items-center gap-2">
              {theme === "light" ? <Sun className="w-4 h-4 text-amber-500" /> : <Moon className="w-4 h-4 text-indigo-400" />}
              {theme === "light" ? "Mode Clair" : "Mode Sombre"}
            </span>
            <span className="text-[10px] font-bold uppercase text-slate-400">Changer</span>
          </button>

          <div className="flex items-center justify-between pt-1">
            <div className="flex items-center gap-2.5 truncate">
              <div className="w-8 h-8 rounded-full bg-indigo-600 flex items-center justify-center text-white font-bold text-xs shrink-0">
                {firstName[0].toUpperCase()}
              </div>
              <div className="truncate">
                <div className="font-bold text-xs text-slate-900 dark:text-white truncate">{firstName}</div>
                <div className="text-[10px] text-emerald-500 font-semibold">Connecté</div>
              </div>
            </div>

            <button
              onClick={handleLogout}
              className="p-1.5 rounded-xl hover:bg-rose-500/10 text-slate-400 hover:text-rose-500 transition-all"
              title="Se déconnecter"
            >
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        </div>
      </aside>

      {/* ── Main Panel ────────────────────────────────────────────── */}
      <main className="flex-1 flex flex-col z-10 overflow-y-auto max-h-screen pb-20 md:pb-8">
        {/* Top Header */}
        <header className="flex items-center justify-between px-6 md:px-8 py-4 border-b border-slate-200 dark:border-white/5 bg-white/80 dark:bg-slate-950/20 backdrop-blur-xl">
          <div className="flex items-center gap-3 md:hidden">
            <Image src="/logo.png" alt="FlyAI" width={32} height={32} className="rounded-xl" />
            <span className="font-extrabold text-lg tracking-tight text-slate-900 dark:text-white">FlyAI</span>
          </div>

          <div className="hidden md:flex items-center gap-3 bg-slate-100 dark:bg-white/5 px-4 py-2 rounded-2xl w-full max-w-md border border-slate-200 dark:border-white/5">
            <Search className="w-4 h-4 text-slate-400" />
            <input
              type="text"
              placeholder="Rechercher des bourses, pays, opportunités..."
              onClick={() => setActiveTab("discover")}
              className="bg-transparent border-none outline-none text-xs w-full text-slate-800 dark:text-slate-200 placeholder:text-slate-400"
            />
          </div>

          <div className="flex items-center gap-3 ml-auto">
            <button
              onClick={toggleTheme}
              className="md:hidden p-2 rounded-xl bg-slate-100 dark:bg-white/5 text-slate-600 dark:text-slate-300"
            >
              {theme === "light" ? <Moon className="w-4 h-4" /> : <Sun className="w-4 h-4 text-amber-400" />}
            </button>

            <button
              onClick={() => setActiveTab("profile")}
              className="relative p-2.5 rounded-xl bg-slate-100 dark:bg-white/5 border border-slate-200 dark:border-white/5 text-slate-600 dark:text-slate-300"
            >
              <Bell className="w-4 h-4" />
              <span className="absolute top-1.5 right-1.5 w-2 h-2 bg-indigo-500 rounded-full" />
            </button>
          </div>
        </header>

        {/* Dynamic Tab Contents */}
        <div className="flex-1 p-4 md:p-8 max-w-6xl mx-auto w-full">
          {activeTab === "discover" && (
            <DiscoverTab
              userId={currentUser?.uid}
              onOpenFlyAgent={(sch) => setAgentScholarship(sch)}
            />
          )}

          {activeTab === "flyagent" && (
            <AssistantTab userId={currentUser?.uid} userProfile={profile} />
          )}

          {activeTab === "applications" && (
            <ApplicationsTab userId={currentUser?.uid} />
          )}

          {activeTab === "documents" && (
            <DocumentsTab userId={currentUser?.uid} userProfile={profile} />
          )}

          {activeTab === "profile" && (
            <ProfileTab
              userId={currentUser?.uid}
              profile={profile}
              onProfileUpdated={(updated) => setProfile(updated)}
            />
          )}
        </div>
      </main>

      {/* FlyAgent Application Modal */}
      {agentScholarship && (
        <FlyAgentModal
          scholarship={agentScholarship}
          userProfile={profile}
          onClose={() => setAgentScholarship(null)}
        />
      )}

      {/* ── Mobile Navigation Bar ────────────────────────────────────────── */}
      <nav className="md:hidden fixed bottom-0 left-0 right-0 bg-white/95 dark:bg-slate-950/90 backdrop-blur-xl border-t border-slate-200 dark:border-white/10 px-2 py-2 z-40 flex items-center justify-around">
        {[
          { id: "discover", label: "Options", icon: Compass },
          { id: "applications", label: "Candidatures", icon: Briefcase },
          { id: "flyagent", label: "FlyAgent", icon: Sparkles },
          { id: "documents", label: "Documents", icon: FileText },
          { id: "profile", label: "Profil", icon: UserIcon },
        ].map((item) => {
          const Icon = item.icon;
          const active = activeTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => setActiveTab(item.id)}
              className={`flex flex-col items-center gap-1 p-1 transition-all shrink-0 ${
                active ? "text-indigo-600 dark:text-indigo-400 scale-105" : "text-slate-400 hover:text-slate-600"
              }`}
            >
              <Icon className="w-4 h-4" />
              <span className="text-[9px] font-bold">{item.label}</span>
            </button>
          );
        })}
      </nav>
    </div>
  );
}
