"use client";

import { useState, useEffect, useRef } from "react";
import { UserProfile } from "@/types";
import {
  User, GraduationCap, Globe, Award, FileText, Save,
  CheckCircle2, UploadCloud, Sparkles, MapPin, Languages,
  Camera, Download, Eye
} from "lucide-react";

interface Props {
  userId?: string;
  profile?: UserProfile | null;
  onProfileUpdated?: (updated: UserProfile) => void;
}

const DEGREES = [
  { value: "licence", label: "Licence / Bachelor" },
  { value: "master", label: "Master / Postgraduate" },
  { value: "doctorat", label: "Doctorat / PhD" },
  { value: "ingenieur", label: "Diplôme d'Ingénieur" },
];

const CEFR = ["A1", "A2", "B1", "B2", "C1", "C2", "Natif"];

const DESTINATIONS = [
  "France", "Allemagne", "Royaume-Uni", "Canada", "Etats-Unis", "Suisse",
  "Belgique", "Pays-Bas", "Suede", "Norvege", "Italie", "Espagne", "Portugal",
  "Japon", "Chine", "Coree du Sud", "Singapour", "Australie", "Maroc",
  "Senegal", "Afrique du Sud", "Tunisie", "Rwanda", "Emirats Arabes Unis"
];

const WORLD_COUNTRIES = [
  "Algerie", "Angola", "Benin", "Botswana", "Burkina Faso", "Burundi",
  "Cameroun", "Cap-Vert", "Congo", "RD Congo", "Cote d Ivoire", "Djibouti",
  "Egypte", "Erythree", "Ethiopie", "Gabon", "Ghana", "Guinee", "Kenya",
  "Lesotho", "Liberia", "Libye", "Madagascar", "Malawi", "Mali", "Maroc",
  "Maurice", "Mauritanie", "Mozambique", "Namibie", "Niger", "Nigeria",
  "Ouganda", "Rwanda", "Senegal", "Seychelles", "Sierra Leone", "Somalie",
  "Soudan", "Tchad", "Togo", "Tunisie", "Zambie", "Zimbabwe",
  "France", "Allemagne", "Belgique", "Suisse", "Canada", "Etats-Unis",
  "Royaume-Uni", "Espagne", "Italie", "Portugal", "Chine", "Japon",
  "Inde", "Bresil", "Mexique", "Australie", "Autre nationalite"
];

export default function ProfileTab({ userId, profile, onProfileUpdated }: Props) {
  const [fullName, setFullName] = useState(profile?.fullName || "");
  const [degreeLevel, setDegreeLevel] = useState(profile?.degreeLevel || "master");
  const [targetDegreeLevel, setTargetDegreeLevel] = useState((profile as any)?.targetDegreeLevel || "master");
  const [fieldOfStudy, setFieldOfStudy] = useState(profile?.fieldOfStudy || "");
  const [nationality, setNationality] = useState(profile?.nationality || "Togo");
  const [university, setUniversity] = useState((profile as any)?.university || "");
  const [targetCountries, setTargetCountries] = useState<string[]>(profile?.targetCountries || []);
  const [gpa, setGpa] = useState(profile?.gpa || 3.5);
  const [averageOutOf20, setAverageOutOf20] = useState((profile as any)?.averageOutOf20 || 14);
  const [englishLevel, setEnglishLevel] = useState(profile?.languages?.english || "B2");
  const [frenchLevel, setFrenchLevel] = useState(profile?.languages?.french || "C1");
  const [projectSummary, setProjectSummary] = useState((profile as any)?.projectSummary || "");
  const [photoUrl, setPhotoUrl] = useState(profile?.photoUrl || "");
  const [cvUrl, setCvUrl] = useState(profile?.cvUrl || "");
  const [saving, setSaving] = useState(false);
  const [savedSuccess, setSavedSuccess] = useState(false);
  const [activeSection, setActiveSection] = useState<string>("academic");

  const photoInputRef = useRef<HTMLInputElement>(null);
  const cvInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (profile) {
      setFullName(profile.fullName || "");
      setDegreeLevel(profile.degreeLevel || "master");
      setTargetDegreeLevel((profile as any).targetDegreeLevel || "master");
      setFieldOfStudy(profile.fieldOfStudy || "");
      setNationality(profile.nationality || "Togo");
      setUniversity((profile as any).university || "");
      setTargetCountries(profile.targetCountries || []);
      setGpa(profile.gpa || 3.5);
      setAverageOutOf20((profile as any).averageOutOf20 || 14);
      setEnglishLevel(profile.languages?.english || "B2");
      setFrenchLevel(profile.languages?.french || "C1");
      setProjectSummary((profile as any).projectSummary || "");
      setPhotoUrl(profile.photoUrl || "");
      setCvUrl(profile.cvUrl || "");
    }
  }, [profile]);

  const convert20To4 = (avg: number) => {
    if (avg >= 16) return 4.0;
    if (avg >= 14) return parseFloat((3.5 + (avg - 14) * 0.25).toFixed(2));
    if (avg >= 12) return parseFloat((3.0 + (avg - 12) * 0.25).toFixed(2));
    if (avg >= 10) return parseFloat((2.5 + (avg - 10) * 0.25).toFixed(2));
    return 1.5;
  };

  const handlePhotoChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => setPhotoUrl(reader.result as string);
    reader.readAsDataURL(file);
  };

  const handleCvChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = () => setCvUrl(reader.result as string);
    reader.readAsDataURL(file);
  };

  const handleSave = async () => {
    if (!userId) return;
    setSaving(true);
    setSavedSuccess(false);

    const payload = {
      userId,
      fullName,
      degreeLevel,
      targetDegreeLevel,
      fieldOfStudy,
      nationality,
      university,
      targetCountries,
      gpa,
      averageOutOf20,
      languages: { english: englishLevel, french: frenchLevel },
      projectSummary,
      photoUrl,
      cvUrl,
      onboardingCompleted: true,
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

  const inputStyle: React.CSSProperties = {
    width: "100%",
    padding: "10px 14px",
    background: "var(--warm-50)",
    border: "1px solid var(--border)",
    borderRadius: "var(--radius)",
    fontSize: "var(--text-body)",
    color: "var(--ink-text)",
    outline: "none",
  };

  const labelStyle: React.CSSProperties = {
    fontSize: "var(--text-caption)",
    fontWeight: 700,
    color: "var(--ink-muted)",
    textTransform: "uppercase",
    letterSpacing: "0.04em",
    marginBottom: "6px",
    display: "block",
  };

  const SECTIONS = [
    { id: "academic", label: "Parcours", icon: GraduationCap },
    { id: "destination", label: "Destinations", icon: Globe },
    { id: "languages", label: "Langues", icon: Languages },
    { id: "documents", label: "Documents", icon: FileText },
    { id: "project", label: "Projet", icon: Sparkles },
  ];

  return (
    <div style={{ maxWidth: "900px", margin: "0 auto", display: "flex", flexDirection: "column", gap: "var(--space-6)" }}>

      {/* ── Header Profile Banner ── */}
      <div style={{
        background: "var(--warm-100)", border: "1px solid var(--border)",
        borderRadius: "var(--radius-2xl)", padding: "var(--space-6)",
        display: "flex", flexDirection: "column", gap: "var(--space-4)",
      }}>
        <div style={{ display: "flex", alignItems: "center", gap: "var(--space-4)", flexWrap: "wrap" }}>
          {/* ✅ FIX BUG 6: Photo de profil cliquable pour modifier */}
          <div style={{ position: "relative", flexShrink: 0 }}>
            <div style={{
              width: 80, height: 80, borderRadius: "50%",
              background: "var(--warm-200)",
              display: "flex", alignItems: "center", justifyContent: "center",
              color: "white", fontWeight: 700, fontSize: "1.8rem",
              overflow: "hidden", border: "3px solid var(--accent)",
              boxShadow: "0 4px 16px rgba(15,123,108,0.25)",
            }}>
              {photoUrl ? (
                <img src={photoUrl} alt={fullName} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
              ) : (
                <span style={{ color: "var(--accent)", fontWeight: 800 }}>
                  {fullName?.[0]?.toUpperCase() || "?"}
                </span>
              )}
            </div>
            <button
              onClick={() => photoInputRef.current?.click()}
              title="Changer la photo"
              style={{
                position: "absolute", bottom: -2, right: -2,
                width: 26, height: 26, borderRadius: "50%",
                background: "var(--accent)", border: "2px solid white",
                display: "flex", alignItems: "center", justifyContent: "center",
                cursor: "pointer",
              }}
            >
              <Camera size={12} color="white" />
            </button>
            <input ref={photoInputRef} type="file" accept="image/*" onChange={handlePhotoChange} style={{ display: "none" }} />
          </div>

          <div style={{ flex: 1, minWidth: 0 }}>
            <input
              type="text"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              placeholder="Votre nom complet"
              style={{
                background: "transparent", border: "none", outline: "none",
                fontSize: "1.3rem", fontWeight: 700, color: "var(--ink-text)",
                width: "100%", fontFamily: "var(--font-body)",
              }}
            />
            <div style={{ display: "flex", alignItems: "center", gap: "var(--space-2)", marginTop: 4, flexWrap: "wrap" }}>
              <span style={{
                fontSize: "var(--text-caption)", color: "var(--accent)", fontWeight: 600,
                display: "flex", alignItems: "center", gap: 4,
              }}>
                <Sparkles size={12} />
                Profil FlyAI
              </span>
              {nationality && (
                <span style={{
                  fontSize: "var(--text-caption)", color: "var(--ink-muted)",
                  display: "flex", alignItems: "center", gap: 4,
                }}>
                  <MapPin size={10} /> {nationality}
                </span>
              )}
              {degreeLevel && (
                <span style={{
                  fontSize: "var(--text-caption)", background: "var(--accent-light)",
                  color: "var(--accent)", padding: "2px 8px", borderRadius: "var(--radius-full)",
                  fontWeight: 600,
                }}>
                  {DEGREES.find(d => d.value === degreeLevel)?.label || degreeLevel}
                </span>
              )}
            </div>
          </div>

          {/* Bouton Enregistrer */}
          <button
            onClick={handleSave}
            disabled={saving}
            className="btn-primary"
            style={{ padding: "var(--space-3) var(--space-5)", borderRadius: "var(--radius-2xl)", flexShrink: 0 }}
          >
            {savedSuccess ? (
              <><CheckCircle2 size={16} /><span>Enregistré !</span></>
            ) : (
              <><Save size={16} /><span>{saving ? "Sauvegarde..." : "Enregistrer"}</span></>
            )}
          </button>
        </div>
      </div>

      {/* ── Navigation Sections (tabs) ── */}
      <div style={{
        display: "flex", gap: "var(--space-2)", overflowX: "auto",
        paddingBottom: "var(--space-1)",
      }}>
        {SECTIONS.map((sec) => {
          const Icon = sec.icon;
          const active = activeSection === sec.id;
          return (
            <button
              key={sec.id}
              onClick={() => setActiveSection(sec.id)}
              style={{
                display: "flex", alignItems: "center", gap: "var(--space-2)",
                padding: "var(--space-2) var(--space-4)", borderRadius: "var(--radius-full)",
                border: "1px solid", flexShrink: 0, cursor: "pointer",
                fontSize: "var(--text-caption)", fontWeight: 600,
                background: active ? "var(--accent)" : "var(--warm-100)",
                color: active ? "white" : "var(--ink-muted)",
                borderColor: active ? "var(--accent)" : "var(--border)",
                transition: "all var(--transition-base)",
              }}
            >
              <Icon size={13} />
              {sec.label}
            </button>
          );
        })}
      </div>

      {/* ── Section: Parcours Académique ── */}
      {activeSection === "academic" && (
        <div style={{
          background: "var(--warm-100)", border: "1px solid var(--border)",
          borderRadius: "var(--radius-2xl)", padding: "var(--space-6)",
          display: "flex", flexDirection: "column", gap: "var(--space-5)",
        }}>
          <h3 style={{ fontSize: "var(--text-h2)", fontWeight: 700, color: "var(--ink-text)", margin: 0, display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
            <GraduationCap size={20} style={{ color: "var(--accent)" }} />
            Parcours Académique
          </h3>

          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))", gap: "var(--space-4)" }}>
            <div>
              <label style={labelStyle}>Nationalité / Pays d'origine</label>
              <select style={inputStyle} value={nationality} onChange={(e) => setNationality(e.target.value)}>
                {WORLD_COUNTRIES.map((c) => <option key={c} value={c}>{c}</option>)}
              </select>
            </div>

            <div>
              <label style={labelStyle}>Université actuelle</label>
              <input
                style={inputStyle} type="text" value={university}
                onChange={(e) => setUniversity(e.target.value)}
                placeholder="Ex: Université de Lomé"
              />
            </div>
          </div>

          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))", gap: "var(--space-4)" }}>
            <div>
              <label style={labelStyle}>Niveau actuel</label>
              <select style={inputStyle} value={degreeLevel} onChange={(e) => setDegreeLevel(e.target.value)}>
                {DEGREES.map((d) => <option key={d.value} value={d.value}>{d.label}</option>)}
              </select>
            </div>

            <div>
              <label style={labelStyle}>Niveau visé (pour les recommandations)</label>
              <select style={inputStyle} value={targetDegreeLevel} onChange={(e) => setTargetDegreeLevel(e.target.value)}>
                {DEGREES.map((d) => <option key={d.value} value={d.value}>{d.label}</option>)}
              </select>
            </div>
          </div>

          <div>
            <label style={labelStyle}>Domaine d'études / Spécialité</label>
            <input
              style={inputStyle} type="text" value={fieldOfStudy}
              onChange={(e) => setFieldOfStudy(e.target.value)}
              placeholder="Ex: Informatique & Intelligence Artificielle"
            />
          </div>

          {/* ✅ FIX BUG 6: Moyenne sur 20 éditableave conversion GPA */}
          <div style={{ background: "var(--warm-50)", border: "1px solid var(--border)", borderRadius: "var(--radius)", padding: "var(--space-4)" }}>
            <label style={labelStyle}>Moyenne générale (sur 20)</label>
            <div style={{ display: "flex", alignItems: "center", gap: "var(--space-4)", flexWrap: "wrap" }}>
              <input
                type="number" step="0.1" min="0" max="20"
                value={averageOutOf20}
                onChange={(e) => {
                  const v = Math.min(20, Math.max(0, parseFloat(e.target.value) || 0));
                  setAverageOutOf20(v);
                  setGpa(convert20To4(v));
                }}
                style={{ ...inputStyle, width: 110, fontSize: "1.2rem", fontWeight: 700, color: "var(--accent)", textAlign: "center" }}
              />
              <div>
                <div style={{ fontSize: "var(--text-caption)", color: "var(--ink-subtle)" }}>Équivalent GPA</div>
                <div style={{ fontSize: "1.2rem", fontWeight: 700, color: "var(--ink-text)" }}>{gpa} / 4.00</div>
              </div>
              <div style={{ flex: 1 }}>
                <div style={{
                  height: 6, borderRadius: 3, background: "var(--warm-200)",
                  overflow: "hidden", minWidth: 100,
                }}>
                  <div style={{
                    height: "100%", borderRadius: 3,
                    width: `${(averageOutOf20 / 20) * 100}%`,
                    background: averageOutOf20 >= 14 ? "var(--accent)" : averageOutOf20 >= 12 ? "#d97706" : "var(--alert)",
                    transition: "width 0.3s",
                  }} />
                </div>
                <span style={{ fontSize: "10px", color: averageOutOf20 >= 14 ? "var(--accent)" : "var(--ink-subtle)", fontWeight: 600 }}>
                  {averageOutOf20 >= 16 ? "Excellent" : averageOutOf20 >= 14 ? "Très bien" : averageOutOf20 >= 12 ? "Bien" : "Passable"}
                </span>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ── Section: Destinations ── */}
      {activeSection === "destination" && (
        <div style={{
          background: "var(--warm-100)", border: "1px solid var(--border)",
          borderRadius: "var(--radius-2xl)", padding: "var(--space-6)",
          display: "flex", flexDirection: "column", gap: "var(--space-4)",
        }}>
          <h3 style={{ fontSize: "var(--text-h2)", fontWeight: 700, color: "var(--ink-text)", margin: 0, display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
            <Globe size={20} style={{ color: "var(--accent)" }} />
            Destinations souhaitées
          </h3>
          <p style={{ fontSize: "var(--text-body)", color: "var(--ink-muted)", margin: 0 }}>
            {targetCountries.length} destination{targetCountries.length > 1 ? "s" : ""} sélectionnée{targetCountries.length > 1 ? "s" : ""}
          </p>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(130px, 1fr))", gap: "var(--space-2)" }}>
            {DESTINATIONS.map((country) => {
              const selected = targetCountries.includes(country);
              return (
                <button
                  key={country}
                  onClick={() => toggleCountry(country)}
                  style={{
                    padding: "var(--space-2) var(--space-3)",
                    borderRadius: "var(--radius)", border: "1px solid",
                    fontSize: "var(--text-caption)", fontWeight: selected ? 700 : 400,
                    cursor: "pointer", transition: "all var(--transition-base)",
                    background: selected ? "var(--accent)" : "var(--warm-50)",
                    color: selected ? "white" : "var(--ink-muted)",
                    borderColor: selected ? "var(--accent)" : "var(--border)",
                    whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis",
                  }}
                >
                  {country}
                </button>
              );
            })}
          </div>
        </div>
      )}

      {/* ── Section: Langues ── */}
      {activeSection === "languages" && (
        <div style={{
          background: "var(--warm-100)", border: "1px solid var(--border)",
          borderRadius: "var(--radius-2xl)", padding: "var(--space-6)",
          display: "flex", flexDirection: "column", gap: "var(--space-4)",
        }}>
          <h3 style={{ fontSize: "var(--text-h2)", fontWeight: 700, color: "var(--ink-text)", margin: 0, display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
            <Languages size={20} style={{ color: "var(--accent)" }} />
            Niveaux de langue
          </h3>
          <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(180px, 1fr))", gap: "var(--space-4)" }}>
            <div>
              <label style={labelStyle}>Anglais (CEFR)</label>
              <select style={inputStyle} value={englishLevel} onChange={(e) => setEnglishLevel(e.target.value)}>
                {CEFR.map((l) => <option key={l} value={l}>{l}</option>)}
              </select>
            </div>
            <div>
              <label style={labelStyle}>Français (CEFR)</label>
              <select style={inputStyle} value={frenchLevel} onChange={(e) => setFrenchLevel(e.target.value)}>
                {CEFR.map((l) => <option key={l} value={l}>{l}</option>)}
              </select>
            </div>
          </div>
        </div>
      )}

      {/* ── Section: Documents ── */}
      {activeSection === "documents" && (
        <div style={{
          background: "var(--warm-100)", border: "1px solid var(--border)",
          borderRadius: "var(--radius-2xl)", padding: "var(--space-6)",
          display: "flex", flexDirection: "column", gap: "var(--space-5)",
        }}>
          <h3 style={{ fontSize: "var(--text-h2)", fontWeight: 700, color: "var(--ink-text)", margin: 0, display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
            <FileText size={20} style={{ color: "var(--accent)" }} />
            Documents
          </h3>

          {/* Photo de profil */}
          <div style={{ display: "flex", alignItems: "center", gap: "var(--space-4)", padding: "var(--space-4)", background: "var(--warm-50)", borderRadius: "var(--radius)", border: "1px solid var(--border)", flexWrap: "wrap" }}>
            <div style={{
              width: 64, height: 64, borderRadius: "50%", flexShrink: 0,
              background: "var(--warm-200)", overflow: "hidden",
              display: "flex", alignItems: "center", justifyContent: "center",
              border: photoUrl ? "2px solid var(--accent)" : "2px dashed var(--border)",
            }}>
              {photoUrl ? (
                <img src={photoUrl} alt="Photo" style={{ width: "100%", height: "100%", objectFit: "cover" }} />
              ) : (
                <Camera size={20} style={{ color: "var(--ink-subtle)" }} />
              )}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontWeight: 700, color: "var(--ink-text)", fontSize: "var(--text-body)" }}>Photo de profil</div>
              <div style={{ fontSize: "var(--text-caption)", color: "var(--ink-muted)", marginTop: 2 }}>
                {photoUrl ? "✅ Photo chargée" : "JPG, PNG — recommandé pour vos candidatures"}
              </div>
            </div>
            <input ref={photoInputRef} type="file" accept="image/*" onChange={handlePhotoChange} style={{ display: "none" }} />
            <button
              onClick={() => photoInputRef.current?.click()}
              className="btn-secondary"
              style={{ padding: "var(--space-2) var(--space-4)", flexShrink: 0 }}
            >
              <UploadCloud size={14} />
              <span>{photoUrl ? "Modifier" : "Ajouter"}</span>
            </button>
          </div>

          {/* CV */}
          <div style={{ display: "flex", alignItems: "center", gap: "var(--space-4)", padding: "var(--space-4)", background: "var(--warm-50)", borderRadius: "var(--radius)", border: "1px solid var(--border)", flexWrap: "wrap" }}>
            <div style={{
              width: 64, height: 64, borderRadius: "var(--radius)", flexShrink: 0,
              background: cvUrl ? "var(--accent-light)" : "var(--warm-200)",
              display: "flex", alignItems: "center", justifyContent: "center",
              border: cvUrl ? "2px solid var(--accent)" : "2px dashed var(--border)",
            }}>
              <FileText size={24} style={{ color: cvUrl ? "var(--accent)" : "var(--ink-subtle)" }} />
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontWeight: 700, color: "var(--ink-text)", fontSize: "var(--text-body)" }}>Curriculum Vitae</div>
              <div style={{ fontSize: "var(--text-caption)", color: "var(--ink-muted)", marginTop: 2 }}>
                {cvUrl ? "✅ CV chargé — utilisé par l'IA pour le matching" : "PDF ou Word — fortement recommandé"}
              </div>
            </div>
            <div style={{ display: "flex", gap: "var(--space-2)", flexShrink: 0 }}>
              {cvUrl && (
                <a
                  href={cvUrl}
                  download="mon-cv"
                  target="_blank"
                  rel="noreferrer"
                  className="btn-secondary"
                  style={{ padding: "var(--space-2) var(--space-3)", textDecoration: "none", display: "flex", alignItems: "center", gap: 4 }}
                >
                  <Download size={13} />
                  <span>Voir</span>
                </a>
              )}
              <input ref={cvInputRef} type="file" accept=".pdf,.doc,.docx" onChange={handleCvChange} style={{ display: "none" }} />
              <button
                onClick={() => cvInputRef.current?.click()}
                className="btn-secondary"
                style={{ padding: "var(--space-2) var(--space-4)" }}
              >
                <UploadCloud size={14} />
                <span>{cvUrl ? "Changer" : "Ajouter"}</span>
              </button>
            </div>
          </div>

          <p style={{ fontSize: "var(--text-caption)", color: "var(--ink-subtle)", margin: 0, textAlign: "center" }}>
            Ces documents sont sauvegardés dans votre profil et utilisés pour améliorer le matching.
          </p>
        </div>
      )}

      {/* ── Section: Projet ── */}
      {activeSection === "project" && (
        <div style={{
          background: "var(--warm-100)", border: "1px solid var(--border)",
          borderRadius: "var(--radius-2xl)", padding: "var(--space-6)",
          display: "flex", flexDirection: "column", gap: "var(--space-4)",
        }}>
          <h3 style={{ fontSize: "var(--text-h2)", fontWeight: 700, color: "var(--ink-text)", margin: 0, display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
            <Sparkles size={20} style={{ color: "var(--accent)" }} />
            Projet académique & professionnel
          </h3>
          <p style={{ fontSize: "var(--text-body)", color: "var(--ink-muted)", margin: 0 }}>
            FlyAgent utilise ce contexte pour personnaliser ses conseils. Soyez spécifique.
          </p>
          <textarea
            rows={5}
            value={projectSummary}
            onChange={(e) => setProjectSummary(e.target.value)}
            placeholder="Ex: Obtenir un Master en IA en Allemagne pour développer des systèmes de santé intelligents adaptés à l'Afrique subsaharienne."
            style={{ ...inputStyle, resize: "vertical", lineHeight: 1.6 }}
          />
          <div style={{ padding: "var(--space-3)", background: "var(--accent-light)", borderRadius: "var(--radius)", border: "1px solid var(--accent)" }}>
            <p style={{ fontSize: "var(--text-caption)", color: "var(--accent)", margin: 0, fontWeight: 500 }}>
              💡 Un projet précis améliore significativement la qualité des recommandations de FlyAgent.
            </p>
          </div>
        </div>
      )}

      {/* Bouton Save flottant bas */}
      <div style={{ display: "flex", justifyContent: "center", paddingBottom: "var(--space-8)" }}>
        <button
          onClick={handleSave}
          disabled={saving}
          className="btn-primary"
          style={{ padding: "var(--space-4) var(--space-8)", borderRadius: "var(--radius-2xl)", fontSize: "var(--text-body)" }}
        >
          {savedSuccess ? (
            <><CheckCircle2 size={18} /><span>Profil enregistré avec succès !</span></>
          ) : (
            <><Save size={18} /><span>{saving ? "Sauvegarde en cours..." : "Enregistrer toutes les modifications"}</span></>
          )}
        </button>
      </div>
    </div>
  );
}
