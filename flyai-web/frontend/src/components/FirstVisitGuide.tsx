"use client";

import { useState, useEffect } from "react";
import { X, Info, Mail, Lock, UserPlus } from "lucide-react";
import { InlineGuide } from "./GuidedTour";

export interface FirstVisitGuideProps {
  isNewUser?: boolean;
  onDismiss: () => void;
}

// Guide pour les nouveaux utilisateurs sur la page d'inscription
export function RegistrationGuide({ onDismiss }: { onDismiss: () => void }) {
  return (
    <InlineGuide
      title="Première visite ?"
      content="Pour accéder à la page de compléter votre profil et bénéficier des recommandations personnalisées, nous vous recommandons de vous inscrire avec votre email et mot de passe plutôt qu'avec Google."
      onDismiss={onDismiss}
    />
  );
}

// Guide pour les utilisateurs qui se connectent avec Google
export function GoogleConnectGuide({ onDismiss }: { onDismiss: () => void }) {
  return (
    <InlineGuide
      title="Bienvenue ! Complétez votre profil"
      content="Même si vous vous connectez avec Google, vous devez compléter votre profil pour que FlyAgent puisse vous recommander les meilleures bourses adaptées à votre situation."
      onDismiss={onDismiss}
    />
  );
}

// Guide pour les nouveaux utilisateurs sur le dashboard
export function NewUserDashboardGuide({ onDismiss }: { onDismiss: () => void }) {
  return (
    <div
      style={{
        background: "linear-gradient(135deg, var(--accent) 0%, var(--accent-hover) 100%)",
        borderRadius: "var(--radius-xl)",
        padding: "var(--space-6)",
        margin: "var(--space-6) var(--space-4)",
        color: "var(--accent-text)",
        display: "flex",
        alignItems: "flex-start",
        gap: "var(--space-4)",
        boxShadow: "var(--shadow-lg)",
        position: "relative",
      }}
    >
      <div style={{ width: "32px", height: "32px", borderRadius: "var(--radius)", background: "rgba(255, 255, 255, 0.2)", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
        <Info size={18} />
      </div>
      <div style={{ flex: 1 }}>
        <h3 style={{ fontWeight: 700, fontSize: "var(--text-body)", margin: "0 0 var(--space-2)", color: "var(--accent-text)" }}>
          Bienvenue sur FlyAI !
        </h3>
        <ul style={{ fontSize: "var(--text-caption)", lineHeight: 1.8, margin: 0, paddingLeft: "var(--space-4)" }}>
          <li><strong>Étape 1 :</strong> Complétez votre profil dans l'onglet &quot;Mon Profil&quot; pour un matching précis</li>
          <li><strong>Étape 2 :</strong> Découvrez vos &quot;Bourses recommandées&quot; - classées par compatibilité avec votre profil</li>
          <li><strong>Étape 3 :</strong> Utilisez le système de swipe (glisser à droite) pour ajouter des bourses à vos favoris</li>
          <li><strong>Étape 4 :</strong> Consultez l'onglet FlyAgent pour obtenir de l'aide avec vos candidatures</li>
        </ul>
      </div>
      <button
        onClick={onDismiss}
        style={{
          background: "rgba(255, 255, 255, 0.2)",
          border: "none",
          padding: "8px",
          cursor: "pointer",
          color: "var(--accent-text)",
          borderRadius: "var(--radius)",
          flexShrink: 0,
          transition: "all var(--transition-base)"
        }}
        onMouseEnter={(e) => { (e.currentTarget as HTMLButtonElement).style.background = "rgba(255, 255, 255, 0.3)"; }}
        onMouseLeave={(e) => { (e.currentTarget as HTMLButtonElement).style.background = "rgba(255, 255, 255, 0.2)"; }}
        title="Fermer"
      >
        <X size={18} />
      </button>
    </div>
  );
}

// Guide pour l'onglet Bourses recommandées
export function RecommendedTabGuide({ onDismiss }: { onDismiss: () => void }) {
  return (
    <InlineGuide
      title="Comment fonctionne le matching ?"
      content="FlyAgent analyse votre profil (nationalité, domaine d'études, moyenne, langues, etc.) et calcule un score de compatibilité pour chaque bourse. Les bourses sont classées du meilleur au moins bon match. Utilisez le swipe : glisser à droite pour accepter, à gauche pour refuser, vers le haut pour les favoris."
      onDismiss={onDismiss}
    />
  );
}

// Guide pour l'onglet Documents
export function DocumentsTabGuide({ onDismiss }: { onDismiss: () => void }) {
  return (
    <InlineGuide
      title="Ajoutez vos documents"
      content="Téléversez votre CV académique et votre photo de profil. Ces documents sont utilisés par FlyAgent pour évaluer votre éligibilité aux bourses et générer des recommandations personnalisées."
      onDismiss={onDismiss}
    />
  );
}

// Guide pour l'onglet FlyAgent
export function FlyAgentTabGuide({ onDismiss }: { onDismiss: () => void }) {
  return (
    <InlineGuide
      title="Votre assistant IA"
      content="FlyAgent est votre copilote pour les candidatures. Il peut : générer un plan d'action personnalisé, rédiger des brouillons de lettres de motivation, et créer des checklists de documents adaptées à chaque bourse."
      onDismiss={onDismiss}
    />
  );
}

// Hook pour gérer l'affichage des guides pour les nouveaux utilisateurs
export function useNewUserGuides() {
  const [showRegistrationGuide, setShowRegistrationGuide] = useState(false);
  const [showDashboardGuide, setShowDashboardGuide] = useState(false);
  const [showRecommendedGuide, setShowRecommendedGuide] = useState(false);
  const [showDocumentsGuide, setShowDocumentsGuide] = useState(false);
  const [showFlyAgentGuide, setShowFlyAgentGuide] = useState(false);

  // Vérifier si l'utilisateur est nouveau
  useEffect(() => {
    const isNewUser = localStorage.getItem("flyai_is_new_user");
    
    // Afficher les guides si c'est un nouveau utilisateur
    if (isNewUser === "true") {
      setShowDashboardGuide(true);
      setShowRecommendedGuide(true);
      setShowDocumentsGuide(true);
      setShowFlyAgentGuide(true);
    }
  }, []);

  // Marquer comme utilisateur ayant vu les guides
  const markGuidesAsSeen = () => {
    localStorage.setItem("flyai_is_new_user", "false");
  };

  return {
    showRegistrationGuide,
    setShowRegistrationGuide,
    showDashboardGuide,
    setShowDashboardGuide,
    showRecommendedGuide,
    setShowRecommendedGuide,
    showDocumentsGuide,
    setShowDocumentsGuide,
    showFlyAgentGuide,
    setShowFlyAgentGuide,
    markGuidesAsSeen,
  };
}

// Fonction utilitaire pour vérifier si c'est la première visite
export function isFirstVisit(): boolean {
  if (typeof window === "undefined") return false;
  return localStorage.getItem("flyai_is_new_user") === "true";
}

// Fonction utilitaire pour marquer la première visite comme terminée
export function markFirstVisitComplete() {
  if (typeof window !== "undefined") {
    localStorage.setItem("flyai_is_new_user", "false");
  }
}
