"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
import { Settings, Sun, Moon, Globe, Shield, Bell, FileText, CheckCircle2 } from "lucide-react";

interface Props {
  theme: "light" | "dark";
  onToggleTheme: () => void;
}

export default function SettingsTab({ theme, onToggleTheme }: Props) {
  const [language, setLanguage] = useState("fr");
  const [notifications, setNotifications] = useState(true);
  const [saved, setSaved] = useState(false);

  const handleSave = () => {
    setSaved(true);
    setTimeout(() => setSaved(false), 2000);
  };

  return (
    <div className="max-w-3xl mx-auto space-y-8 text-slate-800 dark:text-slate-200">
      {/* Banner */}
      <div className="bg-white dark:bg-slate-900/60 backdrop-blur-xl border border-slate-200 dark:border-white/5 p-6 rounded-3xl flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-extrabold text-slate-900 dark:text-white flex items-center gap-2">
            <Settings className="w-6 h-6 text-indigo-500" /> Paramètres & Préférences
          </h2>
          <p className="text-sm text-slate-500 dark:text-slate-400 mt-1">
            Personnalise ton expérience d'application, thème et notifications.
          </p>
        </div>
      </div>

      {/* Theme & Appearance */}
      <div className="bg-white dark:bg-slate-900/60 border border-slate-200 dark:border-white/5 p-6 rounded-3xl space-y-4">
        <h3 className="font-extrabold text-slate-900 dark:text-white text-base border-b border-slate-100 dark:border-white/5 pb-3 flex items-center gap-2">
          {theme === "light" ? <Sun className="w-5 h-5 text-amber-500" /> : <Moon className="w-5 h-5 text-indigo-400" />} Thème & Apparence
        </h3>

        <div className="flex items-center justify-between p-4 rounded-2xl bg-slate-50 dark:bg-white/5 border border-slate-200 dark:border-white/5">
          <div>
            <div className="font-bold text-sm text-slate-900 dark:text-white">Mode d'affichage</div>
            <div className="text-xs text-slate-500 dark:text-slate-400">
              {theme === "light" ? "Mode Clair actif (par défaut)" : "Mode Sombre actif"}
            </div>
          </div>

          <button
            onClick={onToggleTheme}
            className="flex items-center gap-2 px-4 py-2 rounded-xl bg-indigo-600 text-white font-bold text-xs shadow-md transition-all"
          >
            {theme === "light" ? (
              <>
                <Moon className="w-4 h-4" />
                <span>Passer en Mode Sombre</span>
              </>
            ) : (
              <>
                <Sun className="w-4 h-4" />
                <span>Passer en Mode Clair</span>
              </>
            )}
          </button>
        </div>
      </div>

      {/* Language */}
      <div className="bg-white dark:bg-slate-900/60 border border-slate-200 dark:border-white/5 p-6 rounded-3xl space-y-4">
        <h3 className="font-extrabold text-slate-900 dark:text-white text-base border-b border-slate-100 dark:border-white/5 pb-3 flex items-center gap-2">
          <Globe className="w-5 h-5 text-indigo-500" /> Langue de l'interface
        </h3>

        <div className="grid grid-cols-2 gap-4">
          <button
            onClick={() => setLanguage("fr")}
            className={`p-4 rounded-2xl border text-left font-bold text-xs transition-all ${
              language === "fr"
                ? "bg-indigo-600 text-white border-indigo-500 shadow-md"
                : "bg-slate-50 dark:bg-white/5 border-slate-200 dark:border-white/5 text-slate-700 dark:text-slate-300"
            }`}
          >
            🇫🇷 Français (Default)
          </button>

          <button
            onClick={() => setLanguage("en")}
            className={`p-4 rounded-2xl border text-left font-bold text-xs transition-all ${
              language === "en"
                ? "bg-indigo-600 text-white border-indigo-500 shadow-md"
                : "bg-slate-50 dark:bg-white/5 border-slate-200 dark:border-white/5 text-slate-700 dark:text-slate-300"
            }`}
          >
            🇬🇧 English
          </button>
        </div>
      </div>

      {/* Terms & Legal */}
      <div className="bg-white dark:bg-slate-900/60 border border-slate-200 dark:border-white/5 p-6 rounded-3xl space-y-4">
        <h3 className="font-extrabold text-slate-900 dark:text-white text-base border-b border-slate-100 dark:border-white/5 pb-3 flex items-center gap-2">
          <FileText className="w-5 h-5 text-emerald-500" /> Informations Légales
        </h3>

        <Link
          href="/terms"
          className="flex items-center justify-between p-4 rounded-2xl bg-slate-50 dark:bg-white/5 border border-slate-200 dark:border-white/5 hover:border-indigo-500 transition-all"
        >
          <span className="font-bold text-xs text-slate-900 dark:text-white">Conditions Générales d'Utilisation & Confidentialité</span>
          <span className="text-xs text-indigo-600 dark:text-indigo-400 font-bold">&rarr; Voir la page</span>
        </Link>
      </div>
    </div>
  );
}
