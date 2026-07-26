"use client";

import { useState, useEffect } from "react";
import { Scholarship } from "@/types";
import ScholarshipDetailModal from "./ScholarshipDetailModal";
import { Search, Filter, Compass, Sparkles, MapPin, Calendar, ExternalLink, RefreshCw, Award, Heart } from "lucide-react";

interface Props {
  userId?: string;
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

      const res = await fetch(`/api/scholarships?${params.toString()}`);
      const json = await res.json();
      if (json.data) {
        setScholarships(json.data);
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
  }, [search, countryFilter, degreeFilter, fundingFilter]);

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
      <div className="bg-slate-900/60 backdrop-blur-xl border border-white/5 p-4 md:p-6 rounded-3xl space-y-4">
        <div className="flex flex-col md:flex-row items-center gap-4">
          <div className="relative flex-1 w-full">
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-400" />
            <input
              type="text"
              placeholder="Rechercher par mot-clé, titre, université (ex: Eiffel, DAAD, Erasmus)..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pl-11 pr-4 py-3 bg-white/5 border border-white/10 rounded-2xl text-sm text-slate-100 placeholder:text-slate-500 focus:outline-none focus:border-indigo-500 transition-all"
            />
          </div>

          <button
            onClick={() => fetchScholarships()}
            className="flex items-center gap-2 px-4 py-3 bg-indigo-600/20 text-indigo-300 border border-indigo-500/30 rounded-2xl text-sm font-semibold hover:bg-indigo-600/30 transition-all"
          >
            <RefreshCw className={`w-4 h-4 ${loading ? "animate-spin" : ""}`} />
            <span>Actualiser</span>
          </button>
        </div>

        {/* Quick Filter Badges */}
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 pt-2 border-t border-white/5">
          <select
            value={degreeFilter}
            onChange={(e) => setDegreeFilter(e.target.value)}
            className="bg-white/5 border border-white/10 text-slate-300 text-xs rounded-xl px-3 py-2.5 outline-none focus:border-indigo-500"
          >
            <option value="" className="bg-slate-900">Tous les Niveaux</option>
            <option value="master" className="bg-slate-900">Master</option>
            <option value="doctorat" className="bg-slate-900">Doctorat / PhD</option>
            <option value="licence" className="bg-slate-900">Licence / Bachelor</option>
          </select>

          <select
            value={countryFilter}
            onChange={(e) => setCountryFilter(e.target.value)}
            className="bg-white/5 border border-white/10 text-slate-300 text-xs rounded-xl px-3 py-2.5 outline-none focus:border-indigo-500"
          >
            <option value="" className="bg-slate-900">Toutes les Destinations</option>
            <option value="France" className="bg-slate-900">France</option>
            <option value="Germany" className="bg-slate-900">Allemagne</option>
            <option value="Canada" className="bg-slate-900">Canada</option>
            <option value="USA" className="bg-slate-900">États-Unis</option>
            <option value="United Kingdom" className="bg-slate-900">Royaume-Uni</option>
          </select>

          <select
            value={fundingFilter}
            onChange={(e) => setFundingFilter(e.target.value)}
            className="bg-white/5 border border-white/10 text-slate-300 text-xs rounded-xl px-3 py-2.5 outline-none focus:border-indigo-500"
          >
            <option value="" className="bg-slate-900">Tous les financements</option>
            <option value="TOTAL" className="bg-slate-900">Entièrement Financé (100%)</option>
            <option value="PARTIEL" className="bg-slate-900">Partiellement Financé</option>
          </select>

          <div className="flex items-center justify-end text-xs text-slate-400 font-medium px-2">
            <span>{scholarships.length} Bourses trouvées</span>
          </div>
        </div>
      </div>

      {/* Grid of Real Scholarships */}
      {loading ? (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {[1, 2, 3, 4, 5, 6].map((n) => (
            <div key={n} className="h-64 rounded-3xl bg-white/5 animate-pulse border border-white/5" />
          ))}
        </div>
      ) : scholarships.length === 0 ? (
        <div className="p-12 text-center bg-slate-900/40 rounded-3xl border border-white/5 space-y-3">
          <Compass className="w-12 h-12 text-slate-500 mx-auto" />
          <h3 className="text-lg font-bold text-white">Aucune bourse ne correspond à ces critères</h3>
          <p className="text-sm text-slate-400">Essaie de réinitialiser tes filtres ou d'élargir ta recherche.</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {scholarships.map((sch) => {
            const score = sch.matchScore || 85;
            return (
              <div
                key={sch.id}
                onClick={() => setSelectedScholarship(sch)}
                className="group relative bg-slate-900/60 hover:bg-slate-800/80 backdrop-blur-xl border border-white/5 hover:border-indigo-500/40 rounded-3xl p-6 transition-all duration-300 flex flex-col justify-between cursor-pointer hover:-translate-y-1 shadow-lg hover:shadow-indigo-500/10"
              >
                <div>
                  {/* Top bar badges */}
                  <div className="flex items-center justify-between mb-4">
                    <span className="px-3 py-1 text-xs font-black rounded-full bg-indigo-500/20 text-indigo-300 border border-indigo-500/30 flex items-center gap-1">
                      <Sparkles className="w-3 h-3 text-indigo-400" /> Match {score}%
                    </span>

                    <button
                      onClick={(e) => handleLike(sch, e)}
                      className="p-2 rounded-xl bg-white/5 hover:bg-rose-500/20 text-slate-400 hover:text-rose-400 transition-all border border-white/5"
                      title="Sauvegarder"
                    >
                      <Heart className="w-4 h-4" />
                    </button>
                  </div>

                  {/* Title */}
                  <h3 className="font-extrabold text-lg text-white group-hover:text-indigo-300 transition-colors line-clamp-2 mb-3">
                    {sch.titre}
                  </h3>

                  {/* Description snippet */}
                  <p className="text-xs text-slate-400 line-clamp-3 leading-relaxed mb-4">
                    {sch.description}
                  </p>
                </div>

                <div className="space-y-4 pt-4 border-t border-white/5">
                  {/* Dest & Deadline */}
                  <div className="flex items-center justify-between text-xs text-slate-400">
                    <div className="flex items-center gap-1.5 truncate max-w-[150px]">
                      <MapPin className="w-3.5 h-3.5 text-indigo-400 shrink-0" />
                      <span className="truncate">{sch.pays_destination?.join(", ") || "International"}</span>
                    </div>

                    <div className="flex items-center gap-1.5 text-amber-400 font-semibold shrink-0">
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
                        className="px-3 py-1.5 rounded-xl bg-indigo-600/20 hover:bg-indigo-600/40 text-indigo-300 border border-indigo-500/30 text-[11px] font-bold flex items-center gap-1.5 transition-all"
                      >
                        <Sparkles className="w-3 h-3 text-amber-300" />
                        <span>FlyAgent</span>
                      </button>
                    )}

                    <span className="text-xs font-bold text-indigo-400 group-hover:translate-x-1 transition-transform flex items-center gap-1 ml-auto">
                      Voir détails &rarr;
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
