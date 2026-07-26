import { Scholarship, UserProfile, MatchBreakdown } from "@/types";

/**
 * Advanced Multi-Factor Matching Algorithm for FlyAI
 * Calculates compatibility score (0-100%) between a student profile and a scholarship.
 * Strictly prioritizes degree level matches (e.g. Licence vs Master vs Doctorat).
 */
export function calculateMatchScore(
  profile: Partial<UserProfile> | null,
  scholarship: Scholarship,
  overrideDegreeFilter?: string
): MatchBreakdown {
  // Utiliser targetDegreeLevel si disponible, sinon degreeLevel (niveau actuel)
  // Cela permet à un étudiant en licence de viser des bourses master, etc.
  const targetDegree = (overrideDegreeFilter || profile?.targetDegreeLevel || profile?.degreeLevel || "master").toLowerCase();

  const reasons: string[] = [];

  // 1. Strict Degree Level Evaluation (35 pts max)
  let degreeScore = 0;
  let degreeMatch = false;
  const schNiveaux = (scholarship.niveau_etude || []).map((n) => n.toLowerCase());

  if (schNiveaux.length === 0) {
    degreeScore = 20;
    degreeMatch = true;
    reasons.push("Ouvert à tous les niveaux d'études");
  } else {
    // Check degree match with normalization
    const matchesTarget = schNiveaux.some((n) => {
      if (targetDegree.includes("licence") || targetDegree.includes("bachelor")) {
        return n.includes("licence") || n.includes("bachelor") || n.includes("undergraduate") || n.includes("formation");
      }
      if (targetDegree.includes("master") || targetDegree.includes("postgraduate")) {
        return n.includes("master") || n.includes("postgraduate") || n.includes("magistère") || n.includes("ingénieur");
      }
      if (targetDegree.includes("doctorat") || targetDegree.includes("phd")) {
        return n.includes("doctorat") || n.includes("phd") || n.includes("recherche") || n.includes("postdoc");
      }
      return n.includes(targetDegree) || targetDegree.includes(n);
    });

    if (matchesTarget) {
      degreeScore = 35;
      degreeMatch = true;
      reasons.push(`Niveau d'étude exact : ${targetDegree.toUpperCase()}`);
    } else {
      // Mismatched degree levels (e.g. Master scholarship when Licence selected) get 0 pts
      degreeScore = 0;
      degreeMatch = false;
    }
  }

  // 2. Domain / Field of Study Evaluation (25 pts max)
  let domainScore = 5;
  let domainMatch = false;
  const userField = (profile?.fieldOfStudy || "").toLowerCase();
  const schDomaines = (scholarship.domaines || []).map((d) => d.toLowerCase());

  if (schDomaines.length === 0) {
    domainScore = 18;
    domainMatch = true;
    reasons.push("Multidisciplinaire / tous domaines");
  } else {
    const isDirectMatch = schDomaines.some((d) => {
      if (!userField) return false;
      return (
        d.includes(userField) ||
        userField.includes(d) ||
        (userField.includes("informatique") && (d.includes("computer") || d.includes("ai") || d.includes("tech") || d.includes("data"))) ||
        (userField.includes("droit") && d.includes("law")) ||
        (userField.includes("gestion") && (d.includes("business") || d.includes("management") || d.includes("éco")))
      );
    });

    if (isDirectMatch) {
      domainScore = 25;
      domainMatch = true;
      reasons.push(`Spécialité correspondante : ${profile?.fieldOfStudy || "Domaine principal"}`);
    } else {
      domainScore = 12;
      reasons.push("Domaine d'étude proche");
    }
  }

  // 3. Target Destination Countries Evaluation (20 pts max)
  let countryScore = 5;
  let countryMatch = false;
  const userCountries = (profile?.targetCountries || []).map((c) => c.toLowerCase());
  const schPays = (scholarship.pays_destination || []).map((p) => p.toLowerCase());

  if (schPays.length === 0) {
    countryScore = 12;
    countryMatch = true;
  } else {
    const matchedCountry = schPays.find((p) =>
      userCountries.some((uc) => p.includes(uc) || uc.includes(p))
    );

    if (matchedCountry) {
      countryScore = 20;
      countryMatch = true;
      reasons.push(`Destination souhaitée : ${scholarship.pays_destination.join(", ")}`);
    } else {
      countryScore = 8;
    }
  }

  // 4. Funding Type Evaluation (12 pts max)
  let fundingScore = 5;
  let fundingMatch = false;
  if (scholarship.financement === "TOTAL") {
    fundingScore = 12;
    fundingMatch = true;
    reasons.push("Financement à 100% (Frais + Allocation)");
  } else if (scholarship.financement === "PARTIEL") {
    fundingScore = 8;
    fundingMatch = true;
    reasons.push("Prise en charge partielle");
  } else {
    fundingScore = 4;
  }

  // 5. Nationality & Eligibility Evaluation (8 pts max)
  let nationalityScore = 4;
  let nationalityMatch = false;
  const userNat = (profile?.nationality || "international").toLowerCase();
  const schNats = (scholarship.nationalites_eligibles || []).map((n) => n.toLowerCase());

  if (schNats.length === 0 || schNats.some((n) => n.includes("tous") || n.includes("all") || n.includes("international"))) {
    nationalityScore = 8;
    nationalityMatch = true;
    reasons.push("Éligibilité ouverte aux étudiants internationaux");
  } else if (schNats.some((n) => n.includes(userNat) || userNat.includes(n))) {
    nationalityScore = 8;
    nationalityMatch = true;
    reasons.push(`Ouvert à la nationalité : ${profile?.nationality}`);
  } else {
    nationalityScore = 2;
  }

  const rawTotal = degreeScore + domainScore + countryScore + fundingScore + nationalityScore;
  // If degree is explicitly mismatched (0 pts), overall score is capped at 50% max
  const overallScore = degreeMatch || schNiveaux.length === 0
    ? Math.min(100, Math.max(35, rawTotal))
    : Math.min(50, rawTotal);

  return {
    overallScore,
    degreeMatch,
    degreeScore,
    domainMatch,
    domainScore,
    countryMatch,
    countryScore,
    fundingMatch,
    fundingScore,
    nationalityMatch,
    nationalityScore,
    reasons,
  };
}

/**
 * Batch match scholarships against a student profile
 */
export function rankScholarshipsForProfile(
  profile: Partial<UserProfile> | null,
  scholarships: Scholarship[],
  overrideDegreeFilter?: string
): Scholarship[] {
  return scholarships
    .map((sch) => {
      const breakdown = calculateMatchScore(profile, sch, overrideDegreeFilter);
      return {
        ...sch,
        matchScore: breakdown.overallScore,
        matchBreakdown: breakdown,
      };
    })
    .sort((a, b) => (b.matchScore || 0) - (a.matchScore || 0));
}
