"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { onAuthStateChanged, User } from "firebase/auth";
import { auth } from "@/lib/firebase";

export interface ProfileCheckResult {
  user: User | null;
  profileExists: boolean;
  profile: any | null;
  loading: boolean;
  isNewUser: boolean;
}

export function useProfileCheck(): ProfileCheckResult {
  const router = useRouter();
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<any | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (user) => {
      if (user) {
        setUser(user);
        try {
          // Vérifier si le profil existe dans Supabase
          const response = await fetch(`/api/profile?userId=${user.uid}`);
          const data = await response.json();
          
          if (data.data && data.data.firebase_uid) {
            setProfile(data.data);
            // Vérifier si l'onboarding est complété
            const isOnboardingCompleted = data.data.onboarding_completed || 
              (data.data.fullName && data.data.nationality && data.data.degreeLevel);
            
            // Si l'onboarding n'est pas complété, on pourrait rediriger
            // Mais on laisse la décision à la page appelante
          } else {
            // Profil n'existe pas
            setProfile(null);
          }
        } catch (error) {
          console.error("Error checking profile:", error);
          setProfile(null);
        } finally {
          setLoading(false);
        }
      } else {
        setUser(null);
        setProfile(null);
        setLoading(false);
      }
    });

    return () => unsub();
  }, [router]);

  // Un utilisateur est considéré comme nouveau s'il a un user mais pas de profil
  const isNewUser = !!user && !profile;
  const profileExists = !!profile;

  return {
    user,
    profile,
    profileExists,
    loading,
    isNewUser,
  };
}
