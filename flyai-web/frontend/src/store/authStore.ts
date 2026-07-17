import { create } from "zustand";
import { UserProfile } from "../types";

interface AuthState {
  user: { uid: string; email: string; displayName?: string } | null;
  profile: UserProfile | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  setSession: (
    user: AuthState["user"],
    profile: UserProfile | null
  ) => void;
  clearSession: () => void;
  setProfile: (profile: UserProfile) => void;
  setLoading: (isLoading: boolean) => void;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  profile: null,
  isAuthenticated: false,
  isLoading: true,
  setSession: (user, profile) =>
    set({
      user,
      profile,
      isAuthenticated: !!user,
      isLoading: false,
    }),
  clearSession: () =>
    set({
      user: null,
      profile: null,
      isAuthenticated: false,
      isLoading: false,
    }),
  setProfile: (profile) => set({ profile }),
  setLoading: (isLoading) => set({ isLoading }),
}));
