"use client";

import Image from "next/image";
import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { ArrowRight, Rocket } from "lucide-react";

// ─── Slide data — mirrors Flutter _Slide ─────────────────────────────────────
const SLIDES = [
  {
    title: "Find Your\nScholarship",
    subtitle:
      "Discover hundreds of global scholarships matched to your profile and ambitions.",
    // gradient colors (CSS)
    gradientFrom: "#2563EB",
    gradientTo: "#1D4ED8",
    accentFrom: "#60A5FA",
    glowColor: "rgba(37,99,235,0.35)",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" className="w-16 h-16">
        <circle cx="11" cy="11" r="8" />
        <path d="m21 21-4.35-4.35" />
        <path d="M11 8v6M8 11h6" />
      </svg>
    ),
  },
  {
    title: "AI Finds\nYour Match",
    subtitle:
      "Swipe through opportunities. Our AI calculates your compatibility score in real time.",
    gradientFrom: "#7C3AED",
    gradientTo: "#5B21B6",
    accentFrom: "#A78BFA",
    glowColor: "rgba(124,58,237,0.35)",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" className="w-16 h-16">
        <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z" />
      </svg>
    ),
  },
  {
    title: "Apply with\nConfidence",
    subtitle:
      "Get AI-assisted CV reviews, motivation letters, and interview prep — all in one place.",
    gradientFrom: "#0891B2",
    gradientTo: "#0E7490",
    accentFrom: "#22D3EE",
    glowColor: "rgba(8,145,178,0.35)",
    icon: (
      <svg viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth={1.8} strokeLinecap="round" strokeLinejoin="round" className="w-16 h-16">
        <path d="M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2.91-.09z" />
        <path d="m12 15-3-3a22 22 0 0 1 2-3.95A12.88 12.88 0 0 1 22 2c0 2.72-.78 7.5-6 11a22.35 22.35 0 0 1-4 2z" />
        <path d="M9 12H4s.55-3.03 2-4c1.62-1.08 5 0 5 0" />
        <path d="M12 15v5s3.03-.55 4-2c1.08-1.62 0-5 0-5" />
      </svg>
    ),
  },
];

// ─── Animated pill dot ────────────────────────────────────────────────────────
function Dot({ active, color }: { active: boolean; color: string }) {
  return (
    <div
      className="h-[7px] rounded-full transition-all duration-300"
      style={{
        width: active ? 28 : 7,
        backgroundColor: active ? color : "rgba(255,255,255,0.24)",
      }}
    />
  );
}

// ─── Main Onboarding ──────────────────────────────────────────────────────────
export default function OnboardingPage() {
  const router = useRouter();
  const [page, setPage] = useState(0);
  const [fadeIn, setFadeIn] = useState(true);
  const [exiting, setExiting] = useState(false);

  const slide = SLIDES[page];
  const isLast = page === SLIDES.length - 1;

  // Fade content out → switch page → fade in
  const goTo = (next: number) => {
    setFadeIn(false);
    setTimeout(() => {
      setPage(next);
      setFadeIn(true);
    }, 220);
  };

  const handleNext = () => {
    if (!isLast) {
      goTo(page + 1);
    } else {
      setExiting(true);
      setTimeout(() => router.push("/auth/login"), 350);
    }
  };

  // Keyboard navigation
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === "ArrowRight" || e.key === "Enter") handleNext();
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [page]);

  return (
    <div
      className={`fixed inset-0 flex flex-col bg-[#0A0F1C] transition-opacity duration-350 ${
        exiting ? "opacity-0" : "opacity-100"
      }`}
    >
      {/* ── Animated radial gradient background — changes per slide ── */}
      <div
        className="absolute inset-0 pointer-events-none transition-all duration-500"
        style={{
          background: `radial-gradient(ellipse at 30% 20%, ${slide.glowColor} 0%, transparent 60%)`,
        }}
      />
      {/* Bottom glow */}
      <div
        className="absolute bottom-0 left-0 right-0 h-72 pointer-events-none transition-all duration-500"
        style={{
          background: `radial-gradient(ellipse at 50% 100%, ${slide.glowColor.replace("0.35", "0.18")} 0%, transparent 70%)`,
        }}
      />

      {/* ── Header: Logo + Skip ─────────────────────────────────────── */}
      <div className="relative z-10 flex items-center justify-between px-7 pt-10 pb-2">
        <Image src="/logo.png" alt="FlyAI" width={36} height={36} className="rounded-xl" />
        <button
          onClick={() => { setExiting(true); setTimeout(() => router.push("/auth/login"), 350); }}
          className="text-sm font-medium transition-colors"
          style={{ color: "rgba(255,255,255,0.45)" }}
        >
          Skip
        </button>
      </div>

      {/* ── Slide content (fade-animated) ───────────────────────────── */}
      <div className="relative z-10 flex-1 flex flex-col items-center justify-center px-7">
        <div
          className="flex flex-col items-center text-center transition-all duration-220"
          style={{ opacity: fadeIn ? 1 : 0, transform: fadeIn ? "translateY(0)" : "translateY(12px)" }}
        >
          {/* Icon orb */}
          <div
            className="w-32 h-32 rounded-full flex items-center justify-center mb-14 transition-all duration-500"
            style={{
              background: `linear-gradient(135deg, ${slide.gradientFrom}, ${slide.gradientTo})`,
              boxShadow: `0 0 60px ${slide.glowColor}, 0 0 30px ${slide.glowColor}`,
            }}
          >
            {slide.icon}
          </div>

          {/* Title */}
          <h1
            className="text-[38px] font-black text-white leading-[1.1] tracking-[-1px] whitespace-pre-line mb-5"
          >
            {slide.title}
          </h1>

          {/* Subtitle */}
          <p
            className="text-[16px] leading-[1.65] font-normal max-w-xs"
            style={{ color: "rgba(255,255,255,0.60)" }}
          >
            {slide.subtitle}
          </p>
        </div>
      </div>

      {/* ── Bottom controls ─────────────────────────────────────────── */}
      <div className="relative z-10 px-7 pb-12 flex flex-col items-center gap-7">
        {/* Pill dots — animated width like Flutter */}
        <div className="flex items-center gap-2">
          {SLIDES.map((_, i) => (
            <Dot key={i} active={i === page} color={slide.gradientFrom} />
          ))}
        </div>

        {/* CTA button — gradient matches current slide */}
        <button
          onClick={handleNext}
          className="w-full max-w-sm h-14 rounded-[18px] flex items-center justify-center gap-2 font-extrabold text-base tracking-[0.3px] text-white transition-all duration-300 hover:opacity-90 hover:scale-[1.02] active:scale-[0.98]"
          style={{
            background: `linear-gradient(135deg, ${slide.gradientFrom}, ${slide.gradientTo})`,
            boxShadow: `0 8px 24px ${slide.glowColor}`,
          }}
        >
          {isLast ? (
            <>
              Get Started
              <Rocket className="w-[18px] h-[18px]" />
            </>
          ) : (
            <>
              Next
              <ArrowRight className="w-[18px] h-[18px]" />
            </>
          )}
        </button>
      </div>
    </div>
  );
}
