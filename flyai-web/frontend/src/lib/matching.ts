import { Scholarship, UserProfile, MatchBreakdown } from "@/types";

/**
 * FlyAI — Algorithme de Scoring de Compatibilité v2
 * 
 * Pondération stricte (total = 100 pts) :
 *   - Niveau d'études     : 35 pts  (FILTRE DUR — incompatible = cap à 25% max)
 *   - Domaine d'études    : 25 pts  (score sémantique)
 *   - Pays de destination : 20 pts  (filtre souple)
 *   - Nationalité eligible: 12 pts  (filtre dur souple — pénalité si exclu)
 *   - Type de financement :  8 pts  (score souple)
 *
 * RÈGLES CRITIQUES :
 * 1. Si niveau d'études incompatible → score plafonné à 25% (jamais 100% pour une mauvaise bourse)
 * 2. Si nationalité explicitement exclue → pénalité de -15 pts supplémentaires
 * 3. Aucun minimum artificiel (pas de Math.max(35,...))
 * 4. Utilise targetDegreeLevel (niveau visé) et NON degreeLevel (niveau actuel)
 */
export function calculateMatchScore(
  profile: Partial<UserProfile> | null,
  scholarship: Scholarship,
  overrideDegreeFilter?: string
): MatchBreakdown {
  // ✅ FIX: Utiliser targetDegreeLevel (niveau visé) pour le matching
  // Si l'étudiant vise un master, il cherche des bourses de master
  const targetDegree = (
    overrideDegreeFilter ||
    profile?.targetDegreeLevel ||
    profile?.degreeLevel ||
    "master"
  ).toLowerCase().trim();

  const reasons: string[] = [];

  // ────────────────────────────────────────────────────────────
  // 1. NIVEAU D'ÉTUDES — 35 pts max (FILTRE DUR)
  // ────────────────────────────────────────────────────────────
  let degreeScore = 0;
  let degreeMatch = false;
  const schNiveaux = (scholarship.niveau_etude || []).map((n) => n.toLowerCase());

  if (schNiveaux.length === 0) {
    // Bourse ouverte à tous les niveaux
    degreeScore = 22;
    degreeMatch = true;
    reasons.push("Bourse ouverte à tous les niveaux d'études");
  } else {
    const matchesTarget = schNiveaux.some((n) => {
      if (targetDegree.includes("licence") || targetDegree.includes("bachelor")) {
        return (
          n.includes("licence") ||
          n.includes("bachelor") ||
          n.includes("undergraduate") ||
          n.includes("l1") || n.includes("l2") || n.includes("l3")
        );
      }
      if (
        targetDegree.includes("master") ||
        targetDegree.includes("postgraduate") ||
        targetDegree.includes("ingénieur") ||
        targetDegree.includes("ingenieur")
      ) {
        return (
          n.includes("master") ||
          n.includes("postgraduate") ||
          n.includes("magistère") ||
          n.includes("ingénieur") ||
          n.includes("m1") || n.includes("m2") || n.includes("mba")
        );
      }
      if (targetDegree.includes("doctorat") || targetDegree.includes("phd")) {
        return (
          n.includes("doctorat") ||
          n.includes("phd") ||
          n.includes("recherche") ||
          n.includes("postdoc")
        );
      }
      return n.includes(targetDegree) || targetDegree.includes(n);
    });

    if (matchesTarget) {
      degreeScore = 35;
      degreeMatch = true;
      reasons.push(`Niveau d'études compatible : ${targetDegree.toUpperCase()}`);
    } else {
      // ✅ FIX: Incompatibilité niveau = 0 pts, PAS de score positif
      degreeScore = 0;
      degreeMatch = false;
      const schLevels = scholarship.niveau_etude.join(", ");
      reasons.push(`❌ Niveau incompatible — Bourse pour : ${schLevels} | Vous visez : ${targetDegree.toUpperCase()}`);
    }
  }

  // ────────────────────────────────────────────────────────────
  // 2. DOMAINE D'ÉTUDES — 25 pts max
  // ────────────────────────────────────────────────────────────
  let domainScore = 5;
  let domainMatch = false;
  const userField = (profile?.fieldOfStudy || "").toLowerCase();
  const schDomaines = (scholarship.domaines || []).map((d) => d.toLowerCase());

  if (schDomaines.length === 0) {
    domainScore = 18;
    domainMatch = true;
    reasons.push("Multidisciplinaire — tous domaines acceptés");
  } else if (!userField) {
    domainScore = 10;
    reasons.push("Domaine non renseigné");
  } else {
    const SYNONYMS: Record<string, string[]> = {
      informatique: ["computer", "ai", "tech", "data", "digital", "logiciel", "software", "intelligence artificielle", "cybersécurité", "cybersecurite"],
      droit: ["law", "juridique", "legal", "sciences politiques"],
      gestion: ["business", "management", "économie", "finance", "commerce", "marketing"],
      médecine: ["health", "medical", "santé", "clinical", "pharmacie", "biologie"],
      ingénierie: ["engineering", "mécanique", "électrique", "civil", "chimie", "aeronautique", "btp", "génie"],
      mathématiques: ["math", "statistics", "statistique", "applied sciences"],
      agronomie: ["agriculture", "agri", "agroalimentaire", "environnement"],
      architecture: ["urban", "urbanisme", "design", "art"],
    };

    const isDirectMatch = schDomaines.some((d) => {
      if (d.includes(userField) || userField.includes(d)) return true;
      for (const [key, aliases] of Object.entries(SYNONYMS)) {
        const userMatchesKey = userField.includes(key) || aliases.some((a) => userField.includes(a));
        const domainMatchesKey = d.includes(key) || aliases.some((a) => d.includes(a));
        if (userMatchesKey && domainMatchesKey) return true;
      }
      return false;
    });

    if (isDirectMatch) {
      domainScore = 25;
      domainMatch = true;
      reasons.push(`Spécialité correspondante : ${profile?.fieldOfStudy}`);
    } else {
      domainScore = 10;
      reasons.push("Domaine partiellement compatible");
    }
  }

  // ────────────────────────────────────────────────────────────
  // 3. PAYS DE DESTINATION — 20 pts max
  // ────────────────────────────────────────────────────────────
  let countryScore = 5;
  let countryMatch = false;
  const userCountries = (profile?.targetCountries || []).map((c) => c.toLowerCase().trim());
  const schPays = (scholarship.pays_destination || []).map((p) => p.toLowerCase().trim());

  if (schPays.length === 0) {
    // Destination internationale ouverte
    countryScore = 12;
    countryMatch = true;
    reasons.push("Destination internationale — aucune restriction géographique");
  } else {
    const matchedPays = schPays.find((p) =>
      userCountries.some((uc) => {
        // Normalisation FR/EN (ex: Allemagne/Germany)
        const norm: Record<string, string[]> = {
          "allemagne": ["germany", "allemagne"],
          "royaume-uni": ["united kingdom", "uk", "england", "britain"],
          "états-unis": ["usa", "united states", "etats-unis", "us"],
          "corée du sud": ["south korea", "coree du sud"],
          "afrique du sud": ["south africa"],
        };
        for (const [fr, variants] of Object.entries(norm)) {
          if ((uc.includes(fr) || variants.some((v) => uc.includes(v))) &&
              (p.includes(fr) || variants.some((v) => p.includes(v)))) {
            return true;
          }
        }
        return p.includes(uc) || uc.includes(p);
      })
    );

    if (matchedPays) {
      countryScore = 20;
      countryMatch = true;
      reasons.push(`Destination souhaitée disponible : ${scholarship.pays_destination.join(", ")}`);
    } else {
      countryScore = 5;
      reasons.push(`Destination non souhaitée (vous visez : ${(profile?.targetCountries || []).join(", ")})`);
    }
  }

  // ────────────────────────────────────────────────────────────
  // 4. NATIONALITÉ ÉLIGIBLE — 12 pts max (FILTRE STRICT)
  // ────────────────────────────────────────────────────────────
  let nationalityScore = 6;
  let nationalityMatch = false;
  const userNat = (profile?.nationality || "").toLowerCase().trim();
  const schNats = (scholarship.nationalites_eligibles || []).map((n) => n.toLowerCase().trim());

  if (schNats.length === 0) {
    // Ouvert à tous
    nationalityScore = 12;
    nationalityMatch = true;
    reasons.push("Éligible à toutes les nationalités");
  } else {
    const isOpenToAll = schNats.some((n) =>
      n.includes("tous") || n.includes("all") || n.includes("international") || n.includes("mondiale")
    );

    if (isOpenToAll) {
      nationalityScore = 12;
      nationalityMatch = true;
      reasons.push("Ouvert aux étudiants internationaux");
    } else if (!userNat) {
      nationalityScore = 6;
      reasons.push("Nationalité non renseignée — vérifiez l'éligibilité");
    } else {
      // ✅ FIX: Vérification stricte de la nationalité
      const isEligible = schNats.some((n) => {
        return n.includes(userNat) || userNat.includes(n);
      });

      if (isEligible) {
        nationalityScore = 12;
        nationalityMatch = true;
        reasons.push(`Éligible : nationalité ${profile?.nationality} acceptée`);
      } else {
        // ✅ FIX: Nationalité exclue = pénalité forte (2 pts seulement)
        nationalityScore = 2;
        nationalityMatch = false;
        reasons.push(`⚠️ Nationalité potentiellement non éligible — Vérifiez les critères`);
      }
    }
  }

  // ────────────────────────────────────────────────────────────
  // 5. TYPE DE FINANCEMENT — 8 pts max
  // ────────────────────────────────────────────────────────────
  let fundingScore = 3;
  let fundingMatch = false;

  if (scholarship.financement === "TOTAL") {
    fundingScore = 8;
    fundingMatch = true;
    reasons.push("Financement complet (frais + allocation de vie)");
  } else if (scholarship.financement === "PARTIEL") {
    fundingScore = 5;
    fundingMatch = true;
    reasons.push("Financement partiel");
  } else {
    fundingScore = 3;
    reasons.push("Type de financement non précisé");
  }

  // ────────────────────────────────────────────────────────────
  // CALCUL FINAL
  // ────────────────────────────────────────────────────────────
  const rawTotal = degreeScore + domainScore + countryScore + nationalityScore + fundingScore;

  let overallScore: number;

  if (!degreeMatch && schNiveaux.length > 0) {
    // ✅ FIX: Niveau incompatible → score plafonné à 25 MAX (jamais 100%)
    overallScore = Math.min(25, rawTotal);
  } else if (!nationalityMatch && schNats.length > 0 && !schNats.some(n => n.includes("tous") || n.includes("all") || n.includes("international"))) {
    // Nationalité exclue → plafonné à 50
    overallScore = Math.min(50, rawTotal);
  } else {
    // ✅ FIX: Pas de minimum artificiel Math.max(35, ...)
    overallScore = Math.min(100, rawTotal);
  }

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

function isDeadlineExpired(deadlineStr?: string): boolean {
  if (!deadlineStr) return false;
  try {
    const dStr = deadlineStr.split("T")[0].trim();
    const deadlineDate = new Date(dStr);
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    return deadlineDate < today;
  } catch {
    return false;
  }
}

/**
 * Rank scholarships for a student profile (descending score)
 * Exclut les bourses expirées et les bourses avec niveau incompatible si strict=true
 */
export function rankScholarshipsForProfile(
  profile: Partial<UserProfile> | null,
  scholarships: Scholarship[],
  overrideDegreeFilter?: string,
  strict: boolean = false
): Scholarship[] {
  return scholarships
    .filter((sch) => {
      if (strict && isDeadlineExpired(sch.deadline)) {
        return false;
      }
      return true;
    })
    .map((sch) => {
      const breakdown = calculateMatchScore(profile, sch, overrideDegreeFilter);
      return {
        ...sch,
        matchScore: breakdown.overallScore,
        matchBreakdown: breakdown,
      };
    })
    .filter((sch) => {
      if (strict && !sch.matchBreakdown?.degreeMatch && (sch.niveau_etude?.length ?? 0) > 0) {
        return false;
      }
      return true;
    })
    .sort((a, b) => (b.matchScore || 0) - (a.matchScore || 0));
}

