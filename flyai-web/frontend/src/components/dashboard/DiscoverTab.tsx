"use client";

import { useState, useEffect } from "react";
import { Scholarship } from "@/types";
import ScholarshipDetailModal from "./ScholarshipDetailModal";
import { Search, Filter, Compass, Sparkles, MapPin, Calendar, ExternalLink, RefreshCw, Award, Heart } from "lucide-react";

interface Props {
  userId?: string;
  userProfile?: any;
  onApplyScholarship?: (scholarship: Scholarship) => void;
  onOpenFlyAgent?: (scholarship: Scholarship) => void;
}

export default function DiscoverTab({ userId, onApplyScholarship, onOpenFlyAgent }: Props) {
  const [scholarships, setScholarships] = useState<Scholarship[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState("");
  const [countryFilter, setCountryFilter] = useState("");
  const [degreeFilter, setDegreeFilter] = useState("");
  const [fundingFilter, setFundingFilter] = useState("");
  const [selectedScholarship, setSelectedScholarship] = useState<Scholarship | null>(null);

  const fetchScholarships = async () => {
    setLoading(true);
    try {
      const params = new URLSearchParams();
      if (search) params.append("search", search);
      if (countryFilter) params.append("country", countryFilter);
      if (degreeFilter) params.append("degree", degreeFilter);
      if (fundingFilter) params.append("funding", fundingFilter);
      if (userId) params.append("user_id", userId);

      const res = await fetch(`/api/scholarships?${params.toString()}`);
      const json = await res.json();
      if (json.data) {
        // Filter out scholarships that don't match user's nationality if profile exists
        let filteredScholarships = json.data;
        if (userProfile?.nationality) {
          const userNat = userProfile.nationality.toLowerCase();
          filteredScholarships = json.data.filter((sch: any) => {
            const eligibleNats = sch.nationalites_eligibles || [];
            // If no specific nationalities required, or if user's nationality is eligible, or if open to all
            if (eligibleNats.length === 0) return true;
            if (eligibleNats.some((nat: string) => nat.toLowerCase().includes(userNat) || userNat.includes(nat.toLowerCase()))) return true;
            if (eligibleNats.some((nat: string) => nat.toLowerCase().includes("all") || nat.toLowerCase().includes("tous") || nat.toLowerCase().includes("international"))) return true;
            return false;
          });
        }
        setScholarships(filteredScholarships);
      }
    } catch (e) {
      console.error("Failed to load scholarships", e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    const timer = setTimeout(() => {
      fetchScholarships();
    }, 300);
    return () => clearTimeout(timer);
  }, [search, countryFilter, degreeFilter, fundingFilter, userId, userProfile]);

  const handleLike = async (sch: Scholarship, e: React.MouseEvent) => {
    e.stopPropagation();
    if (!userId) return;
    try {
      await fetch("/api/swipes", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          userId,
          bourseId: sch.id,
          direction: "right",
          score: sch.matchScore || 85,
          category: "favoris",
        }),
      });
      alert(`Bourse "${sch.titre}" ajoutée à tes favoris / candidatures !`);
    } catch (err) {
      console.error("Error saving swipe:", err);
    }
  };

  return (
    <div className="space-y-6">
      {/* Search and Filters Header Bar */}
      <div className="bg-[rgb(var(--warm-50))] backdrop-blur-xl border border-[rgb(var(--border))] p-4 md:p-6 rounded-3xl space-y-4">
        <div className="flex flex-col md:flex-row items-center gap-4">
          <div className="relative flex-1 w-full">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-[rgb(var(--ink-subtle))]" />
            <input
              type="text"
              placeholder="Rechercher par mot-cle, titre, universite (ex: Eiffel, DAAD, Erasmus)..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-11 pr-4 py-3 bg-[rgb(var(--warm-100))] border border-[rgb(var(--border))] rounded-2xl text-sm text-[rgb(var(--ink-text))] placeholder:text-[rgb(var(--ink-subtle))] focus:outline-none focus:border-accent/50 transition-all"
            />
          </div>

          <button
            onClick={() => fetchScholarships()}
            className="flex items-center gap-2 px-4 py-3 bg-accent/20 text-accent border border-accent/30 rounded-2xl text-sm font-semibold hover:bg-accent/30 transition-all"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? "animate-spin" : ""}`} />
            <span>Actualiser</span>
          </button>
        </div>

        {/* Quick Filter Badges */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 pt-2 border-t border-[rgb(var(--border))]">
          <select
            value={degreeFilter}
            onChange={(e) => setDegreeFilter(e.target.value)}
            className="bg-[rgb(var(--warm-100))] border border-[rgb(var(--border))] text-[rgb(var(--ink-text))] text-xs rounded-xl px-3 py-2.5 outline-none focus:border-accent"
          >
            <option value="">Tous les Niveaux</option>
            <option value="master">Master</option>
            <option value="doctorat">Doctorat / PhD</option>
            <option value="licence">Licence / Bachelor</option>
          </select>

          <select
            value={countryFilter}
            onChange={(e) => setCountryFilter(e.target.value)}
            className="bg-[rgb(var(--warm-100))] border border-[rgb(var(--border))] text-[rgb(var(--ink-text))] text-xs rounded-xl px-3 py-2.5 outline-none focus:border-accent"
          >
            <option value="">Toutes les Destinations</option>
            <option value="France">France</option>
            <option value="Germany">Allemagne</option>
            <option value="Canada">Canada</option>
            <option value="USA">Etats-Unis</option>
            <option value="United Kingdom">Royaume-Uni</option>
          </select>

          <select
            value={fundingFilter}
            onChange={(e) => setFundingFilter(e.target.value)}
            className="bg-[rgb(var(--warm-100))] border border-[rgb(var(--border))] text-[rgb(var(--ink-text))] text-xs rounded-xl px-3 py-2.5 outline-none focus:border-accent"
          >
            <option value="">Tous les financements</option>
            <option value="TOTAL">100% Finance</option>
            <option value="PARTIEL">Partiellement Finance</option>
          </select>

          <div className="flex items-center justify-end text-xs text-[rgb(var(--ink-muted))] font-medium px-2">
            <span>{scholarships.length} Bourses trouvees</span>
          </div>
        </div>
      </div>

      {/* Grid of Real Scholarships */}
      {loading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {[1, 2, 3, 4, 5, 6].map((n) => (
            <div key={n} className="h-64 rounded-3xl bg-[rgb(var(--warm-100))] animate-pulse border border-[rgb(var(--border))]" />
          ))}
        </div>
      ) : scholarships.length === 0 ? (
        <div className="p-12 text-center bg-[rgb(var(--warm-100))] rounded-3xl border border-[rgb(var(--border))] space-y-3">
          <Compass className="w-12 h-12 text-[rgb(var(--ink-muted))] mx-auto" />
          <h3 className="text-lg font-bold text-[rgb(var(--ink-900))]">Aucune bourse ne correspond a ces criteres</h3>
          <p className="text-sm text-[rgb(var(--ink-muted))]">Essaie de reinitialiser tes filtres ou d'elargir ta recherche.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {scholarships.map((sch) => {
            const score = sch.matchScore || 85;
            return (
              <div
                key={sch.id}
                onClick={() => setSelectedScholarship(sch)}
                className="group relative bg-[rgb(var(--warm-50))] hover:bg-[rgb(var(--warm-100))] backdrop-blur-xl border border-[rgb(var(--border))] hover:border-accent/40 rounded-3xl p-6 transition-all duration-300 flex flex-col justify-between cursor-pointer hover:-translate-y-1 shadow-lg hover:shadow-accent/10"
              >
                <div>
                  {/* Top bar badges */}
                  <div className="flex items-center justify-between mb-4">
                    <span className="px-3 py-1 text-xs font-black rounded-full bg-accent/20 text-accent border border-accent/30 flex items-center gap-1">
                      <Sparkles className="w-3 h-3 text-accent" /> Match {score}%
                    </span>

                    <button
                      onClick={(e) => handleLike(sch, e)}
                      className="p-2 rounded-xl bg-[rgb(var(--warm-100))] hover:bg-rose-500/20 text-[rgb(var(--ink-muted))] hover:text-rose-400 transition-all border border-[rgb(var(--border))]"
                      title="Sauvegarder"
                    >
                      <Heart className="w-4 h-4" />
                    </button>
                  </div>

                  {/* Title */}
                  <h3 className="font-extrabold text-lg text-[rgb(var(--ink-900))] group-hover:text-accent transition-colors line-clamp-2 mb-3">
                    {sch.titre}
                  </h3>

                  {/* Description snippet */}
                  <p className="text-xs text-[rgb(var(--ink-muted))] line-clamp-3 leading-relaxed mb-4">
                    {sch.description}
                  </p>
                </div>

                <div className="space-y-4 pt-4 border-t border-[rgb(var(--border))]">
                  {/* Dest & Deadline */}
                  <div className="flex items-center justify-between text-xs text-[rgb(var(--ink-muted))]">
                    <div className="flex items-center gap-1.5 truncate max-w-[150px]">
                      <MapPin className="w-3.5 h-3.5 text-accent shrink-0" />
                      <span className="truncate">{sch.pays_destination?.join(", ") || "International"}</span>
                    </div>

                    <div className="flex items-center gap-1.5 text-warning font-semibold shrink-0">
                      <Calendar className="w-3.5 h-3.5" />
                      <span>{sch.deadline ? new Date(sch.deadline).toLocaleDateString("fr-FR") : "Ouvert"}</span>
                    </div>
                  </div>

                  {/* Action buttons */}
                  <div className="flex items-center justify-between pt-1 gap-2">
                    {onOpenFlyAgent && (
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          onOpenFlyAgent(sch);
                        }}
                        className="px-3 py-1.5 rounded-xl bg-accent/20 hover:bg-accent/40 text-accent border border-accent/30 text-[11px] font-bold flex items-center gap-1.5 transition-all"
                      >
                        <Sparkles className="w-3 h-3 text-amber-300" />
                        <span>FlyAgent</span>
                      </button>
                    )}

                    <span className="text-xs font-bold text-accent group-hover:translate-x-1 transition-transform flex items-center gap-1 ml-auto">
                      Voir details &rarr;
                    </span>
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Detail Modal */}
      {selectedScholarship && (
        <ScholarshipDetailModal
          scholarship={selectedScholarship}
          onClose={() => setSelectedScholarship(null)}
          onApply={onApplyScholarship}
          onOpenFlyAgent={onOpenFlyAgent}
        />
      )}
    </div>
  );
}
