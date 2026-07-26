"use client";

import { useState, useEffect } from "react";
import { X, Lightbulb, ArrowRight } from "lucide-react";

interface GuideStep {
  id: string;
  title: string;
  content: string;
  position?: "top" | "bottom" | "left" | "right";
  targetElement?: string;
}

interface GuidedTourProps {
  steps: GuideStep[];
  currentStep: number;
  onClose: () => void;
  onNext: () => void;
  onPrevious: () => void;
}

// Composant pour un seul guide/tooltip
interface TooltipProps {
  step: GuideStep;
  onClose: () => void;
  onNext?: () => void;
  onPrevious?: () => void;
  hasNext?: boolean;
  hasPrevious?: boolean;
}

function GuideTooltip({ step, onClose, onNext, onPrevious, hasNext, hasPrevious }: TooltipProps) {
  const [visible, setVisible] = useState(true);

  if (!visible) return null;

  // Position par défaut
  const getPositionStyles = () => {
    switch (step.position) {
      case "top":
        return { bottom: "calc(100% + 12px)", left: "50%", transform: "translateX(-50%)" };
      case "bottom":
        return { top: "calc(100% + 12px)", left: "50%", transform: "translateX(-50%)" };
      case "left":
        return { right: "calc(100% + 12px)", top: "50%", transform: "translateY(-50%)" };
      case "right":
        return { left: "calc(100% + 12px)", top: "50%", transform: "translateY(-50%)" };
      default:
        return { top: "calc(100% + 12px)", left: "50%", transform: "translateX(-50%)" };
    }
  };

  return (
    <div
      style={{
        position: "absolute",
        zIndex: 1000,
        background: "var(--warm-50)",
        border: "1px solid var(--border)",
        borderRadius: "var(--radius-xl)",
        padding: "var(--space-4)",
        maxWidth: "320px",
        boxShadow: "var(--shadow-xl)",
        ...getPositionStyles(),
      }}
    >
      <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", marginBottom: "var(--space-2)" }}>
        <div style={{ display: "flex", alignItems: "center", gap: "var(--space-2)" }}>
          <div style={{ width: "24px", height: "24px", borderRadius: "var(--radius-sm)", background: "var(--accent-50)", display: "flex", alignItems: "center", justifyContent: "center", color: "var(--accent)" }}>
            <Lightbulb size={14} />
          </div>
          <h4 style={{ fontWeight: 700, fontSize: "var(--text-body)", color: "var(--ink-text)", margin: 0 }}>{step.title}</h4>
        </div>
        <button
          onClick={onClose}
          style={{ background: "none", border: "none", padding: "4px", cursor: "pointer", color: "var(--ink-muted)", borderRadius: "var(--radius-sm)" }}
          title="Fermer"
        >
          <X size={14} />
        </button>
      </div>
      
      <p style={{ fontSize: "var(--text-caption)", color: "var(--ink-muted)", lineHeight: 1.6, margin: 0 }}>
        {step.content}
      </p>
      
      <div style={{ display: "flex", gap: "var(--space-2)", marginTop: "var(--space-3)", justifyContent: "flex-end" }}>
        {hasPrevious && (
          <button
            onClick={onPrevious}
            style={{ padding: "var(--space-2) var(--space-4)", background: "var(--warm-100)", border: "1px solid var(--border)", borderRadius: "var(--radius)", fontSize: "var(--text-caption)", fontWeight: 600, color: "var(--ink-text)", cursor: "pointer", transition: "all var(--transition-base)" }}
          >
            Précédent
          </button>
        )}
        {hasNext && (
          <button
            onClick={onNext}
            className="btn-primary"
            style={{ padding: "var(--space-2) var(--space-4)", borderRadius: "var(--radius)", fontSize: "var(--text-caption)", fontWeight: 600 }}
          >
            Suivant
            <ArrowRight size={12} />
          </button>
        )}
        {!hasNext && !hasPrevious && (
          <button
            onClick={onClose}
            className="btn-primary"
            style={{ padding: "var(--space-2) var(--space-4)", borderRadius: "var(--radius)", fontSize: "var(--text-caption)", fontWeight: 600 }}
          >
            Compris !
          </button>
        )}
      </div>
    </div>
  );
}

// Overlay pour bloquer les clics en arrière
export function GuidedTourOverlay({ onClose }: { onClose: () => void }) {
  return (
    <div
      style={{
        position: "fixed",
        inset: 0,
        zIndex: 999,
        background: "rgba(0, 0, 0, 0.1)",
        backdropFilter: "blur(2px)",
      }}
      onClick={onClose}
    />
  );
}

// Composant principal du tour guidé
export function GuidedTour({ steps, currentStep, onClose, onNext, onPrevious }: GuidedTourProps) {
  if (currentStep >= steps.length || currentStep < 0) return null;

  const current = steps[currentStep];
  
  return (
    <>
      <GuidedTourOverlay onClose={onClose} />
      <GuideTooltip
        step={current}
        onClose={onClose}
        onNext={onNext}
        onPrevious={onPrevious}
        hasNext={currentStep < steps.length - 1}
        hasPrevious={currentStep > 0}
      />
    </>
  );
}

// Hook pour gérer le tour guidé
export function useGuidedTour(initialSteps: GuideStep[]) {
  const [steps] = useState<GuideStep[]>(initialSteps);
  const [currentStep, setCurrentStep] = useState<number>(0);
  const [isTourActive, setIsTourActive] = useState<boolean>(false);
  const [completedSteps, setCompletedSteps] = useState<Set<string>>(new Set());

  // Vérifier si un guide a déjà été vu
  useEffect(() => {
    const savedCompleted = localStorage.getItem("flyai_completed_guides");
    if (savedCompleted) {
      setCompletedSteps(new Set(JSON.parse(savedCompleted)));
    }
  }, []);

  // Sauvegarder les étapes complétées
  useEffect(() => {
    localStorage.setItem("flyai_completed_guides", JSON.stringify(Array.from(completedSteps)));
  }, [completedSteps]);

  const startTour = (stepIndex: number = 0) => {
    setCurrentStep(stepIndex);
    setIsTourActive(true);
  };

  const closeTour = () => {
    setIsTourActive(false);
    // Marquer l'étape comme complétée
    if (currentStep < steps.length) {
      setCompletedSteps((prev) => new Set(prev).add(steps[currentStep].id));
    }
  };

  const nextStep = () => {
    if (currentStep < steps.length - 1) {
      setCurrentStep((prev) => prev + 1);
    } else {
      closeTour();
    }
  };

  const previousStep = () => {
    if (currentStep > 0) {
      setCurrentStep((prev) => prev - 1);
    }
  };

  // Vérifier si un guide spécifique doit être affiché
  const shouldShowGuide = (guideId: string) => {
    return !completedSteps.has(guideId);
  };

  return {
    steps,
    currentStep,
    isTourActive,
    completedSteps,
    startTour,
    closeTour,
    nextStep,
    previousStep,
    shouldShowGuide,
    setCurrentStep,
  };
}

// Composant simple pour afficher un guide inline (pas de positionnement absolu)
interface InlineGuideProps {
  title: string;
  content: string;
  onDismiss: () => void;
}

export function InlineGuide({ title, content, onDismiss }: InlineGuideProps) {
  return (
    <div
      style={{
        background: "var(--warm-100)",
        border: "1px solid var(--accent)",
        borderRadius: "var(--radius-xl)",
        padding: "var(--space-4)",
        margin: "var(--space-4) 0",
        display: "flex",
        alignItems: "flex-start",
        gap: "var(--space-3)",
      }}
    >
      <div style={{ width: "24px", height: "24px", borderRadius: "var(--radius-sm)", background: "var(--accent-50)", display: "flex", alignItems: "center", justifyContent: "center", color: "var(--accent)", flexShrink: 0 }}>
        <Lightbulb size={14} />
      </div>
      <div style={{ flex: 1 }}>
        <h4 style={{ fontWeight: 700, fontSize: "var(--text-body)", color: "var(--ink-text)", margin: "0 0 var(--space-1)" }}>{title}</h4>
        <p style={{ fontSize: "var(--text-caption)", color: "var(--ink-muted)", lineHeight: 1.6, margin: 0 }}>{content}</p>
      </div>
      <button
        onClick={onDismiss}
        style={{ background: "none", border: "none", padding: "4px", cursor: "pointer", color: "var(--ink-muted)", borderRadius: "var(--radius-sm)", flexShrink: 0 }}
        title="Fermer"
      >
        <X size={14} />
      </button>
    </div>
  );
}
