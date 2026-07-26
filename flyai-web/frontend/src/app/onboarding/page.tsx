"use client";

import Image from "next/image";
import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { onAuthStateChanged } from "firebase/auth";
import { auth } from "@/lib/firebase";
import { ArrowRight, ArrowLeft, Check, GraduationCap, Globe2, MapPin, Sparkles, Plus, Trash2 } from "lucide-react";

interface ProfileState {
  fullName: string;
  degreeLevel: string;
  fieldOfStudy: string;
  university: string;
  averageOutOf20: number;
  gpa: number;
  nationality: string;
  englishLevel: string;
  frenchLevel: string;
  otherLanguages: { language: string; level: string }[];
  targetCountries: string[];
  needsFullFunding: boolean;
  projectSummary: string;
}

const WORLD_COUNTRIES = [
  "Algerie","Angola","Benin","Botswana","Burkina Faso","Burundi","Cameroun","Cap-Vert",
  "Congo","RD Congo","Cote d Ivoire","Djibouti","Egypte","Erythree","Ethiopie","Gabon",
  "Ghana","Guinee","Kenya","Lesotho","Liberia","Libye","Madagascar","Malawi","Mali",
  "Maroc","Maurice","Mauritanie","Mozambique","Namibie","Niger","Nigeria","Ouganda",
  "Rwanda","Senegal","Seychelles","Sierra Leone","Somalie","Soudan","Tchad","Togo",
  "Tunisie","Zambie","Zimbabwe","France","Allemagne","Belgique","Suisse","Canada",
  "Etats-Unis","Royaume-Uni","Espagne","Italie","Portugal","Chine","Japon","Inde",
  "Bresil","Mexique","Australie","Autre nationalite"
];

const FIELDS = [
  "Informatique & Intelligence Artificielle","Genie Logiciel & Cybersecurite",
  "Data Science & Big Data","Ingenierie Electrique & Electronique",
  "Ingenierie Mecanique & Mecatronique","Genie Civil & BTP",
  "Ingenierie Chimique & Materiaux","Aeronautique & Spatial",
  "Medecine Generale & Chirurgie","Pharmacie & Biologie Medicale",
  "Sante Publique & Epidemiologie","Economie, Finance & Gestion",
  "Management & Business Administration","Marketing Digital & Commerce International",
  "Droit International & Droit des Affaires","Sciences Politiques & Relations Internationales",
  "Physique, Chimie & Materiaux","Biotechnologies & Bio-Ingenierie",
  "Mathematiques & Statistique Appliquee","Sciences de l Environnement & Energies Renouvelables",
  "Agronomie, Agriculture & Agroalimentaire","Architecture, Urbanisme & Design",
  "Sciences Humaines & Philosophie","Psychologie & Neurosciences",
  "Journalisme, Communication & Medias","Education & Sciences de l Enseignement",
];

const DESTINATIONS = [
  "France","Allemagne","Royaume-Uni","Canada","Etats-Unis","Suisse","Belgique",
  "Pays-Bas","Suede","Norvege","Danemark","Finlande","Italie","Espagne","Portugal",
  "Japon","Chine","Coree du Sud","Singapour","Australie","Maroc","Senegal",
  "Afrique du Sud","Tunisie","Rwanda","Emirats Arabes Unis"
];

const CEFR = ["A1","A2","B1","B2","C1","C2","Natif"];

const DEGREES = [
  { value: "licence", label: "Licence / Bachelor", desc: "1ere a 3eme annee" },
  { value: "master",  label: "Master / Postgraduate", desc: "M1 / M2 / MBA" },
  { value: "doctorat", label: "Doctorat / PhD", desc: "Recherche avancee" },
  { value: "ingenieur", label: "Diplome d Ingenieur", desc: "Cycle specialise" },
];

// 7 etapes micro-succes -- §4.3 onboarding
const STEPS = [
  { id: "identity",     label: "Identite",      short: "Qui etes-vous ?" },
  { id: "academic",     label: "Parcours",      short: "Votre niveau d etudes" },
  { id: "average",      label: "Resultats",     short: "Vos resultats academiques" },
  { id: "languages",    label: "Langues",       short: "Vos niveaux de langue" },
  { id: "destination",  label: "Destinations",  short: "Ou souhaitez-vous etudier ?" },
  { id: "funding",      label: "Financement",   short: "Vos besoins de financement" },
  { id: "project",      label: "Projet",        short: "En une phrase, votre projet" },
];

// Input style reutilisable
const inputSt: React.CSSProperties = {
  width: "100%",
  padding: "10px 14px",
  background: "var(--warm-100)",
  border: "1px solid var(--border)",
  borderRadius: "var(--radius)",
  fontSize: "var(--text-body)",
  color: "var(--ink-text)",
  outline: "none",
  transition: "border-color var(--transition-base)",
};

const labelSt: React.CSSProperties = {
  fontSize: "var(--text-caption)",
  fontWeight: 600,
  textTransform: "uppercase",
  letterSpacing: "0.04em",
  color: "var(--ink-subtle)",
  display: "block",
  marginBottom: 6,
};

export default function OnboardingPage() {
  const router = useRouter();
  const [step, setStep] = useState(0);
  const [user, setUser] = useState<any>(null);
  const [saving, setSaving] = useState(false);

  const [profile, setProfile] = useState<ProfileState>({
    fullName: "",
    degreeLevel: "master",
    fieldOfStudy: "Informatique & Intelligence Artificielle",
    university: "",
    averageOutOf20: 14,
    gpa: 3.5,
    nationality: "Senegal",
    englishLevel: "B2",
    frenchLevel: "C1",
    otherLanguages: [],
    targetCountries: ["France", "Allemagne"],
    needsFullFunding: true,
    projectSummary: "",
  });

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, (u) => {
      setUser(u);
      if (u?.displayName) setProfile((p) => ({ ...p, fullName: u.displayName || "" }));
    });
    return () => unsub();
  }, []);

  const convert20To4 = (avg: number) => {
    if (avg >= 16) return 4.0;
    if (avg >= 14) return parseFloat((3.5 + (avg - 14) * 0.25).toFixed(2));
    if (avg >= 12) return parseFloat((3.0 + (avg - 12) * 0.25).toFixed(2));
    if (avg >= 10) return parseFloat((2.5 + (avg - 10) * 0.25).toFixed(2));
    return 1.5;
  };

  const canNext = () => {
    if (step === 0) return !!profile.fullName && !!profile.nationality;
    if (step === 1) return !!profile.degreeLevel && !!profile.fieldOfStudy;
    if (step === 2) return profile.averageOutOf20 >= 0;
    if (step === 3) return !!profile.englishLevel;
    if (step === 4) return profile.targetCountries.length > 0;
    if (step === 5) return true;
    if (step === 6) return true;
    return false;
  };

  const handleNext = async () => {
    if (step < STEPS.length - 1) {
      setStep(step + 1);
      return;
    }
    setSaving(true);
    try {
      if (user) {
        await fetch("/api/profile", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            userId: user.uid,
            fullName: profile.fullName || user.displayName || "Etudiant FlyAI",
            degreeLevel: profile.degreeLevel,
            fieldOfStudy: profile.fieldOfStudy,
            nationality: profile.nationality,
            targetCountries: profile.targetCountries,
            gpa: profile.gpa,
            needsFullFunding: profile.needsFullFunding,
            projectSummary: profile.projectSummary,
            languages: { english: profile.englishLevel, french: profile.frenchLevel, others: profile.otherLanguages },
          }),
        });
        router.push("/dashboard");
      } else {
        localStorage.setItem("flyai_onboarding_profile", JSON.stringify(profile));
        router.push("/auth/signup");
      }
    } catch {
      router.push("/dashboard");
    } finally {
      setSaving(false);
    }
  };

  const pct = Math.round(((step + 1) / STEPS.length) * 100);

  return (
    <div style={{ minHeight: "100vh", background: "var(--warm-50)", display: "flex", flexDirection: "column", padding: "var(--space-6)", fontFamily: "var(--font-body)" }}>

      {/* Header */}
      <div style={{ maxWidth: 560, margin: "0 auto", width: "100%", display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "var(--space-6)" }}>
        <div style={{ display: "flex", alignItems: "center", gap: "var(--space-3)" }}>
          <div style={{ width: 32, height: 32, borderRadius: "var(--radius)", background: "var(--ink-800)", display: "flex", alignItems: "center", justifyContent: "center" }}>
            <Sparkles size={16} color="white" />
          </div>
          <span style={{ fontFamily: "var(--font-display)", fontSize: "1.1rem", color: "var(--ink-text)" }}>
            Fly<span style={{ color: "var(--accent)" }}>AI</span>
          </span>
        </div>
        <span style={{ fontSize: "var(--text-caption)", color: "var(--ink-subtle)", fontWeight: 600 }}>
          Etape {step + 1} / {STEPS.length}
        </span>
      </div>

      {/* Barre de progression */}
      <div style={{ maxWidth: 560, margin: "0 auto var(--space-6)", width: "100%" }}>
        {/* Steps pills */}
        <div style={{ display: "flex", gap: 4, marginBottom: "var(--space-3)" }}>
          {STEPS.map((s, i) => (
            <div key={s.id} style={{ flex: 1, height: 3, borderRadius: 2, background: i <= step ? "var(--accent)" : "var(--warm-300)", transition: "background 300ms" }} />
          ))}
        </div>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
          <span style={{ fontSize: "var(--text-caption)", color: "var(--ink-subtle)" }}>{STEPS[step].short}</span>
          <span style={{ fontSize: "var(--text-caption)", color: "var(--accent)", fontWeight: 700 }}>{pct}%</span>
        </div>
      </div>

      {/* Card */}
      <div style={{ maxWidth: 560, margin: "0 auto", width: "100%", background: "var(--warm-50)", border: "1px solid var(--border)", borderRadius: "var(--radius-lg)", padding: "var(--space-8)", boxShadow: "var(--shadow-md)", display: "flex", flexDirection: "column", gap: "var(--space-6)" }}>

        {/* Etape 0 — Identite */}
        {step === 0 && (
          <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-4)" }}>
            <div style={{ textAlign: "center" }}>
              <h2 style={{ fontFamily: "var(--font-display)", fontSize: "var(--text-h1)", fontWeight: 400, color: "var(--ink-text)", margin: "0 0 var(--space-2)" }}>
                Bonjour, qui etes-vous ?
              </h2>
              <p style={{ fontSize: "var(--text-body)", color: "var(--ink-muted)", margin: 0 }}>
                Ces informations determinent votre eligibilite aux bourses reservees a certaines nationalites.
              </p>
            </div>
            <div>
              <label style={labelSt}>Votre nom complet</label>
              <input style={inputSt} type="text" placeholder="Prenom Nom" value={profile.fullName} onChange={(e) => setProfile({ ...profile, fullName: e.target.value })} />
            </div>
            <div>
              <label style={labelSt}>Nationalite / Pays d origine</label>
              <select style={inputSt} value={profile.nationality} onChange={(e) => setProfile({ ...profile, nationality: e.target.value })}>
                {WORLD_COUNTRIES.map((c) => <option key={c} value={c}>{c}</option>)}
              </select>
            </div>
            <div>
              <label style={labelSt}>Universite actuelle (facultatif)</label>
              <input style={inputSt} type="text" placeholder="Ex: Universite Cheikh Anta Diop" value={profile.university} onChange={(e) => setProfile({ ...profile, university: e.target.value })} />
            </div>
          </div>
        )}

        {/* Etape 1 — Parcours academique */}
        {step === 1 && (
          <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-4)" }}>
            <div style={{ textAlign: "center" }}>
              <h2 style={{ fontFamily: "var(--font-display)", fontSize: "var(--text-h1)", fontWeight: 400, color: "var(--ink-text)", margin: "0 0 var(--space-2)" }}>
                Votre parcours academique
              </h2>
              <p style={{ fontSize: "var(--text-body)", color: "var(--ink-muted)", margin: 0 }}>
                Le niveau d etudes est un filtre eliminatoire dans la plupart des bourses d excellence.
              </p>
            </div>
            <div>
              <label style={labelSt}>Niveau d etudes vise</label>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "var(--space-3)" }}>
                {DEGREES.map((d) => {
                  const sel = profile.degreeLevel === d.value;
                  return (
                    <button key={d.value} onClick={() => setProfile({ ...profile, degreeLevel: d.value })} style={{ padding: "var(--space-3) var(--space-4)", borderRadius: "var(--radius)", border: `1px solid ${sel ? "var(--accent)" : "var(--border)"}`, background: sel ? "var(--accent-light)" : "var(--warm-100)", cursor: "pointer", textAlign: "left", transition: "all var(--transition-base)" }}>
                      <div style={{ fontSize: "var(--text-body)", fontWeight: 600, color: sel ? "var(--accent)" : "var(--ink-text)" }}>{d.label}</div>
                      <div style={{ fontSize: "10px", color: "var(--ink-subtle)", marginTop: 2 }}>{d.desc}</div>
                    </button>
                  );
                })}
              </div>
            </div>
            <div>
              <label style={labelSt}>Domaine d etudes principal</label>
              <select style={inputSt} value={profile.fieldOfStudy} onChange={(e) => setProfile({ ...profile, fieldOfStudy: e.target.value })}>
                {FIELDS.map((f) => <option key={f} value={f}>{f}</option>)}
              </select>
            </div>
          </div>
        )}

        {/* Etape 2 — Resultats */}
        {step === 2 && (
          <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-4)" }}>
            <div style={{ textAlign: "center" }}>
              <h2 style={{ fontFamily: "var(--font-display)", fontSize: "var(--text-h1)", fontWeight: 400, color: "var(--ink-text)", margin: "0 0 var(--space-2)" }}>
                Vos resultats academiques
              </h2>
              <p style={{ fontSize: "var(--text-body)", color: "var(--ink-muted)", margin: 0 }}>
                La moyenne sert a calculer votre score de compatibilite avec les bourses d excellence.
              </p>
            </div>
            <div style={{ padding: "var(--space-6)", background: "var(--warm-100)", border: "1px solid var(--border)", borderRadius: "var(--radius)" }}>
              <label style={labelSt}>Moyenne generale (sur 20)</label>
              <div style={{ display: "flex", alignItems: "center", gap: "var(--space-4)", marginTop: "var(--space-2)" }}>
                <input
                  type="number" step="0.1" min="0" max="20"
                  value={profile.averageOutOf20}
                  onChange={(e) => {
                    const v = Math.min(20, Math.max(0, parseFloat(e.target.value) || 0));
                    setProfile({ ...profile, averageOutOf20: v, gpa: convert20To4(v) });
                  }}
                  style={{ ...inputSt, width: 120, fontSize: "1.25rem", fontWeight: 700, color: "var(--accent)", textAlign: "center" }}
                />
                <div>
                  <div style={{ fontSize: "var(--text-caption)", color: "var(--ink-subtle)" }}>Equivalent GPA (4.0)</div>
                  <div style={{ fontSize: "var(--text-h2)", fontWeight: 700, color: "var(--ink-text)" }}>{profile.gpa} / 4.00</div>
                </div>
              </div>
              {/* Jauge visuelle */}
              <div style={{ marginTop: "var(--space-4)" }}>
                <div className="score-gauge">
                  <div className="score-gauge-fill" style={{ width: `${(profile.averageOutOf20 / 20) * 100}%` }} />
                </div>
                <div style={{ display: "flex", justifyContent: "space-between", marginTop: 4 }}>
                  <span style={{ fontSize: "10px", color: "var(--ink-subtle)" }}>0/20</span>
                  <span style={{ fontSize: "10px", color: profile.averageOutOf20 >= 14 ? "var(--accent)" : "var(--alert)", fontWeight: 600 }}>
                    {profile.averageOutOf20 >= 16 ? "Excellent" : profile.averageOutOf20 >= 14 ? "Tres bien" : profile.averageOutOf20 >= 12 ? "Bien" : "Passable"}
                  </span>
                  <span style={{ fontSize: "10px", color: "var(--ink-subtle)" }}>20/20</span>
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Etape 3 — Langues */}
        {step === 3 && (
          <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-4)" }}>
            <div style={{ textAlign: "center" }}>
              <h2 style={{ fontFamily: "var(--font-display)", fontSize: "var(--text-h1)", fontWeight: 400, color: "var(--ink-text)", margin: "0 0 var(--space-2)" }}>
                Vos niveaux de langue
              </h2>
              <p style={{ fontSize: "var(--text-body)", color: "var(--ink-muted)", margin: 0 }}>
                Le niveau de langue est souvent un critere eliminatoire. Soyez precis.
              </p>
            </div>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "var(--space-4)" }}>
              <div>
                <label style={labelSt}>Anglais (CEFR)</label>
                <select style={inputSt} value={profile.englishLevel} onChange={(e) => setProfile({ ...profile, englishLevel: e.target.value })}>
                  {CEFR.map((l) => <option key={l} value={l}>{l}</option>)}
                </select>
              </div>
              <div>
                <label style={labelSt}>Francais (CEFR)</label>
                <select style={inputSt} value={profile.frenchLevel} onChange={(e) => setProfile({ ...profile, frenchLevel: e.target.value })}>
                  {CEFR.map((l) => <option key={l} value={l}>{l}</option>)}
                </select>
              </div>
            </div>
            <div>
              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: "var(--space-2)" }}>
                <label style={{ ...labelSt, marginBottom: 0 }}>Autres langues</label>
                <button onClick={() => setProfile((p) => ({ ...p, otherLanguages: [...p.otherLanguages, { language: "Espagnol", level: "B1" }] }))} style={{ fontSize: "var(--text-caption)", color: "var(--accent)", fontWeight: 600, background: "none", border: "none", cursor: "pointer", display: "flex", alignItems: "center", gap: 4 }}>
                  <Plus size={12} /> Ajouter
                </button>
              </div>
              {profile.otherLanguages.map((item, idx) => (
                <div key={idx} style={{ display: "flex", gap: "var(--space-2)", marginBottom: "var(--space-2)" }}>
                  <input type="text" placeholder="Langue" value={item.language} onChange={(e) => { const u = [...profile.otherLanguages]; u[idx].language = e.target.value; setProfile({ ...profile, otherLanguages: u }); }} style={{ ...inputSt, flex: 1 }} />
                  <select value={item.level} onChange={(e) => { const u = [...profile.otherLanguages]; u[idx].level = e.target.value; setProfile({ ...profile, otherLanguages: u }); }} style={{ ...inputSt, width: 90 }}>
                    {CEFR.map((l) => <option key={l} value={l}>{l}</option>)}
                  </select>
                  <button onClick={() => setProfile((p) => ({ ...p, otherLanguages: p.otherLanguages.filter((_, i) => i !== idx) }))} style={{ background: "none", border: "1px solid var(--border)", borderRadius: "var(--radius)", padding: "4px 8px", cursor: "pointer", color: "var(--alert)" }}>
                    <Trash2 size={13} />
                  </button>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Etape 4 — Destinations */}
        {step === 4 && (
          <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-4)" }}>
            <div style={{ textAlign: "center" }}>
              <h2 style={{ fontFamily: "var(--font-display)", fontSize: "var(--text-h1)", fontWeight: 400, color: "var(--ink-text)", margin: "0 0 var(--space-2)" }}>
                Destinations souhaitees
              </h2>
              <p style={{ fontSize: "var(--text-body)", color: "var(--ink-muted)", margin: 0 }}>
                Selectionnez les pays ou vous souhaitez etudier. Votre selection oriente le scoring.
              </p>
            </div>
            <div style={{ display: "grid", gridTemplateColumns: "repeat(3, 1fr)", gap: "var(--space-2)" }}>
              {DESTINATIONS.map((name) => {
                const sel = profile.targetCountries.includes(name);
                return (
                  <button key={name} onClick={() => setProfile((p) => ({ ...p, targetCountries: sel ? p.targetCountries.filter((c) => c !== name) : [...p.targetCountries, name] }))} style={{ padding: "var(--space-2) var(--space-3)", borderRadius: "var(--radius)", border: `1px solid ${sel ? "var(--accent)" : "var(--border)"}`, background: sel ? "var(--accent-light)" : "var(--warm-100)", color: sel ? "var(--accent)" : "var(--ink-muted)", fontSize: "var(--text-caption)", fontWeight: sel ? 700 : 400, cursor: "pointer", transition: "all var(--transition-base)", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>
                    {name}
                  </button>
                );
              })}
            </div>
            {profile.targetCountries.length > 0 && (
              <p style={{ fontSize: "var(--text-caption)", color: "var(--accent)", fontWeight: 600 }}>
                {profile.targetCountries.length} destination{profile.targetCountries.length > 1 ? "s" : ""} selectionnee{profile.targetCountries.length > 1 ? "s" : ""}
              </p>
            )}
          </div>
        )}

        {/* Etape 5 — Financement */}
        {step === 5 && (
          <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-4)" }}>
            <div style={{ textAlign: "center" }}>
              <h2 style={{ fontFamily: "var(--font-display)", fontSize: "var(--text-h1)", fontWeight: 400, color: "var(--ink-text)", margin: "0 0 var(--space-2)" }}>
                Vos besoins de financement
              </h2>
              <p style={{ fontSize: "var(--text-body)", color: "var(--ink-muted)", margin: 0 }}>
                Cette information oriente la selection vers les bourses de financement complet ou partiel.
              </p>
            </div>
            <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-3)" }}>
              {[{ v: true, label: "Financement complet necessaire", desc: "Frais de scolarite + allocation de vie" }, { v: false, label: "Financement partiel acceptable", desc: "Je peux couvrir une partie des frais" }].map((opt) => {
                const sel = profile.needsFullFunding === opt.v;
                return (
                  <button key={String(opt.v)} onClick={() => setProfile({ ...profile, needsFullFunding: opt.v })} style={{ padding: "var(--space-4) var(--space-6)", borderRadius: "var(--radius)", border: `1px solid ${sel ? "var(--accent)" : "var(--border)"}`, background: sel ? "var(--accent-light)" : "var(--warm-100)", cursor: "pointer", textAlign: "left", transition: "all var(--transition-base)" }}>
                    <div style={{ fontSize: "var(--text-body)", fontWeight: 600, color: sel ? "var(--accent)" : "var(--ink-text)" }}>{opt.label}</div>
                    <div style={{ fontSize: "var(--text-caption)", color: "var(--ink-subtle)", marginTop: 4 }}>{opt.desc}</div>
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {/* Etape 6 — Projet (micro-commitment) */}
        {step === 6 && (
          <div style={{ display: "flex", flexDirection: "column", gap: "var(--space-4)" }}>
            <div style={{ textAlign: "center" }}>
              <h2 style={{ fontFamily: "var(--font-display)", fontSize: "var(--text-h1)", fontWeight: 400, color: "var(--ink-text)", margin: "0 0 var(--space-2)" }}>
                Votre projet, en une phrase
              </h2>
              <p style={{ fontSize: "var(--text-body)", color: "var(--ink-muted)", margin: 0 }}>
                FlyAgent utilisera ce contexte pour personnaliser ses conseils. Soyez specifique.
              </p>
            </div>
            <div>
              <label style={labelSt}>Votre projet professionnel ou academique</label>
              <textarea
                rows={4}
                placeholder="Ex: Obtenir un Master en IA en Allemagne pour contribuer au developpement de systemes de sante intelligents au Senegal."
                value={profile.projectSummary}
                onChange={(e) => setProfile({ ...profile, projectSummary: e.target.value })}
                style={{ ...inputSt, resize: "vertical", lineHeight: 1.6 }}
              />
              <p style={{ fontSize: "10px", color: "var(--ink-subtle)", marginTop: "var(--space-2)" }}>
                Facultatif — vous pourrez le modifier dans votre profil.
              </p>
            </div>
            <div style={{ padding: "var(--space-4)", background: "var(--accent-light)", border: "1px solid var(--accent)", borderRadius: "var(--radius)" }}>
              <p style={{ fontSize: "var(--text-body)", color: "var(--accent)", margin: 0, fontWeight: 500 }}>
                Votre profil est pret. FlyAgent va identifier vos meilleures options parmi toutes les bourses disponibles.
              </p>
            </div>
          </div>
        )}

        {/* Navigation */}
        <div style={{ display: "flex", gap: "var(--space-3)", paddingTop: "var(--space-4)", borderTop: "1px solid var(--border)" }}>
          {step > 0 && (
            <button onClick={() => setStep(step - 1)} className="btn-secondary" style={{ display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
              <ArrowLeft size={14} />
              Retour
            </button>
          )}
          <button onClick={handleNext} disabled={!canNext() || saving} className="btn-primary" style={{ flex: 1, justifyContent: "center", opacity: !canNext() || saving ? 0.4 : 1 }}>
            <span>{step === STEPS.length - 1 ? (saving ? "Sauvegarde..." : "Acceder au tableau de bord") : step === 5 ? "Presque fini" : "Continuer"}</span>
            <ArrowRight size={14} />
          </button>
        </div>
      </div>
    </div>
  );
}
