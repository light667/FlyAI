"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { onAuthStateChanged, signOut } from "firebase/auth";
import { auth } from "@/lib/firebase";
import { supabase } from "@/lib/supabase";
import { User, Bell, ShieldCheck, Info, HelpCircle, LogOut, Check, X, ArrowLeft, User as UserIcon } from "lucide-react";
import Link from "next/link";

export default function SettingsPage() {
  const router = useRouter();
  const [currentUser, setCurrentUser] = useState<any>(null);
  const [profile, setProfile] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [activeSection, setActiveSection] = useState("profile");
  const [acceptTerms, setAcceptTerms] = useState(false);
  const [notificationsEnabled, setNotificationsEnabled] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      if (user) {
        setCurrentUser(user);
        try {
          const { data, error } = await supabase
            .from("profiles")
            .select("*")
            .eq("firebase_uid", user.uid)
            .single();
          
          if (data) {
            setProfile(data);
            setAcceptTerms(data.terms_accepted || false);
          }
        } catch (err) {
          console.error("Error fetching profile:", err);
        } finally {
          setLoading(false);
        }
      } else {
        router.replace("/auth/login");
      }
    });

    return () => unsubscribe();
  }, [router]);

  const handleAcceptTerms = async () => {
    if (!currentUser) return;
    setSaving(true);
    try {
      const { error } = await supabase
        .from("profiles")
        .upsert({
          firebase_uid: currentUser.uid,
          terms_accepted: true,
        }, {
          onConflict: "firebase_uid",
        });
      
      if (!error) {
        setAcceptTerms(true);
        setProfile({ ...profile, terms_accepted: true });
      }
    } catch (err) {
      console.error("Error accepting terms:", err);
    } finally {
      setSaving(false);
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

  const firstName = profile?.fullName?.split(" ")[0] || currentUser?.displayName?.split(" ")[0] || "Etudiant";

  if (loading) {
    return (
      <div className="min-h-screen bg-[rgb(var(--background))] flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <div className="w-12 h-12 rounded-full bg-accent/20 animate-pulse" />
          <p className="text-sm text-[rgb(var(--ink-muted))]">Chargement...</p>
        </div>
      </div>
    );
  }

  const sections = [
    { id: "profile", label: "Profil", icon: UserIcon },
    { id: "notifications", label: "Notifications", icon: Bell },
    { id: "privacy", label: "Confidentialite", icon: ShieldCheck },
    { id: "terms", label: "Conditions d'utilisation", icon: Info },
    { id: "help", label: "Aide", icon: HelpCircle },
  ];

  return (
    <div className="min-h-screen bg-[rgb(var(--background))] text-[rgb(var(--foreground))] flex flex-col">
      {/* Header */}
      <header className="flex items-center gap-4 p-6 border-b border-[rgb(var(--border))]">
        <button
          onClick={() => router.back()}
          className="p-2 rounded-xl bg-[rgb(var(--warm-100))] border border-[rgb(var(--border))] text-[rgb(var(--ink-text))] hover:bg-[rgb(var(--warm-200))] transition-all"
        >
          <ArrowLeft className="w-5 h-5" />
        </button>
        
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-full bg-accent flex items-center justify-center text-accent-text font-bold overflow-hidden">
            {profile?.photoUrl ? (
              <img src={profile.photoUrl} alt={firstName} className="w-full h-full object-cover" />
            ) : (
              firstName[0].toUpperCase()
            )}
          </div>
          <div>
            <h1 className="text-lg font-bold text-[rgb(var(--ink-900))]">Parametres</h1>
            <p className="text-sm text-[rgb(var(--ink-muted))]">{firstName}</p>
          </div>
        </div>
      </header>

      <div className="flex-1 flex flex-col lg:flex-row gap-6 p-6 max-w-6xl mx-auto w-full">
        {/* Sidebar */}
        <div className="lg:w-64 shrink-0">
          <nav className="space-y-1">
            {sections.map((section) => {
              const Icon = section.icon;
              const active = activeSection === section.id;
              return (
                <button
                  key={section.id}
                  onClick={() => setActiveSection(section.id)}
                  className={`w-full flex items-center gap-3 px-4 py-3 rounded-xl text-sm font-semibold transition-all ${
                    active
                      ? "bg-accent text-accent-text"
                      : "text-[rgb(var(--ink-text))] hover:bg-[rgb(var(--warm-100))]"
                  }`}
                >
                  <Icon className={`w-5 h-5 ${active ? "text-accent-text" : "text-[rgb(var(--ink-subtle))]"}`} />
                  <span>{section.label}</span>
                </button>
              );
            })}
          </nav>
        </div>

        {/* Content */}
        <div className="flex-1">
          {activeSection === "profile" && (
            <div className="space-y-6">
              <h3 className="text-lg font-bold text-[rgb(var(--ink-900))]">
                Informations du profil
              </h3>
              
              <div className="bg-[rgb(var(--warm-50))] border border-[rgb(var(--border))] rounded-2xl p-6 space-y-4">
                <div className="flex items-center gap-4">
                  <div className="w-20 h-20 rounded-full bg-accent flex items-center justify-center text-accent-text text-3xl font-bold overflow-hidden">
                    {profile?.photoUrl ? (
                      <img src={profile.photoUrl} alt={firstName} className="w-full h-full object-cover" />
                    ) : (
                      firstName[0].toUpperCase()
                    )}
                  </div>
                  <div>
                    <h4 className="font-bold text-[rgb(var(--ink-900))]">
                      Photo de profil
                    </h4>
                    <p className="text-sm text-[rgb(var(--ink-muted))]">
                      Mettez a jour votre photo de profil dans la section "Mon Profil" du tableau de bord
                    </p>
                  </div>
                </div>
              </div>

              <div className="bg-[rgb(var(--warm-50))] border border-[rgb(var(--border))] rounded-2xl p-6 space-y-4">
                <div className="space-y-3">
                  <div>
                    <label className="text-xs text-[rgb(var(--ink-muted))] font-medium uppercase tracking-wider mb-1 block">
                      Nom complet
                    </label>
                    <p className="text-[rgb(var(--ink-text))] font-medium">{profile?.fullName || "Non specifie"}</p>
                  </div>
                  
                  <div>
                    <label className="text-xs text-[rgb(var(--ink-muted))] font-medium uppercase tracking-wider mb-1 block">
                      Email
                    </label>
                    <p className="text-[rgb(var(--ink-text))] font-medium">{currentUser?.email || "Non specifie"}</p>
                  </div>
                  
                  <div>
                    <label className="text-xs text-[rgb(var(--ink-muted))] font-medium uppercase tracking-wider mb-1 block">
                      Nationalite
                    </label>
                    <p className="text-[rgb(var(--ink-text))] font-medium">{profile?.nationality || "Non specifie"}</p>
                  </div>
                  
                  <div>
                    <label className="text-xs text-[rgb(var(--ink-muted))] font-medium uppercase tracking-wider mb-1 block">
                      Niveau d'etudes
                    </label>
                    <p className="text-[rgb(var(--ink-text))] font-medium">{profile?.degreeLevel || "Non specifie"}</p>
                  </div>
                </div>

                <button
                  onClick={() => router.push("/dashboard?tab=profile")}
                  className="w-full py-3 rounded-xl border border-[rgb(var(--border))] hover:border-accent hover:bg-accent-light text-[rgb(var(--ink-text))] font-medium transition-all flex items-center justify-center gap-2 text-sm"
                >
                  <UserIcon className="w-4 h-4" />
                  Modifier le profil
                </button>
              </div>
            </div>
          )}

          {activeSection === "notifications" && (
            <div className="space-y-6">
              <h3 className="text-lg font-bold text-[rgb(var(--ink-900))]">
                Preferences de notification
              </h3>
              
              <div className="bg-[rgb(var(--warm-50))] border border-[rgb(var(--border))] rounded-2xl p-6 space-y-4">
                <div className="flex items-center justify-between">
                  <div>
                    <h4 className="font-semibold text-[rgb(var(--ink-900))]">
                      Notifications par email
                    </h4>
                    <p className="text-sm text-[rgb(var(--ink-muted))]">
                      Recevez des notifications pour les nouvelles bourses correspondantes
                    </p>
                  </div>
                  <button
                    onClick={() => setNotificationsEnabled(!notificationsEnabled)}
                    className={`p-2 rounded-full ${
                      notificationsEnabled ? "bg-accent text-accent-text" : "bg-[rgb(var(--warm-200))]"
                    }`}
                  >
                    {notificationsEnabled ? <Check className="w-5 h-5" /> : <X className="w-5 h-5" />}
                  </button>
                </div>
              </div>
            </div>
          )}

          {activeSection === "privacy" && (
            <div className="space-y-6">
              <h3 className="text-lg font-bold text-[rgb(var(--ink-900))]">
                Confidentialite et securite
              </h3>
              
              <div className="bg-[rgb(var(--warm-50))] border border-[rgb(var(--border))] rounded-2xl p-6 space-y-4">
                <div className="space-y-3">
                  <div className="flex items-start gap-3">
                    <ShieldCheck className="w-5 h-5 text-accent mt-0.5 flex-shrink-0" />
                    <div>
                      <h4 className="font-semibold text-[rgb(var(--ink-900))]">
                        Protection des donnees
                      </h4>
                      <p className="text-sm text-[rgb(var(--ink-muted))]">
                        Vos donnees personnelles sont securisees et ne sont jamais partagees avec des tiers sans votre consentement.
                      </p>
                    </div>
                  </div>
                  
                  <div className="flex items-start gap-3">
                    <Info className="w-5 h-5 text-accent mt-0.5 flex-shrink-0" />
                    <div>
                      <h4 className="font-semibold text-[rgb(var(--ink-900))]">
                        Utilisation des donnees
                      </h4>
                      <p className="text-sm text-[rgb(var(--ink-muted))]">
                        Vos informations sont utilisees uniquement pour ameliorer votre experience et vous proposer des bourses adaptees.
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {activeSection === "terms" && (
            <div className="space-y-6">
              <h3 className="text-lg font-bold text-[rgb(var(--ink-900))]">
                Conditions d'utilisation
              </h3>
              
              <div className="bg-[rgb(var(--warm-50))] border border-[rgb(var(--border))] rounded-2xl p-6 space-y-4">
                <div className="space-y-4 text-sm text-[rgb(var(--ink-muted))] leading-relaxed">
                  <p>
                    Bienvenue sur FlyAI ! En utilisant notre plateforme, vous acceptez les conditions d'utilisation suivantes :
                  </p>
                  
                  <h4 className="font-bold text-[rgb(var(--ink-900))] text-base">
                    1. Acceptation des conditions
                  </h4>
                  <p>
                    En creant un compte et en utilisant nos services, vous acceptez de respecter ces conditions d'utilisation. Si vous n'etes pas d'accord avec ces conditions, veuillez ne pas utiliser notre plateforme.
                  </p>
                  
                  <h4 className="font-bold text-[rgb(var(--ink-900))] text-base">
                    2. Utilisation de la plateforme
                  </h4>
                  <p>
                    FlyAI est destine a aider les etudiants a trouver des bourses d'etudes adaptes a leur profil. Vous vous engagez a utiliser notre plateforme de maniere legale et conforme a toutes les lois applicables.
                  </p>
                  
                  <h4 className="font-bold text-[rgb(var(--ink-900))] text-base">
                    3. Protection des donnees
                  </h4>
                  <p>
                    Nous nous engageons a proteger vos donnees personnelles. Consultez notre politique de confidentialite pour plus d'informations sur la maniere dont nous collectons, utilisons et protegeons vos informations.
                  </p>
                  
                  <h4 className="font-bold text-[rgb(var(--ink-900))] text-base">
                    4. Propriete intellectuelle
                  </h4>
                  <p>
                    Tout le contenu, les marques, les logos et les materiaux presents sur FlyAI sont la propriete de nos partenaires ou de nous-memes et sont proteges par les lois sur la propriete intellectuelle.
                  </p>
                  
                  <h4 className="font-bold text-[rgb(var(--ink-900))] text-base">
                    5. Modifications
                  </h4>
                  <p>
                    Nous nous reservons le droit de modifier ces conditions d'utilisation a tout moment. Les modifications seront efficaces des leur publication sur la plateforme. Il est de votre responsabilite de consulter regulierement ces conditions.
                  </p>
                </div>

                {!acceptTerms && (
                  <div className="pt-4 border-t border-[rgb(var(--border))]">
                    <div className="flex items-start gap-3">
                      <input
                        type="checkbox"
                        id="accept-terms-settings"
                        checked={acceptTerms}
                        onChange={(e) => setAcceptTerms(e.target.checked)}
                        className="mt-1 w-4 h-4 rounded border-[rgb(var(--border))] text-accent focus:ring-accent"
                      />
                      <label htmlFor="accept-terms-settings" className="text-sm">
                        <span className="font-semibold text-[rgb(var(--ink-900))]">
                          J'accepte les conditions d'utilisation
                        </span>
                        <p className="text-xs text-[rgb(var(--ink-muted))] mt-1">
                          Vous devez accepter les conditions d'utilisation pour continuer a utiliser FlyAI
                        </p>
                      </label>
                    </div>
                    
                    {currentUser && !acceptTerms && (
                      <button
                        onClick={handleAcceptTerms}
                        disabled={saving}
                        className="mt-4 w-full py-3 rounded-xl bg-accent hover:bg-accent-hover text-accent-text font-semibold transition-all disabled:opacity-60"
                      >
                        {saving ? "Enregistrement..." : "Accepter les conditions"}
                      </button>
                    )}
                  </div>
                )}

                {acceptTerms && (
                  <div className="pt-4 border-t border-[rgb(var(--border))] flex items-center gap-2 p-3 bg-accent-light rounded-xl">
                    <Check className="w-5 h-5 text-accent" />
                    <span className="text-sm text-accent font-medium">
                      Conditions d'utilisation acceptees
                    </span>
                  </div>
                )}
              </div>
            </div>
          )}

          {activeSection === "help" && (
            <div className="space-y-6">
              <h3 className="text-lg font-bold text-[rgb(var(--ink-900))]">
                Centre d'aide
              </h3>
              
              <div className="bg-[rgb(var(--warm-50))] border border-[rgb(var(--border))] rounded-2xl p-6 space-y-4">
                <div className="space-y-3">
                  <div className="p-4 bg-[rgb(var(--accent-50))] rounded-xl border border-accent/20">
                    <h4 className="font-bold text-[rgb(var(--ink-900))] mb-2">
                      Besoin d'aide ?
                    </h4>
                    <p className="text-sm text-[rgb(var(--ink-muted))]">
                      Contactez notre equipe de support pour toute question ou preoccupation.
                    </p>
                    <button
                      onClick={() => window.open("mailto:support@flyai.com", "_blank")}
                      className="mt-3 px-4 py-2 bg-accent hover:bg-accent-hover text-accent-text text-sm font-semibold rounded-xl transition-all"
                    >
                      Contactez-nous
                    </button>
                  </div>
                  
                  <div className="space-y-2">
                    <h4 className="font-semibold text-[rgb(var(--ink-900))]">
                      Questions frequentes
                    </h4>
                    <div className="space-y-2">
                      <Link href="/dashboard?tab=flyagent" className="w-full block p-3 text-left bg-[rgb(var(--warm-100))] hover:bg-[rgb(var(--warm-200))] rounded-xl text-sm text-[rgb(var(--ink-text))] transition-all">
                        Comment fonctionne le systeme de matching ?
                      </Link>
                      <Link href="/dashboard?tab=discover" className="w-full block p-3 text-left bg-[rgb(var(--warm-100))] hover:bg-[rgb(var(--warm-200))] rounded-xl text-sm text-[rgb(var(--ink-text))] transition-all">
                        Comment postuler a une bourse ?
                      </Link>
                      <Link href="/dashboard?tab=profile" className="w-full block p-3 text-left bg-[rgb(var(--warm-100))] hover:bg-[rgb(var(--warm-200))] rounded-xl text-sm text-[rgb(var(--ink-text))] transition-all">
                        Puis-je modifier mes informations de profil ?
                      </Link>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Logout Section */}
      <div className="p-6 border-t border-[rgb(var(--border))]">
        <button
          onClick={handleLogout}
          className="w-full py-3.5 rounded-xl border border-alert hover:bg-alert-light/50 text-alert font-semibold transition-all flex items-center justify-center gap-2"
        >
          <LogOut className="w-4 h-4" />
          <span>Se deconnecter</span>
        </button>
      </div>
    </div>
  );
}
