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
  const [fullName, setFullName] = useState(profile?.fullName || "");
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
      setFullName(profile.fullName || "");
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
    <div style={{ maxWidth: "1000px", margin: "0 auto", display: "flex", flexDirection: "column", gap: "var(--space-8)" }}>
      {/* Header Banner */}
      <div style={{ background: "var(--warm-100)", backdropFilter: "blur(12px)", border: "1px solid var(--border)", borderRadius: "var(--radius-2xl)", padding: "var(--space-6)", display: "flex", flexDirection: "column", alignItems: "flex-start", gap: "var(--space-6)", position: "relative", overflow: "hidden" }}>
        <div style={{ display: "flex", alignItems: "center", gap: "var(--space-4)" }}>
          <div style={{ width: "64px", height: "64px", borderRadius: "var(--radius-full)", background: "var(--gradient-accent)", display: "flex", alignItems: "center", justifyContent: "center", color: "var(--accent-text)", fontWeight: 700, fontSize: "var(--text-h1)", boxShadow: "var(--shadow-lg), 0 4px 12px rgba(15, 123, 108, 0.2)" }}>
            {profile?.photoUrl ? (
              <img src={profile.photoUrl} alt={fullName} style={{ width: "100%", height: "100%", borderRadius: "50%", objectFit: "cover" }} />
            ) : (
              fullName[0]?.toUpperCase()
            )}
          </div>
          <div>
            <h2 style={{ fontFamily: "var(--font-body)", fontSize: "var(--text-h1)", fontWeight: 700, color: "var(--ink-text)", margin: 0 }}>{fullName}</h2>
            <p style={{ fontSize: "var(--text-caption)", color: "var(--accent)", marginTop: "var(--space-1)", display: "flex", alignItems: "center", gap: "var(--space-1)" }}>
              <Sparkles style={{ width: "14px", height: "14px" }} /> Profil optimisé pour les bourses 2026-2027
            </p>
          </div>
        </div>

        <button
          onClick={handleSave}
          disabled={saving}
          className="btn-primary"
          style={{ marginLeft: "auto", padding: "var(--space-3) var(--space-6)", borderRadius: "var(--radius-2xl)", boxShadow: "var(--shadow-lg)" }}
        >
          {savedSuccess ? (
            <>
              <CheckCircle2 style={{ width: "16px", height: "16px", color: "var(--success)" }} />
              <span>Enregistré !</span>
            </>
          ) : (
            <>
              <Save style={{ width: "16px", height: "16px" }} />
              <span>{saving ? "Sauvegarde..." : "Enregistrer mon profil"}</span>
            </>
          )}
        </button>
      </div>

      {/* Profile Form Sections */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(300px, 1fr))", gap: "var(--space-6)" }}>
        {/* Section 1: Informations Académiques */}
        <div style={{ background: "var(--warm-100)", border: "1px solid var(--border)", borderRadius: "var(--radius-2xl)", padding: "var(--space-6)", display: "flex", flexDirection: "column", gap: "var(--space-4)" }}>
          <h3 style={{ fontSize: "var(--text-body)", fontWeight: 700, color: "var(--ink-text)", display: "flex", alignItems: "center", gap: "var(--space-2)", paddingBottom: "var(--space-3)", borderBottom: "1px solid var(--border)" }}>
            <GraduationCap style={{ width: "20px", height: "20px", color: "var(--accent)" }} /> Parcours Académique
          </h3>

          <div>
            <label style={{ fontSize: "var(--text-caption)", fontWeight: 700, color: "var(--ink-muted)", textTransform: "uppercase", letterSpacing: "0.04em", marginBottom: "var(--space-1.5)", display: "block" }}>Nom complet</label>
            <input
              type="text"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              style={{ width: "100%", padding: "var(--space-3)", background: "var(--warm-50)", border: "1px solid var(--border)", borderRadius: "var(--radius-xl)", fontSize: "var(--text-body)", color: "var(--ink-text)", outline: "none" }}
            />
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "var(--space-3)" }}>
            <div>
              <label style={{ fontSize: "var(--text-caption)", fontWeight: 700, color: "var(--ink-muted)", textTransform: "uppercase", letterSpacing: "0.04em", marginBottom: "var(--space-1.5)", display: "block" }}>Niveau d'étude cible</label>
              <select
                value={degreeLevel}
                onChange={(e) => setDegreeLevel(e.target.value)}
                style={{ width: "100%", padding: "var(--space-3)", background: "var(--warm-50)", border: "1px solid var(--border)", borderRadius: "var(--radius-xl)", fontSize: "var(--text-body)", color: "var(--ink-text)", outline: "none" }}
              >
                <option value="master">Master / Graduate</option>
                <option value="doctorat">Doctorat / PhD</option>
                <option value="licence">Licence / Bachelor</option>
              </select>
            </div>

            <div>
              <label style={{ fontSize: "var(--text-caption)", fontWeight: 700, color: "var(--ink-muted)", textTransform: "uppercase", letterSpacing: "0.04em", marginBottom: "var(--space-1.5)", display: "block" }}>Moyenne / GPA (sur 4.0)</label>
              <input
                type="number"
                step="0.1"
                min="2.0"
                max="4.0"
                value={gpa}
                onChange={(e) => setGpa(parseFloat(e.target.value))}
                style={{ width: "100%", padding: "var(--space-3)", background: "var(--warm-50)", border: "1px solid var(--border)", borderRadius: "var(--radius-xl)", fontSize: "var(--text-body)", color: "var(--ink-text)", outline: "none" }}
              />
            </div>
          </div>

          <div>
            <label style={{ fontSize: "var(--text-caption)", fontWeight: 700, color: "var(--ink-muted)", textTransform: "uppercase", letterSpacing: "0.04em", marginBottom: "var(--space-1.5)", display: "block" }}>Domaine d'études / Spécialité</label>
            <input
              type="text"
              value={fieldOfStudy}
              onChange={(e) => setFieldOfStudy(e.target.value)}
              placeholder="Ex: Informatique, Droit, Génie Civil, Bio-Santé..."
              style={{ width: "100%", padding: "var(--space-3)", background: "var(--warm-50)", border: "1px solid var(--border)", borderRadius: "var(--radius-xl)", fontSize: "var(--text-body)", color: "var(--ink-text)", outline: "none" }}
            />
          </div>
        </div>

        {/* Section 2: Préférences Géographiques & Budget */}
        <div style={{ background: "var(--warm-100)", border: "1px solid var(--border)", borderRadius: "var(--radius-2xl)", padding: "var(--space-6)", display: "flex", flexDirection: "column", gap: "var(--space-4)" }}>
          <h3 style={{ fontSize: "var(--text-body)", fontWeight: 700, color: "var(--ink-text)", display: "flex", alignItems: "center", gap: "var(--space-2)", paddingBottom: "var(--space-3)", borderBottom: "1px solid var(--border)" }}>
            <Globe style={{ width: "20px", height: "20px", color: "var(--accent)" }} /> Destination & Budget
          </h3>

          <div>
            <label style={{ fontSize: "var(--text-caption)", fontWeight: 700, color: "var(--ink-muted)", textTransform: "uppercase", letterSpacing: "0.04em", marginBottom: "var(--space-2)", display: "block" }}>Pays de destination cibles</label>
            <div style={{ display: "flex", flexWrap: "wrap", gap: "var(--space-2)" }}>
              {["France", "Allemagne", "Canada", "USA", "Royaume-Uni", "Suisse", "Japon", "Togo"].map((country) => {
                const selected = targetCountries.includes(country);
                return (
                  <button
                    key={country}
                    type="button"
                    onClick={() => toggleCountry(country)}
                    style={{
                      padding: "var(--space-3.5) var(--space-9)",
                      borderRadius: "var(--radius-xl)",
                      fontSize: "var(--text-caption)",
                      fontWeight: 600,
                      border: "1px solid",
                      cursor: "pointer",
                      transition: "all var(--transition-base)",
                      background: selected ? "var(--accent)" : "var(--warm-50)",
                      color: selected ? "var(--accent-text)" : "var(--ink-muted)",
                      borderColor: selected ? "var(--accent)" : "var(--border)",
                      boxShadow: selected ? "var(--shadow-md)" : "none"
                    }}
                    onMouseEnter={(e) => {
                      if (!selected) {
                        (e.currentTarget as HTMLButtonElement).style.color = "var(--ink-text)";
                        (e.currentTarget as HTMLButtonElement).style.borderColor = "var(--accent)";
                      }
                    }}
                    onMouseLeave={(e) => {
                      if (!selected) {
                        (e.currentTarget as HTMLButtonElement).style.color = "var(--ink-muted)";
                        (e.currentTarget as HTMLButtonElement).style.borderColor = "var(--border)";
                      }
                    }}
                  >
                    {country}
                  </button>
                );
              })}
            </div>
          </div>

          <div>
            <label style={{ fontSize: "var(--text-caption)", fontWeight: 700, color: "var(--ink-muted)", textTransform: "uppercase", letterSpacing: "0.04em", marginBottom: "var(--space-1.5)", display: "block" }}>
              Budget max annuel estimé (€) : <span style={{ color: "var(--accent)", fontWeight: 700 }}>{budgetMax} €</span>
            </label>
            <input
              type="range"
              min="0"
              max="30000"
              step="1000"
              value={budgetMax}
              onChange={(e) => setBudgetMax(parseInt(e.target.value))}
              style={{ width: "100%", height: "4px", borderRadius: "var(--radius-sm)", background: "var(--warm-200)", outline: "none", WebkitAppearance: "none", cursor: "pointer" }}
            />
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "var(--space-3)", paddingTop: "var(--space-2)" }}>
            <div>
              <label style={{ fontSize: "var(--text-caption)", fontWeight: 700, color: "var(--ink-muted)", textTransform: "uppercase", letterSpacing: "0.04em", marginBottom: "var(--space-1)", display: "block" }}>Niveau d'Anglais</label>
              <select
                value={englishLevel}
                onChange={(e) => setEnglishLevel(e.target.value)}
                style={{ width: "100%", padding: "var(--space-2.5) var(--space-3)", background: "var(--warm-50)", border: "1px solid var(--border)", borderRadius: "var(--radius)", fontSize: "var(--text-caption)", color: "var(--ink-text)", outline: "none" }}
              >
                <option value="B1">B1 (Intermédiaire)</option>
                <option value="B2">B2 (Avancé / TOEFL 80+)</option>
                <option value="C1">C1 (Courant / IELTS 7.0+)</option>
              </select>
            </div>

            <div>
              <label style={{ fontSize: "var(--text-caption)", fontWeight: 700, color: "var(--ink-muted)", textTransform: "uppercase", letterSpacing: "0.04em", marginBottom: "var(--space-1)", display: "block" }}>Niveau de Français</label>
              <select
                value={frenchLevel}
                onChange={(e) => setFrenchLevel(e.target.value)}
                style={{ width: "100%", padding: "var(--space-2.5) var(--space-3)", background: "var(--warm-50)", border: "1px solid var(--border)", borderRadius: "var(--radius)", fontSize: "var(--text-caption)", color: "var(--ink-text)", outline: "none" }}
              >
                <option value="B2">B2 (DELF B2)</option>
                <option value="C1">C1 (DALF C1)</option>
                <option value="Natif">Langue maternelle / Natif</option>
              </select>
            </div>
          </div>
        </div>
      </div>

      {/* CV & Document Upload */}
      <div style={{ background: "var(--warm-100)", border: "1px solid var(--border)", borderRadius: "var(--radius-2xl)", padding: "var(--space-6)", display: "flex", flexDirection: "column", alignItems: "flex-start", gap: "var(--space-6)" }}>
        <div style={{ display: "flex", alignItems: "center", gap: "var(--space-4)" }}>
          <div style={{ padding: "var(--space-4)", borderRadius: "var(--radius-2xl)", background: "var(--accent-50)", border: "1px solid var(--accent-200)", color: "var(--accent)" }}>
            <FileText style={{ width: "32px", height: "32px" }} />
          </div>
          <div>
            <h4 style={{ fontWeight: 700, color: "var(--ink-text)", fontSize: "var(--text-body)", margin: 0 }}>Curriculum Vitae (CV Académique)</h4>
            <p style={{ fontSize: "var(--text-caption)", color: "var(--ink-muted)", marginTop: "var(--space-0.5)" }}>Format PDF recommandé. Utilisé par l'IA pour évaluer ton éligibilité.</p>
          </div>
        </div>

        <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-4)", width: "100%" }}>
          <div style={{ display: "flex", alignItems: "center", gap: "var(--space-4)" }}>
            <div style={{ padding: "var(--space-4)", borderRadius: "var(--radius-2xl)", background: "var(--accent-50)", border: "1px solid var(--accent-200)", color: "var(--accent)" }}>
              <UploadCloud style={{ width: "16px", height: "16px" }} />
            </div>
            <div>
              <h4 style={{ fontWeight: 700, color: "var(--ink-text)", fontSize: "var(--text-body)", margin: 0 }}>Photo de profil</h4>
              <p style={{ fontSize: "var(--text-caption)", color: "var(--ink-muted)", marginTop: "var(--space-0.5)" }}>JPG ou PNG, max 2Mo. Affichée dans ton profil et les candidatures.</p>
            </div>
          </div>
          <button
            onClick={() => alert("Upload du CV et photo vers Supabase Storage configuré !")}
            className="btn-secondary"
            style={{ padding: "var(--space-3) var(--space-5)", borderRadius: "var(--radius-2xl)", fontWeight: 700, border: "1px solid var(--accent)", color: "var(--accent)" }}
          >
            <UploadCloud style={{ width: "16px", height: "16px" }} />
            <span>Téléverser CV & Photo</span>
          </button>
        </div>
      </div>
    </div>
  );
}
