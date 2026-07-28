"use client";

import Image from "next/image";
import Link from "next/link";
import { useState, useEffect } from "react";
import { Sparkles, Mail, Lock, Eye, EyeOff, Loader2 } from "lucide-react";
import { auth } from "@/lib/firebase";
import { supabase } from "@/lib/supabase";
import {
  signInWithEmailAndPassword,
  GoogleAuthProvider,
  signInWithPopup,
} from "firebase/auth";
import { useRouter } from "next/navigation";
import { onAuthStateChanged } from "firebase/auth";

// Inline Google logo (no lucide equivalent)
function GoogleIcon() {
  return (
    <svg viewBox="0 0 24 24" className="w-4 h-4" fill="currentColor">
      <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
      <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
      <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
      <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
    </svg>
  );
}

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [isCheckingAuth, setIsCheckingAuth] = useState(true);

  // Vérifier si l'utilisateur est déjà connecté
  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      if (user) {
        // Pour le login, toujours rediriger vers dashboard
        // L'onboarding ne doit s'afficher que lors du premier signup
        router.replace("/dashboard");
      } else {
        setIsCheckingAuth(false);
      }
    });

    return () => unsubscribe();
  }, [router]);

  const handleEmailLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      const userCredential = await signInWithEmailAndPassword(auth, email, password);
      
      // Vérifier si le profil existe via API (pas de requête directe à Supabase)
      const res = await fetch(`/api/profile?userId=${userCredential.user.uid}`);
      const json = await res.json();
      
      if (json.data) {
        // Vérifier si l'onboarding est complété
        const isOnboardingCompleted = json.data.onboardingCompleted || 
          (json.data.fullName && json.data.nationality && json.data.degreeLevel);
        
        // Marquer comme nouveau utilisateur pour les guides du dashboard
        localStorage.setItem("flyai_is_new_user", "true");
        
        if (isOnboardingCompleted) {
          router.push("/dashboard");
        } else {
          router.push("/onboarding");
        }
      } else {
        // Nouveau utilisateur, rediriger vers onboarding
        // Marquer comme nouveau utilisateur
        localStorage.setItem("flyai_is_new_user", "true");
        router.push("/onboarding");
      }
    } catch (err: unknown) {
      const firebaseError = err as { message?: string };
      setError(firebaseError.message || "Échec de la connexion. Vérifiez vos identifiants.");
    } finally {
      setLoading(false);
    }
  };

  const handleGoogleLogin = async () => {
    setLoading(true);
    setError("");
    try {
      const provider = new GoogleAuthProvider();
      const userCredential = await signInWithPopup(auth, provider);
      
      // Vérifier si le profil existe via API (pas de requête directe à Supabase)
      const res = await fetch(`/api/profile?userId=${userCredential.user.uid}`);
      const json = await res.json();
      
      if (json.data) {
        // Vérifier si l'onboarding est complété
        const isOnboardingCompleted = json.data.onboardingCompleted || 
          (json.data.fullName && json.data.nationality && json.data.degreeLevel);
        
        // Marquer comme nouveau utilisateur pour les guides du dashboard
        localStorage.setItem("flyai_is_new_user", "true");
        
        if (isOnboardingCompleted) {
          router.push("/dashboard");
        } else {
          router.push("/onboarding");
        }
      } else {
        // Nouveau utilisateur, rediriger vers onboarding
        // Marquer comme nouveau utilisateur
        localStorage.setItem("flyai_is_new_user", "true");
        router.push("/onboarding");
      }
    } catch (err: unknown) {
      const firebaseError = err as { message?: string };
      setError(firebaseError.message || "Échec de la connexion Google.");
    } finally {
      setLoading(false);
    }
  };

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
            Bon retour sur FlyAI
          </h1>
          <p className="text-[rgb(var(--ink-muted))] text-sm mt-1">
            Connecte-toi pour continuer ta progression
          </p>
        </div>

        {/* Card */}
        <div className="p-6 md:p-8 w-full bg-[rgb(var(--warm-50))] border border-[rgb(var(--border))] rounded-2xl shadow-md">
          {error && (
            <div className="mb-4 p-3 rounded-xl bg-alert-light border border-alert text-alert text-sm">
              {error}
            </div>
          )}

          <form onSubmit={handleEmailLogin} className="space-y-4">
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
                  placeholder="••••••••"
                  required
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

            <div className="flex justify-end">
              <a href="#" className="text-xs text-accent hover:text-accent-hover transition-colors">
                Mot de passe oublie ?
              </a>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full py-3.5 rounded-xl bg-gradient-to-r from-accent to-accent-hover hover:from-accent-hover text-accent-text font-semibold transition-all hover:shadow-lg hover:shadow-accent/25 disabled:opacity-60 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              {loading ? (
                <Loader2 className="w-4 h-4 animate-spin" />
              ) : (
                <>
                  <Sparkles className="w-4 h-4" />
                  Se connecter
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
            onClick={handleGoogleLogin}
            disabled={loading}
            className="w-full py-3.5 rounded-xl border border-[rgb(var(--border))] hover:border-[rgb(var(--border-subtle))] hover:bg-[rgb(var(--warm-100))] text-[rgb(var(--ink-text))] font-medium transition-all flex items-center justify-center gap-2 text-sm"
          >
            <GoogleIcon />
            Continuer avec Google
          </button>
        </div>

        <p className="text-center text-sm text-[rgb(var(--ink-muted))] mt-6">
          Pas encore de compte ? {" "}
          <Link href="/auth/signup" className="text-accent hover:text-accent-hover font-medium">
            S&apos;inscrire gratuitement
          </Link>
        </p>
      </div>
    </div>
  );
}
