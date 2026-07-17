"use client";

import Image from "next/image";
import { useState } from "react";
import { useRouter } from "next/navigation";
import { ArrowRight, ArrowLeft, Check, GraduationCap, Globe2, BookOpen, MapPin } from "lucide-react";

// ─── Types ────────────────────────────────────────────────────────────────────
interface Profile {
  degreeLevel: string;
  fieldOfStudy: string;
  nationality: string;
  targetCountries: string[];
}

// ─── Data ─────────────────────────────────────────────────────────────────────
const DEGREE_LEVELS = [
  { value: "licence", label: "Licence / Bachelor", icon: "🎓" },
  { value: "master", label: "Master", icon: "📚" },
  { value: "doctorat", label: "Doctorat / PhD", icon: "🔬" },
  { value: "preparatoire", label: "Préparatoire", icon: "📝" },
  { value: "professionnel", label: "Professionnel / MBA", icon: "💼" },
];

const FIELDS = [
  "Informatique & IA", "Ingénierie", "Médecine & Santé", "Sciences",
  "Économie & Gestion", "Droit", "Sciences sociales", "Arts & Design",
  "Agriculture", "Architecture", "Éducation", "Environnement",
];

const NATIONALITIES = [
  "Algérienne", "Béninoise", "Burkinabée", "Camerounaise", "Centrafricaine",
  "Comorienne", "Congolaise", "Côte d'Ivoirienne", "Djiboutienne", "Égyptienne",
  "Éthiopienne", "Gabonaise", "Gambienne", "Ghanéenne", "Guinéenne",
  "Ivoirienne", "Kényane", "Libyenne", "Malgache", "Malienne",
  "Marocaine", "Mauritanienne", "Mozambicaine", "Namibienne", "Nigériane",
  "Nigérienne", "Rwandaise", "Sénégalaise", "Sierra Léonaise", "Somalienne",
  "Soudanaise", "Tanzanienne", "Tchadienne", "Togolaise", "Tunisienne",
  "Ougandaise", "Zambienne", "Zimbabwéenne", "Autre",
];

const TARGET_COUNTRIES = [
  { flag: "🇫🇷", name: "France" },
  { flag: "🇩🇪", name: "Allemagne" },
  { flag: "🇬🇧", name: "Royaume-Uni" },
  { flag: "🇺🇸", name: "États-Unis" },
  { flag: "🇨🇦", name: "Canada" },
  { flag: "🇨🇳", name: "Chine" },
  { flag: "🇯🇵", name: "Japon" },
  { flag: "🇦🇺", name: "Australie" },
  { flag: "🇳🇱", name: "Pays-Bas" },
  { flag: "🇧🇪", name: "Belgique" },
  { flag: "🇨🇭", name: "Suisse" },
  { flag: "🇸🇪", name: "Suède" },
  { flag: "🇳🇴", name: "Norvège" },
  { flag: "🇩🇰", name: "Danemark" },
  { flag: "🇿🇦", name: "Afrique du Sud" },
  { flag: "🇲🇦", name: "Maroc" },
];

// ─── Step Indicator ───────────────────────────────────────────────────────────
function StepDot({ active, done }: { active: boolean; done: boolean }) {
  return (
    <div
      className={`w-2.5 h-2.5 rounded-full transition-all duration-300 ${
        done ? "bg-indigo-500 scale-100" : active ? "bg-white scale-125" : "bg-white/20"
      }`}
    />
  );
}

// ─── Option chip ─────────────────────────────────────────────────────────────
function Chip({
  selected,
  onClick,
  children,
}: {
  selected: boolean;
  onClick: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      onClick={onClick}
      className={`px-4 py-2.5 rounded-full text-sm font-medium border transition-all duration-200 ${
        selected
          ? "bg-indigo-600 border-indigo-500 text-white shadow-lg shadow-indigo-500/25"
          : "bg-white/5 border-white/10 text-slate-300 hover:border-white/20 hover:text-white"
      }`}
    >
      {children}
    </button>
  );
}

// ─── Main Onboarding Page ─────────────────────────────────────────────────────
export default function OnboardingPage() {
  const router = useRouter();
  const [step, setStep] = useState(0);
  const [profile, setProfile] = useState<Profile>({
    degreeLevel: "",
    fieldOfStudy: "",
    nationality: "",
    targetCountries: [],
  });

  const TOTAL_STEPS = 4;
  const progress = ((step + 1) / TOTAL_STEPS) * 100;

  const canNext = () => {
    if (step === 0) return !!profile.degreeLevel;
    if (step === 1) return !!profile.fieldOfStudy;
    if (step === 2) return !!profile.nationality;
    if (step === 3) return profile.targetCountries.length > 0;
    return false;
  };

  const handleNext = () => {
    if (step < TOTAL_STEPS - 1) {
      setStep(step + 1);
    } else {
      // Save to localStorage for now, replace with Supabase later
      localStorage.setItem("flyai_onboarding_profile", JSON.stringify(profile));
      router.push("/auth/login");
    }
  };

  const toggleCountry = (country: string) => {
    setProfile((p) => ({
      ...p,
      targetCountries: p.targetCountries.includes(country)
        ? p.targetCountries.filter((c) => c !== country)
        : [...p.targetCountries, country],
    }));
  };

  return (
    <div className="min-h-screen bg-[#090d16] flex flex-col">
      {/* Ambient orbs */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden">
        <div className="absolute w-96 h-96 bg-indigo-600/15 rounded-full blur-3xl -top-20 -right-20 animate-pulse" />
        <div className="absolute w-64 h-64 bg-violet-600/10 rounded-full blur-3xl bottom-20 -left-10 animate-pulse" />
      </div>

      {/* Header */}
      <div className="relative z-10 flex items-center justify-between px-6 pt-8 pb-4">
        <div className="flex items-center gap-2">
          <Image src="/logo.png" alt="FlyAI" width={32} height={32} className="rounded-lg" />
          <span className="font-bold text-white">FlyAI</span>
        </div>
        <button
          onClick={() => router.push("/auth/login")}
          className="text-xs text-slate-500 hover:text-slate-300 transition-colors"
        >
          Passer →
        </button>
      </div>

      {/* Progress bar */}
      <div className="relative z-10 px-6">
        <div className="h-0.5 bg-white/10 rounded-full overflow-hidden">
          <div
            className="h-full bg-gradient-to-r from-indigo-500 to-violet-500 transition-all duration-500"
            style={{ width: `${progress}%` }}
          />
        </div>
        <div className="flex gap-2 justify-center mt-3">
          {Array.from({ length: TOTAL_STEPS }).map((_, i) => (
            <StepDot key={i} active={i === step} done={i < step} />
          ))}
        </div>
      </div>

      {/* Step content */}
      <div className="relative z-10 flex-1 flex flex-col items-center justify-center px-6 py-8">
        <div className="w-full max-w-lg">

          {/* ── Step 0: Degree level ──────────────────────────────── */}
          {step === 0 && (
            <div className="space-y-6">
              <div className="text-center mb-8">
                <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-indigo-600 to-violet-600 flex items-center justify-center mx-auto mb-4 shadow-xl shadow-indigo-500/25">
                  <GraduationCap className="w-7 h-7 text-white" />
                </div>
                <h1 className="text-2xl font-black text-white mb-2">
                  Quel est ton niveau d&apos;études ?
                </h1>
                <p className="text-slate-400 text-sm">
                  Nous l&apos;utilisons pour filtrer les bourses compatibles.
                </p>
              </div>
              <div className="space-y-3">
                {DEGREE_LEVELS.map((d) => (
                  <button
                    key={d.value}
                    onClick={() => setProfile((p) => ({ ...p, degreeLevel: d.value }))}
                    className={`w-full flex items-center gap-4 px-5 py-4 rounded-2xl border text-left transition-all duration-200 ${
                      profile.degreeLevel === d.value
                        ? "bg-indigo-600/20 border-indigo-500/60 text-white shadow-lg shadow-indigo-500/10"
                        : "bg-white/3 border-white/8 text-slate-300 hover:border-white/15 hover:bg-white/5"
                    }`}
                  >
                    <span className="text-2xl">{d.icon}</span>
                    <span className="font-medium">{d.label}</span>
                    {profile.degreeLevel === d.value && (
                      <Check className="w-4 h-4 text-indigo-400 ml-auto" />
                    )}
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* ── Step 1: Field of study ────────────────────────────── */}
          {step === 1 && (
            <div className="space-y-6">
              <div className="text-center mb-8">
                <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-blue-600 to-indigo-600 flex items-center justify-center mx-auto mb-4 shadow-xl shadow-blue-500/25">
                  <BookOpen className="w-7 h-7 text-white" />
                </div>
                <h1 className="text-2xl font-black text-white mb-2">
                  Ton domaine d&apos;études ?
                </h1>
                <p className="text-slate-400 text-sm">
                  Sélectionne le domaine qui correspond le mieux à ta formation.
                </p>
              </div>
              <div className="flex flex-wrap gap-2 justify-center">
                {FIELDS.map((f) => (
                  <Chip
                    key={f}
                    selected={profile.fieldOfStudy === f}
                    onClick={() => setProfile((p) => ({ ...p, fieldOfStudy: f }))}
                  >
                    {f}
                  </Chip>
                ))}
              </div>
            </div>
          )}

          {/* ── Step 2: Nationality ───────────────────────────────── */}
          {step === 2 && (
            <div className="space-y-6">
              <div className="text-center mb-8">
                <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-violet-600 to-pink-600 flex items-center justify-center mx-auto mb-4 shadow-xl shadow-violet-500/25">
                  <Globe2 className="w-7 h-7 text-white" />
                </div>
                <h1 className="text-2xl font-black text-white mb-2">
                  Quelle est ta nationalité ?
                </h1>
                <p className="text-slate-400 text-sm">
                  Certaines bourses sont réservées à des nationalités spécifiques.
                </p>
              </div>
              <div className="max-h-80 overflow-y-auto pr-1 space-y-2 scrollbar-thin">
                {NATIONALITIES.map((n) => (
                  <button
                    key={n}
                    onClick={() => setProfile((p) => ({ ...p, nationality: n }))}
                    className={`w-full flex items-center gap-3 px-5 py-3.5 rounded-xl border text-left transition-all duration-200 text-sm ${
                      profile.nationality === n
                        ? "bg-indigo-600/20 border-indigo-500/60 text-white"
                        : "bg-white/3 border-white/8 text-slate-300 hover:border-white/15 hover:bg-white/5"
                    }`}
                  >
                    <span className="flex-1">{n}</span>
                    {profile.nationality === n && (
                      <Check className="w-4 h-4 text-indigo-400" />
                    )}
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* ── Step 3: Target countries ──────────────────────────── */}
          {step === 3 && (
            <div className="space-y-6">
              <div className="text-center mb-8">
                <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-emerald-600 to-teal-600 flex items-center justify-center mx-auto mb-4 shadow-xl shadow-emerald-500/25">
                  <MapPin className="w-7 h-7 text-white" />
                </div>
                <h1 className="text-2xl font-black text-white mb-2">
                  Où veux-tu étudier ?
                </h1>
                <p className="text-slate-400 text-sm">
                  Choisis un ou plusieurs pays de destination. ({profile.targetCountries.length} sélectionné
                  {profile.targetCountries.length > 1 ? "s" : ""})
                </p>
              </div>
              <div className="grid grid-cols-2 gap-3">
                {TARGET_COUNTRIES.map(({ flag, name }) => (
                  <button
                    key={name}
                    onClick={() => toggleCountry(name)}
                    className={`flex items-center gap-3 px-4 py-3.5 rounded-xl border text-left transition-all duration-200 text-sm ${
                      profile.targetCountries.includes(name)
                        ? "bg-indigo-600/20 border-indigo-500/60 text-white shadow-sm"
                        : "bg-white/3 border-white/8 text-slate-300 hover:border-white/15 hover:bg-white/5"
                    }`}
                  >
                    <span className="text-xl">{flag}</span>
                    <span className="font-medium">{name}</span>
                    {profile.targetCountries.includes(name) && (
                      <Check className="w-3.5 h-3.5 text-indigo-400 ml-auto shrink-0" />
                    )}
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* ── Navigation buttons ────────────────────────────────── */}
          <div className="flex gap-3 mt-10">
            {step > 0 && (
              <button
                onClick={() => setStep(step - 1)}
                className="flex items-center gap-2 px-5 py-3 rounded-xl border border-white/10 text-slate-300 hover:text-white hover:border-white/20 transition-all text-sm font-medium"
              >
                <ArrowLeft className="w-4 h-4" />
                Retour
              </button>
            )}
            <button
              onClick={handleNext}
              disabled={!canNext()}
              className={`flex-1 flex items-center justify-center gap-2 py-3 rounded-xl font-semibold text-sm transition-all ${
                canNext()
                  ? "bg-gradient-to-r from-indigo-600 to-violet-600 hover:from-indigo-500 hover:to-violet-500 text-white shadow-lg shadow-indigo-500/20 hover:shadow-indigo-500/40"
                  : "bg-white/5 text-slate-600 cursor-not-allowed"
              }`}
            >
              {step === TOTAL_STEPS - 1 ? (
                <>
                  <Check className="w-4 h-4" />
                  Terminer et créer mon compte
                </>
              ) : (
                <>
                  Continuer
                  <ArrowRight className="w-4 h-4" />
                </>
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
