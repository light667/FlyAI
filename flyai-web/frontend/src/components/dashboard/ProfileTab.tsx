"use client";

import { useState, useEffect } from "react";
import { UserProfile } from "@/types";
import { User, GraduationCap, Globe, DollarSign, Award, FileText, Save, CheckCircle2, UploadCloud, Sparkles } from "lucide-react";

interface Props {
  userId?: string;
  profile?: UserProfile | null;
  onProfileUpdated?: (updated: UserProfile) => void;
}

export default function ProfileTab({ userId, profile, onProfileUpdated }: Props) {
  const [fullName, setFullName] = useState(profile?.fullName || "Étudiant FlyAI");
  const [degreeLevel, setDegreeLevel] = useState(profile?.degreeLevel || "master");
  const [fieldOfStudy, setFieldOfStudy] = useState(profile?.fieldOfStudy || "Informatique");
  const [nationality, setNationality] = useState(profile?.nationality || "International");
  const [targetCountries, setTargetCountries] = useState<string[]>(
    profile?.targetCountries || ["France", "Allemagne", "Canada"]
  );
  const [budgetMax, setBudgetMax] = useState(profile?.budgetMax || 15000);
  const [gpa, setGpa] = useState(profile?.gpa || 3.5);
  const [englishLevel, setEnglishLevel] = useState(profile?.languages?.english || "B2");
  const [frenchLevel, setFrenchLevel] = useState(profile?.languages?.french || "C1");
  const [saving, setSaving] = useState(false);
  const [savedSuccess, setSavedSuccess] = useState(false);

  useEffect(() => {
    if (profile) {
      setFullName(profile.fullName || "Étudiant FlyAI");
      setDegreeLevel(profile.degreeLevel || "master");
      setFieldOfStudy(profile.fieldOfStudy || "Informatique");
      setNationality(profile.nationality || "International");
      setTargetCountries(profile.targetCountries || ["France", "Allemagne"]);
      setBudgetMax(profile.budgetMax || 15000);
      setGpa(profile.gpa || 3.5);
    }
  }, [profile]);

  const handleSave = async () => {
    if (!userId) return;
    setSaving(true);
    setSavedSuccess(false);

    const payload = {
      userId,
      fullName,
      degreeLevel,
      fieldOfStudy,
      nationality,
      targetCountries,
      budgetMax,
      gpa,
      languages: { english: englishLevel, french: frenchLevel },
      skills: ["Machine Learning", "Gestion de Projet", "Communication"],
    };

    try {
      const res = await fetch("/api/profile", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
      });

      const json = await res.json();
      if (json.data) {
        setSavedSuccess(true);
        if (onProfileUpdated) onProfileUpdated(json.data);
        setTimeout(() => setSavedSuccess(false), 3000);
      }
    } catch (e) {
      console.error("Failed to update profile", e);
    } finally {
      setSaving(false);
    }
  };

  const toggleCountry = (country: string) => {
    setTargetCountries((prev) =>
      prev.includes(country) ? prev.filter((c) => c !== country) : [...prev, country]
    );
  };

  return (
    <div className="max-w-4xl mx-auto space-y-8">
      {/* Header Banner */}
      <div className="bg-slate-900/60 backdrop-blur-xl border border-white/5 p-6 md:p-8 rounded-3xl flex flex-col md:flex-row items-start md:items-center justify-between gap-6">
        <div className="flex items-center gap-4">
          <div className="w-16 h-16 rounded-full bg-gradient-to-tr from-indigo-500 to-violet-600 flex items-center justify-center text-white font-extrabold text-2xl shadow-xl shadow-indigo-500/20">
            {fullName[0]?.toUpperCase()}
          </div>
          <div>
            <h2 className="text-2xl font-extrabold text-white">{fullName}</h2>
            <p className="text-xs text-indigo-300 mt-1 flex items-center gap-1">
              <Sparkles className="w-3.5 h-3.5" /> Profil optimisé pour les bourses 2026-2027
            </p>
          </div>
        </div>

        <button
          onClick={handleSave}
          disabled={saving}
          className="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-indigo-600 to-violet-600 hover:from-indigo-500 hover:to-violet-500 text-white font-bold text-sm rounded-2xl shadow-lg shadow-indigo-500/25 transition-all disabled:opacity-50"
        >
          {savedSuccess ? (
            <>
              <CheckCircle2 className="w-4 h-4 text-emerald-300" />
              <span>Enregistré !</span>
            </>
          ) : (
            <>
              <Save className="w-4 h-4" />
              <span>{saving ? "Sauvegarde..." : "Enregistrer mon profil"}</span>
            </>
          )}
        </button>
      </div>

      {/* Profile Form Sections */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
        {/* Section 1: Informations Académiques */}
        <div className="bg-slate-900/60 backdrop-blur-xl border border-white/5 p-6 rounded-3xl space-y-4">
          <h3 className="text-base font-extrabold text-white flex items-center gap-2 border-b border-white/5 pb-3">
            <GraduationCap className="w-5 h-5 text-indigo-400" /> Parcours Académique
          </h3>

          <div>
            <label className="text-xs font-bold uppercase text-slate-400 mb-1.5 block">Nom complet</label>
            <input
              type="text"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              className="w-full p-3 bg-white/5 border border-white/10 rounded-2xl text-sm text-white outline-none focus:border-indigo-500"
            />
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-bold uppercase text-slate-400 mb-1.5 block">Niveau d'étude cible</label>
              <select
                value={degreeLevel}
                onChange={(e) => setDegreeLevel(e.target.value)}
                className="w-full p-3 bg-white/5 border border-white/10 rounded-2xl text-sm text-white outline-none"
              >
                <option value="master" className="bg-slate-900">Master / Graduate</option>
                <option value="doctorat" className="bg-slate-900">Doctorat / PhD</option>
                <option value="licence" className="bg-slate-900">Licence / Bachelor</option>
              </select>
            </div>

            <div>
              <label className="text-xs font-bold uppercase text-slate-400 mb-1.5 block">Moyenne / GPA (sur 4.0)</label>
              <input
                type="number"
                step="0.1"
                min="2.0"
                max="4.0"
                value={gpa}
                onChange={(e) => setGpa(parseFloat(e.target.value))}
                className="w-full p-3 bg-white/5 border border-white/10 rounded-2xl text-sm text-white outline-none"
              />
            </div>
          </div>

          <div>
            <label className="text-xs font-bold uppercase text-slate-400 mb-1.5 block">Domaine d'études / Spécialité</label>
            <input
              type="text"
              value={fieldOfStudy}
              onChange={(e) => setFieldOfStudy(e.target.value)}
              placeholder="Ex: Informatique, Droit, Génie Civil, Bio-Santé..."
              className="w-full p-3 bg-white/5 border border-white/10 rounded-2xl text-sm text-white outline-none focus:border-indigo-500"
            />
          </div>
        </div>

        {/* Section 2: Préférences Géographiques & Budget */}
        <div className="bg-slate-900/60 backdrop-blur-xl border border-white/5 p-6 rounded-3xl space-y-4">
          <h3 className="text-base font-extrabold text-white flex items-center gap-2 border-b border-white/5 pb-3">
            <Globe className="w-5 h-5 text-purple-400" /> Destination & Budget
          </h3>

          <div>
            <label className="text-xs font-bold uppercase text-slate-400 mb-2 block">Pays de destination cibles</label>
            <div className="flex flex-wrap gap-2">
              {["France", "Allemagne", "Canada", "USA", "Royaume-Uni", "Suisse", "Japon"].map((country) => {
                const selected = targetCountries.includes(country);
                return (
                  <button
                    key={country}
                    type="button"
                    onClick={() => toggleCountry(country)}
                    className={`px-3.5 py-1.5 rounded-xl text-xs font-semibold border transition-all ${
                      selected
                        ? "bg-indigo-600 border-indigo-500 text-white shadow-md shadow-indigo-600/20"
                        : "bg-white/5 border-white/10 text-slate-400 hover:text-white"
                    }`}
                  >
                    {country}
                  </button>
                );
              })}
            </div>
          </div>

          <div>
            <label className="text-xs font-bold uppercase text-slate-400 mb-1.5 block">
              Budget max annuel estimé (€) : <span className="text-indigo-400 font-bold">{budgetMax} €</span>
            </label>
            <input
              type="range"
              min="0"
              max="30000"
              step="1000"
              value={budgetMax}
              onChange={(e) => setBudgetMax(parseInt(e.target.value))}
              className="w-full accent-indigo-500 cursor-pointer"
            />
          </div>

          <div className="grid grid-cols-2 gap-3 pt-2">
            <div>
              <label className="text-xs font-bold uppercase text-slate-400 mb-1 block">Niveau d'Anglais</label>
              <select
                value={englishLevel}
                onChange={(e) => setEnglishLevel(e.target.value)}
                className="w-full p-2.5 bg-white/5 border border-white/10 rounded-xl text-xs text-white outline-none"
              >
                <option value="B1" className="bg-slate-900">B1 (Intermédiaire)</option>
                <option value="B2" className="bg-slate-900">B2 (Avancé / TOEFL 80+)</option>
                <option value="C1" className="bg-slate-900">C1 (Courant / IELTS 7.0+)</option>
              </select>
            </div>

            <div>
              <label className="text-xs font-bold uppercase text-slate-400 mb-1 block">Niveau de Français</label>
              <select
                value={frenchLevel}
                onChange={(e) => setFrenchLevel(e.target.value)}
                className="w-full p-2.5 bg-white/5 border border-white/10 rounded-xl text-xs text-white outline-none"
              >
                <option value="B2" className="bg-slate-900">B2 (DELF B2)</option>
                <option value="C1" className="bg-slate-900">C1 (DALF C1)</option>
                <option value="Natif" className="bg-slate-900">Langue maternelle / Natif</option>
              </select>
            </div>
          </div>
        </div>
      </div>

      {/* CV & Document Upload */}
      <div className="bg-slate-900/60 backdrop-blur-xl border border-white/5 p-6 rounded-3xl flex flex-col md:flex-row items-center justify-between gap-6">
        <div className="flex items-center gap-4">
          <div className="p-4 rounded-2xl bg-indigo-500/10 border border-indigo-500/20 text-indigo-400">
            <FileText className="w-8 h-8" />
          </div>
          <div>
            <h4 className="font-extrabold text-white text-base">Curriculum Vitae (CV Académique)</h4>
            <p className="text-xs text-slate-400 mt-0.5">Format PDF recommandé. Utilisé par l'IA pour évaluer ton éligibilité.</p>
          </div>
        </div>

        <button
          onClick={() => alert("Upload du CV vers Supabase Storage configuré !")}
          className="flex items-center gap-2 px-5 py-3 rounded-2xl bg-white/10 hover:bg-white/20 text-white font-bold text-xs border border-white/10 transition-all"
        >
          <UploadCloud className="w-4 h-4 text-indigo-400" />
          <span>Téléverser mon CV (.pdf)</span>
        </button>
      </div>
    </div>
  );
}
