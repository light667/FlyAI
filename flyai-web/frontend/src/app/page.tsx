"use client";

import Image from "next/image";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { onAuthStateChanged } from "firebase/auth";
import { auth } from "@/lib/firebase";

export default function SplashScreen() {
  const router = useRouter();

  // Animation phases: idle → scale+fade in → rings expand → navigate out
  const [visible, setVisible] = useState(false);
  const [ringsVisible, setRingsVisible] = useState(false);
  const [dots, setDots] = useState([false, false, false]);
  const [exiting, setExiting] = useState(false);

  useEffect(() => {
    // Phase 1: fade + scale in (50ms delay so CSS transition triggers)
    const t1 = setTimeout(() => setVisible(true), 50);

    // Phase 2: rings expand
    const t2 = setTimeout(() => setRingsVisible(true), 400);

    // Phase 3: staggered loading dots
    const t3 = setTimeout(() => setDots([true, false, false]), 900);
    const t4 = setTimeout(() => setDots([true, true, false]), 1100);
    const t5 = setTimeout(() => setDots([true, true, true]), 1300);

    // Phase 4: navigate
    const t6 = setTimeout(() => {
      const unsub = onAuthStateChanged(auth, (user) => {
        unsub();
        setExiting(true);
        setTimeout(() => {
          router.replace(user ? "/dashboard" : "/onboarding");
        }, 350);
      });
    }, 2600);

    return () => [t1, t2, t3, t4, t5, t6].forEach(clearTimeout);
  }, [router]);

  return (
    <div
      className={`fixed inset-0 flex items-center justify-center bg-[rgb(var(--ink-900))] transition-opacity duration-350 ${
        exiting ? "opacity-0" : "opacity-100"
      }`}
    >
      {/* Ambient glow — top-left (primary green) */}
      <div className="absolute -top-24 -left-20 w-96 h-96 rounded-full pointer-events-none"
        style={{ background: "radial-gradient(circle, rgba(15,123,108,0.20) 0%, transparent 70%)" }}
      />
      {/* Ambient glow — bottom-right (accent) */}
      <div className="absolute -bottom-24 -right-20 w-80 h-80 rounded-full pointer-events-none"
        style={{ background: "radial-gradient(circle, rgba(15,123,108,0.15) 0%, transparent 70%)" }}
      />

      {/* Center content */}
      <div
        className="flex flex-col items-center"
        style={{
          opacity: visible ? 1 : 0,
          transform: visible ? "scale(1)" : "scale(0.6)",
          transition: "opacity 500ms ease-out, transform 700ms cubic-bezier(0.34,1.56,0.64,1)",
        }}
      >
        {/* Logo with animated rings */}
        <div className="relative flex items-center justify-center mb-9">
          {/* Outer ring */}
          <div
            className="absolute rounded-full border border-accent/25 transition-all duration-700"
            style={{
              width: ringsVisible ? 144 : 90,
              height: ringsVisible ? 144 : 90,
              opacity: ringsVisible ? 1 : 0,
            }}
          />
          {/* Inner glow ring */}
          <div
            className="absolute rounded-full transition-all duration-700"
            style={{
              width: ringsVisible ? 116 : 90,
              height: ringsVisible ? 116 : 90,
              background: ringsVisible
                ? "radial-gradient(circle, rgba(15,123,108,0.20) 0%, transparent 70%)"
                : "transparent",
              opacity: ringsVisible ? 1 : 0,
            }}
          />
          {/* Logo circle */}
          <div className="relative w-[90px] h-[90px] rounded-full overflow-hidden shadow-2xl"
            style={{ boxShadow: "0 0 40px rgba(15,123,108,0.4)" }}
          >
            <Image src="/logo.png" alt="FlyAI" width={90} height={90} className="object-cover" priority />
          </div>
        </div>

        {/* Brand name — white gradient shader */}
        <h1
          className="text-5xl font-black tracking-[6px] uppercase"
          style={{
            background: "linear-gradient(180deg, #ffffff 0%, #e6f4f1 100%)",
            WebkitBackgroundClip: "text",
            WebkitTextFillColor: "transparent",
          }}
        >
          FLY AI
        </h1>

        {/* Tagline */}
        <p
          className="mt-2.5 text-[13px] font-medium tracking-[2.5px] uppercase"
          style={{ color: "rgba(255,255,255,0.70)" }}
        >
          Swipe. Match. Apply. Fly.
        </p>

        {/* Staggered loading dots */}
        <div className="flex gap-2 mt-20">
          {dots.map((active, i) => (
            <div
              key={i}
              className="w-[7px] h-[7px] rounded-full bg-accent transition-all duration-300"
              style={{ opacity: active ? 1 : 0.2, transform: active ? "scale(1)" : "scale(0.6)" }}
            />
          ))}
        </div>
      </div>
    </div>
  );
}
