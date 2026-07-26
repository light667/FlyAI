"use client";

import Image from "next/image";
import Link from "next/link";
import { useState, useEffect } from "react";
import { Sparkles, Mail, Lock, Eye, EyeOff, User, Check, Loader2 } from "lucide-react";
import { auth } from "@/lib/firebase";
import { supabase } from "@/lib/supabase";
import {
  createUserWithEmailAndPassword,
  GoogleAuthProvider,
  signInWithPopup,
  updateProfile,
} from "firebase/auth";
import { useRouter } from "next/navigation";
import { onAuthStateChanged } from "firebase/auth";

export default function SignupPage() {
  const router = useRouter();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [acceptTerms, setAcceptTerms] = useState(false);
  const [showGuide, setShowGuide] = useState(true);
  const [isCheckingAuth, setIsCheckingAuth] = useState(true);
  const [showFirstVisitGuide, setShowFirstVisitGuide] = useState(false);

  // Vérifier si l'utilisateur est déjà connecté
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      if (user) {
        // Vérifier si le profil existe via API (pas de requête directe à Supabase)
        try {
          const res = await fetch(`/api/profile?userId=${user.uid}`);
          const json = await res.json();
          
          if (json.data) {
            // Profil existe, rediriger vers dashboard
            router.replace("/dashboard");
          } else {
            // Pas de profil, rediriger vers onboarding
            router.replace("/onboarding");
          }
        } catch (err) {
          console.error("Error checking profile:", err);
          // Si erreur, on reste sur la page
        } finally {
          setIsCheckingAuth(false);
        }
      } else {
        setIsCheckingAuth(false);
      }
    });

    return () => unsubscribe();
  }, [router]);

  const handleProfileCreation = async (user: any, nameStr: string) => {
    try {
      const localProfileRaw = localStorage.getItem("flyai_onboarding_profile");
      const onboardingCompleted = localStorage.getItem("flyai_onboarding_completed") === "true";
      
      if (localProfileRaw) {
        const localProfile = JSON.parse(localProfileRaw);
        
        // Utiliser l'API /api/profile POST au lieu de requête directe à Supabase
        const response = await fetch("/api/profile", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            userId: user.uid,
            fullName: localProfile.fullName || nameStr || user.displayName || "Scholar",
            email: user.email || localProfile.email || "",
            degreeLevel: localProfile.degreeLevel || "",
            targetDegreeLevel: localProfile.targetDegreeLevel || null,
            fieldOfStudy: localProfile.fieldOfStudy || "",
            university: localProfile.university || "",
            nationality: localProfile.nationality || "",
            targetCountries: localProfile.targetCountries || [],
            gpa: localProfile.gpa || 3.5,
            averageOutOf20: localProfile.averageOutOf20 || 14,
            languages: localProfile.otherLanguages || {},
            needsFullFunding: localProfile.needsFullFunding || false,
            projectSummary: localProfile.projectSummary || "Obtenir une bourse d'études internationale",
            photoUrl: localProfile.photoUrl || "",
            cvUrl: localProfile.cvUrl || "",
            onboardingCompleted: onboardingCompleted,
            termsAccepted: acceptTerms,
          }),
        });

        if (!response.ok) throw new Error("Failed to save profile");
        
        localStorage.removeItem("flyai_onboarding_profile");
        localStorage.removeItem("flyai_onboarding_completed");
      }
    } catch (err) {
      console.error("Error creating profile via API on signup:", err);
    }
  };

  const handleSignup = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!acceptTerms) {
      setError("Vous devez accepter les conditions d'utilisation pour continuer.");
      return;
    }
    
    setLoading(true);
    setError("");
    try {
      const credential = await createUserWithEmailAndPassword(auth, email, password);
      await updateProfile(credential.user, { displayName: name });
      
      // Vérifier si onboarding déjà complété dans localStorage
      const hasOnboarding = localStorage.getItem("flyai_onboarding_profile");
      
      if (hasOnboarding) {
        // Si onboarding déjà fait, créer le profil complet et rediriger vers dashboard
        await handleProfileCreation(credential.user, name);
        router.push("/dashboard");
      } else {
        // Créer un profil temporaire vide pour onboarding
        const tempProfile = {
          fullName: name,
          email: email,
          degreeLevel: "",
          targetDegreeLevel: "",
          fieldOfStudy: "",
          nationality: "",
          targetCountries: [],
        };
        localStorage.setItem("flyai_onboarding_profile", JSON.stringify(tempProfile));
        
        // Marquer comme nouveau utilisateur pour afficher les guides plus tard
        localStorage.setItem("flyai_is_new_user", "true");
        
        // Rediriger vers onboarding pour compléter le profil
        router.push("/onboarding");
      }
    } catch (err: unknown) {
      const firebaseError = err as { message?: string };
      setError(firebaseError.message || "Échec de l'inscription. Réessaie.");
    } finally {
      setLoading(false);
    }
  };

  const handleGoogleSignup = async () => {
    setLoading(true);
    setError("");
    try {
      const provider = new GoogleAuthProvider();
      const credential = await signInWithPopup(auth, provider);
      
      // Vérifier si le profil existe déjà via API
      const res = await fetch(`/api/profile?userId=${credential.user.uid}`);
      const json = await res.json();
      
      if (json.data) {
        // Vérifier si l'onboarding est complété
        const isOnboardingCompleted = json.data.onboardingCompleted || 
          (json.data.fullName && json.data.nationality && json.data.degreeLevel);
        
        if (isOnboardingCompleted) {
          // Profil complet, rediriger vers dashboard
          // Marquer comme nouveau utilisateur pour les guides
          localStorage.setItem("flyai_is_new_user", "true");
          router.push("/dashboard");
        } else {
          // Profil incomplet, rediriger vers onboarding
          // Marquer comme nouveau utilisateur
          localStorage.setItem("flyai_is_new_user", "true");
          router.push("/onboarding");
        }
      } else {
        // Nouveau utilisateur, vérifier si onboarding déjà dans localStorage
        const hasOnboarding = localStorage.getItem("flyai_onboarding_profile");
        
        if (hasOnboarding) {
          // Créer le profil depuis localStorage
          await handleProfileCreation(credential.user, credential.user.displayName || "");
          // Marquer comme nouveau utilisateur
          localStorage.setItem("flyai_is_new_user", "true");
          router.push("/dashboard");
        } else {
          // Nouveau utilisateur, rediriger vers onboarding
          // Marquer comme nouveau utilisateur
          localStorage.setItem("flyai_is_new_user", "true");
          router.push("/onboarding");
        }
      }
    } catch (err: unknown) {
      const firebaseError = err as { message?: string };
      setError(firebaseError.message || "Echec de l'inscription Google.");
    } finally {
      setLoading(false);
    }
  };

  // Guide pour les nouveaux utilisateurs
  const GuideMessage = () => (
    <div style={{
      marginBottom: "var(--space-6)",
      padding: "var(--space-4)",
      background: "var(--warning-light)",
      border: "1px solid var(--warning)",
      borderRadius: "var(--radius-xl)",
      display: "flex",
      alignItems: "flex-start",
      gap: "var(--space-3)",
    }}>
      <div style={{ flexShrink: 0 }}>
        <Sparkles size={20} style={{ color: "var(--warning)" }} />
      </div>
      <div style={{ flex: 1 }}>
        <p style={{ fontSize: "var(--text-body)", color: "var(--warning)", fontWeight: 500, lineHeight: 1.6 }}>
          <strong>Conseil :</strong> Pour une expérience optimale, nous vous recommandons de vous inscrire avec votre 
          <strong>adresse email et mot de passe</strong>. Cela vous permettra de compléter votre profil et de bénéficier 
          de notre système de recommandation de bourses personnalisées.
        </p>
        <p style={{ fontSize: "var(--text-caption)", color: "var(--ink-muted)", marginTop: "var(--space-2)" }}>
          Si vous utilisez Google, vous serez également redirigé vers la page de complétion de profil.
        </p>
      </div>
      <button
        onClick={() => setShowGuide(false)}
        style={{ color: "var(--warning)", fontSize: "var(--text-caption)", fontWeight: 600, background: "none", border: "none", cursor: "pointer", display: "flex", alignItems: "center", gap: "4px" }}
      >
        J'ai compris
      </button>
    </div>
  );

  if (isCheckingAuth) {
    return (
      <div className="min-h-screen bg-[rgb(var(--background))] flex items-center justify-center p-4">
        <div className="flex flex-col items-center gap-4">
          <Loader2 className="w-8 h-8 animate-spin text-accent" />
          <p className="text-sm text-[rgb(var(--ink-muted))]">Verification de l'authentification...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[rgb(var(--background))] flex items-center justify-center p-4 md:p-6 lg:p-8 w-full">
      <div className="w-full max-w-md">
        {/* Header */}
        <div className="flex flex-col items-center mb-8">
          <Image src="/logo.png" alt="FlyAI" width={48} height={48} className="rounded-xl mb-3 shadow-md" />
          <h1 className="text-2xl font-black text-[rgb(var(--ink-900))]">
            Rejoins FlyAI
          </h1>
          <p className="text-[rgb(var(--ink-muted))] text-sm mt-1">
            Cree ton compte et decouvre tes bourses
          </p>
        </div>

        {/* Guide Message */}
        {showGuide && <GuideMessage />}

        {/* Error Message */}
        {error && (
          <div className="mb-4 p-3 rounded-xl bg-alert-light border border-alert text-alert text-sm flex items-center gap-2">
            {error}
          </div>
        )}

        <div className="p-6 md:p-8 w-full bg-[rgb(var(--warm-50))] border border-[rgb(var(--border))] rounded-2xl shadow-md">
          <form onSubmit={handleSignup} className="space-y-4">
            <div>
              <label className="text-xs text-[rgb(var(--ink-muted))] font-medium uppercase tracking-wider mb-2 block">
                Prenom & Nom
              </label>
              <div className="relative">
                <User className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[rgb(var(--ink-subtle))]" />
                <input
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="Aminata Diallo"
                  required
                  className="w-full bg-[rgb(var(--warm-100))] border border-[rgb(var(--border))] rounded-xl pl-10 pr-4 py-3 text-sm text-[rgb(var(--ink-text))] placeholder:text-[rgb(var(--ink-subtle))] focus:outline-none focus:border-accent/50 transition-all"
                />
              </div>
            </div>

            <div>
              <label className="text-xs text-[rgb(var(--ink-muted))] font-medium uppercase tracking-wider mb-2 block">
                Adresse email
              </label>
              <div className="relative">
                <Mail className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[rgb(var(--ink-subtle))]" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="ton@email.com"
                  required
                  className="w-full bg-[rgb(var(--warm-100))] border border-[rgb(var(--border))] rounded-xl pl-10 pr-4 py-3 text-sm text-[rgb(var(--ink-text))] placeholder:text-[rgb(var(--ink-subtle))] focus:outline-none focus:border-accent/50 transition-all"
                />
              </div>
            </div>

            <div>
              <label className="text-xs text-[rgb(var(--ink-muted))] font-medium uppercase tracking-wider mb-2 block">
                Mot de passe
              </label>
              <div className="relative">
                <Lock className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-[rgb(var(--ink-subtle))]" />
                <input
                  type={showPassword ? "text" : "password"}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Minimum 8 caracteres"
                  required
                  minLength={8}
                  className="w-full bg-[rgb(var(--warm-100))] border border-[rgb(var(--border))] rounded-xl pl-10 pr-10 py-3 text-sm text-[rgb(var(--ink-text))] placeholder:text-[rgb(var(--ink-subtle))] focus:outline-none focus:border-accent/50 transition-all"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-[rgb(var(--ink-subtle))] hover:text-[rgb(var(--ink-text))]"
                >
                  {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                </button>
              </div>
            </div>

            {/* Terms and Conditions */}
            <div className="flex items-start gap-2 mt-2">
              <input
                type="checkbox"
                id="acceptTerms"
                checked={acceptTerms}
                onChange={(e) => setAcceptTerms(e.target.checked)}
                required
                className="mt-1 w-4 h-4 rounded border-[rgb(var(--border))] text-accent focus:ring-accent"
              />
              <label htmlFor="acceptTerms" className="text-xs text-[rgb(var(--ink-muted))]">
                J'accepte les {" "}
                <Link href="/terms" className="text-accent hover:underline font-medium">
                  conditions d'utilisation
                </Link>
              </label>
            </div>

            <button
              type="submit"
              disabled={loading || !acceptTerms}
              className="w-full py-3.5 rounded-xl bg-gradient-to-r from-accent to-accent-hover hover:from-accent-hover text-accent-text font-semibold transition-all hover:shadow-lg hover:shadow-accent/25 disabled:opacity-60 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              {loading ? (
                <Loader2 className="w-4 h-4 animate-spin" />
              ) : (
                <>
                  <Sparkles className="w-4 h-4" />
                  Creer mon compte
                </>
              )}
            </button>
          </form>

          <div className="relative my-6">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-[rgb(var(--border))]" />
            </div>
            <div className="relative flex justify-center">
              <span className="bg-[rgb(var(--background))] px-3 text-xs text-[rgb(var(--ink-muted))]">
                ou continuer avec
              </span>
            </div>
          </div>

          <button
            onClick={handleGoogleSignup}
            disabled={loading}
            className="w-full py-3.5 rounded-xl border border-[rgb(var(--border))] hover:border-[rgb(var(--border-subtle))] hover:bg-[rgb(var(--warm-100))] text-[rgb(var(--ink-text))] font-medium transition-all flex items-center justify-center gap-2 text-sm"
          >
            <svg viewBox="0 0 24 24" className="w-4 h-4" fill="currentColor">
              <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4" />
              <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853" />
              <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05" />
              <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335" />
            </svg>
            Continuer avec Google
          </button>

          <p className="text-center text-sm text-[rgb(var(--ink-muted))] mt-6">
            Deja membre ? {" "}
            <Link href="/auth/login" className="text-accent hover:text-accent-hover font-medium">
              Se connecter
            </Link>
          </p>
        </div>
      </div>
    </div>
  );
}
