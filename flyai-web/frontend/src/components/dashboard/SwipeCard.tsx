"use client";

import { useState, useRef, useEffect } from "react";
import { motion, PanInfo, useAnimation } from "framer-motion";
import { Scholarship } from "@/types";
import { Heart, X, Check, ArrowUp, Info } from "lucide-react";

interface SwipeCardProps {
  scholarship: Scholarship;
  onSwipeLeft: (scholarship: Scholarship) => void;
  onSwipeRight: (scholarship: Scholarship) => void;
  onSwipeUp: (scholarship: Scholarship) => void;
  index: number;
}

export default function SwipeCard({ 
  scholarship, 
  onSwipeLeft, 
  onSwipeRight, 
  onSwipeUp,
  index 
}: SwipeCardProps) {
  const [direction, setDirection] = useState<"none" | "left" | "right" | "up">("none");
  const controls = useAnimation();
  const cardRef = useRef<HTMLDivElement>(null);

  const matchScore = scholarship.matchScore || 0;
  const scoreColor = 
    matchScore >= 80 ? "text-accent" :
    matchScore >= 60 ? "text-success" :
    matchScore >= 40 ? "text-warning" :
    "text-alert";

  const handleDragEnd = (event: MouseEvent | TouchEvent | PointerEvent, info: PanInfo) => {
    const threshold = 100;
    const velocityThreshold = 500;
    
    const { offset, velocity } = info;
    
    // Check horizontal swipe
    if (Math.abs(offset.x) > threshold || Math.abs(velocity.x) > velocityThreshold) {
      if (offset.x > 0 || velocity.x > velocityThreshold) {
        // Right swipe - Accept
        setDirection("right");
        controls.start({ 
          x: 500, 
          opacity: 0, 
          rotate: 10,
          transition: { duration: 0.3 }
        });
        setTimeout(() => onSwipeRight(scholarship), 300);
      } else if (offset.x < -threshold || velocity.x < -velocityThreshold) {
        // Left swipe - Reject
        setDirection("left");
        controls.start({ 
          x: -500, 
          opacity: 0, 
          rotate: -10,
          transition: { duration: 0.3 }
        });
        setTimeout(() => onSwipeLeft(scholarship), 300);
      }
    }
    // Check vertical swipe (up)
    else if (offset.y < -threshold || velocity.y < -velocityThreshold) {
      setDirection("up");
      controls.start({ 
        y: -500, 
        opacity: 0,
        transition: { duration: 0.3 }
      });
      setTimeout(() => onSwipeUp(scholarship), 300);
    }
  };

  // Reset animation when scholarship changes
  useEffect(() => {
    controls.start({
      x: 0,
      y: 0,
      rotate: 0,
      opacity: 1,
      transition: { duration: 0.5, type: "spring", damping: 25, stiffness: 300 }
    });
    setDirection("none");
  }, [scholarship, controls]);

  return (
    <motion.div
      ref={cardRef}
      key={scholarship.id}
      animate={controls}
      drag
      dragConstraints={{ left: 0, right: 0, top: 0, bottom: 0 }}
      dragElastic={0.9}
      onDragEnd={handleDragEnd}
      style={{
        position: "absolute",
        top: index * 8,
        left: index * 4,
        right: index * 4,
        zIndex: 100 - index,
        cursor: "grab",
        touchAction: "none",
      }}
      className="w-full rounded-3xl overflow-hidden shadow-2xl"
    >
      {/* Card Content */}
      <div className="relative h-full bg-[rgb(var(--warm-50))] border border-[rgb(var(--border))] backdrop-blur-sm">
        
        {/* Header with score */}
        <div className="absolute top-0 left-0 right-0 z-20 p-6 pt-8">
          <div className="flex items-center justify-between">
            <div className="flex flex-col">
              <span className="text-xs font-bold text-ink-subtle uppercase tracking-wider">
                Compatibilite
              </span>
              <div className="flex items-center gap-2">
                <span className={`text-4xl font-black ${scoreColor}`}>
                  {matchScore}%
                </span>
                <span className="text-xs text-ink-muted">Match</span>
              </div>
            </div>
            <div className="flex items-center gap-2">
              {scholarship.deadline && (
                <span className={`px-3 py-1.5 text-xs font-bold rounded-full ${
                  new Date(scholarship.deadline) > new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
                    ? "bg-success-light text-success"
                    : "bg-alert-light text-alert"
                }`}>
                  {new Date(scholarship.deadline).toLocaleDateString("fr-FR", { 
                    month: "short", 
                    day: "numeric" 
                  })}
                </span>
              )}
            </div>
          </div>
        </div>

        {/* Main Content */}
        <div className="pt-24 pb-6 px-6 h-full flex flex-col">
          
          {/* Title */}
          <h3 className="text-2xl font-black text-ink-900 mb-3 line-clamp-2">
            {scholarship.titre}
          </h3>

          {/* University/Institution */}
          <div className="flex items-center gap-2 mb-4">
            <div className="w-8 h-8 rounded-full bg-accent-50 flex items-center justify-center">
              <span className="text-accent font-bold text-sm">
                {scholarship.source?.charAt(0).toUpperCase() || "U"}
              </span>
            </div>
            <span className="text-sm font-semibold text-ink-muted">
              {scholarship.source || "Institution"}
            </span>
          </div>

          {/* Description */}
          <p className="text-sm text-ink-muted leading-relaxed mb-6 flex-1 line-clamp-4">
            {scholarship.description}
          </p>

          {/* Tags */}
          <div className="flex flex-wrap gap-2 mb-6">
            <span className="px-3 py-1 bg-accent-light text-accent text-xs font-medium rounded-full">
              {scholarship.niveau_etude?.join(", ") || "Tous niveaux"}
            </span>
            {scholarship.pays_destination?.slice(0, 2).map((country) => (
              <span 
                key={country} 
                className="px-3 py-1 bg-warm-100 text-ink-muted text-xs font-medium rounded-full"
              >
                {country}
              </span>
            ))}
          </div>

          {/* Financing Badge */}
          <div className="mt-auto">
            <div className="flex items-center justify-between pt-4 border-t border-[rgb(var(--border-subtle))]">
              <div className="flex items-center gap-2">
                <div className={`w-3 h-3 rounded-full ${
                  scholarship.financement === "TOTAL" 
                    ? "bg-success"
                    : scholarship.financement === "PARTIEL"
                      ? "bg-warning"
                      : "bg-ink-subtle"
                }`} />
                <span className="text-sm font-semibold text-ink-text">
                  {scholarship.financement === "TOTAL" 
                    ? "100% finance"
                    : scholarship.financement === "PARTIEL"
                      ? "Partiellement finance"
                      : "Financement variable"}
                </span>
              </div>
              <Info className="w-5 h-5 text-ink-subtle" />
            </div>
          </div>
        </div>

        {/* Swipe Actions Overlay */}
        <div className="absolute inset-0 pointer-events-none z-10">
          {/* Like overlay (right) */}
          <motion.div 
            className="absolute right-6 top-1/2 -translate-y-1/2 bg-success-light rounded-2xl p-4"
            initial={false}
            animate={{ 
              opacity: direction === "right" ? 1 : 0,
              scale: direction === "right" ? 1.2 : 0.8
            }}
          >
            <Check className="w-8 h-8 text-success" />
          </motion.div>

          {/* Dislike overlay (left) */}
          <motion.div 
            className="absolute left-6 top-1/2 -translate-y-1/2 bg-alert-light rounded-2xl p-4"
            initial={false}
            animate={{ 
              opacity: direction === "left" ? 1 : 0,
              scale: direction === "left" ? 1.2 : 0.8
            }}
          >
            <X className="w-8 h-8 text-alert" />
          </motion.div>

          {/* Favorite overlay (up) */}
          <motion.div 
            className="absolute bottom-20 left-1/2 -translate-x-1/2 bg-info-light rounded-2xl p-4"
            initial={false}
            animate={{ 
              opacity: direction === "up" ? 1 : 0,
              scale: direction === "up" ? 1.2 : 0.8,
              y: direction === "up" ? -20 : 0
            }}
          >
            <Heart className="w-8 h-8 text-info" />
          </motion.div>
        </div>

        {/* Swipe Hints */}
        <div className="absolute bottom-4 left-0 right-0 flex justify-center gap-8 pointer-events-none z-10">
          <div className="flex flex-col items-center gap-1 opacity-60">
            <X className="w-4 h-4 text-alert" />
            <span className="text-[10px] font-medium text-ink-muted">Refuser</span>
          </div>
          <div className="flex flex-col items-center gap-1 opacity-60">
            <ArrowUp className="w-4 h-4 text-info" />
            <span className="text-[10px] font-medium text-ink-muted">Favoris</span>
          </div>
          <div className="flex flex-col items-center gap-1 opacity-60">
            <Check className="w-4 h-4 text-success" />
            <span className="text-[10px] font-medium text-ink-muted">Accepter</span>
          </div>
        </div>
      </div>
    </motion.div>
  );
}
