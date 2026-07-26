"""
FlyAI Matching Service — §4.4
Score de compatibilité composite : 6 critères pondérés.
Terminologie imposée : "score de compatibilité" / "niveau d'adéquation"
JAMAIS "probabilité d'admission" ni "chances d'être pris".

Pondérations de départ (§4.4 — à recalibrer via matching_feedback) :
  - Niveau d'études          : 25 pts (filtre dur éliminatoire)
  - Domaine d'études         : 20 pts (score sémantique)
  - Pays / zone destination  : 15 pts (filtre souple)
  - Niveau de langue         : 15 pts (filtre dur si écart critique)
  - Financement              : 15 pts (score souple)
  - Cohérence projet         : 10 pts (score sémantique)
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime
from typing import Any, Optional
from supabase import create_client, Client


def _get_supabase() -> Client:
    url = os.environ["SUPABASE_URL"]
    key = os.environ["SUPABASE_KEY"]
    return create_client(url, key)


# ─────────────────────────────────────────────────────────────
# Helpers de normalisation
# ─────────────────────────────────────────────────────────────

def _norm(s: str) -> str:
    return (s or "").strip().lower()


def _match_degree(user_level: str, scholarship_levels: list[str]) -> tuple[int, bool, str]:
    """
    Filtre dur §4.4 — 25 pts max.
    Retourne (score, is_hard_filter_met, reason).
    Si aucun niveau renseigné sur la bourse → ouvert à tous → 20 pts neutres.
    Si incompatible → 0 pts (éliminatoire).
    """
    if not scholarship_levels:
        return 20, True, "Ouvert à tous les niveaux d'études"

    u = _norm(user_level)
    for level in scholarship_levels:
        n = _norm(level)
        if u in ("licence", "bachelor", "undergraduate"):
            if any(k in n for k in ("licence", "bachelor", "undergraduate", "formation")):
                return 25, True, f"Niveau d'études compatible : {user_level.upper()}"
        elif u in ("master", "postgraduate", "magistère", "ingénieur"):
            if any(k in n for k in ("master", "postgraduate", "magistère", "ingénieur")):
                return 25, True, f"Niveau d'études compatible : {user_level.upper()}"
        elif u in ("doctorat", "phd", "postdoc", "recherche"):
            if any(k in n for k in ("doctorat", "phd", "postdoc", "recherche")):
                return 25, True, f"Niveau d'études compatible : {user_level.upper()}"
        elif u in n or n in u:
            return 25, True, f"Niveau d'études compatible : {user_level.upper()}"

    return 0, False, f"Niveau requis non correspondant (vous : {user_level})"


def _match_domain(user_field: str, scholarship_domains: list[str]) -> tuple[int, str]:
    """
    Score sémantique §4.4 — 20 pts max.
    """
    if not scholarship_domains:
        return 15, "Multidisciplinaire — tous domaines acceptés"

    u = _norm(user_field)
    if not u:
        return 8, "Domaine non renseigné — score par défaut appliqué"

    synonyms: dict[str, list[str]] = {
        "informatique": ["computer", "ai", "tech", "data", "digital", "logiciel", "software"],
        "droit": ["law", "juridique", "legal"],
        "gestion": ["business", "management", "économie", "finance", "commerce"],
        "médecine": ["health", "medical", "santé", "clinical"],
        "ingénierie": ["engineering", "mécanique", "électrique", "civil", "chimie"],
    }

    # Correspondance directe
    for d in scholarship_domains:
        dn = _norm(d)
        if u in dn or dn in u:
            return 20, f"Domaine correspondant : {user_field}"
        # Correspondance via synonymes
        for key, aliases in synonyms.items():
            if key in u and any(alias in dn for alias in aliases):
                return 18, f"Domaine proche reconnu : {user_field} ↔ {d}"

    return 10, "Domaine différent — compatibilité partielle"


def _match_country(user_countries: list[str], scholarship_countries: list[str]) -> tuple[int, str]:
    """Filtre souple §4.4 — 15 pts max."""
    if not scholarship_countries:
        return 10, "Destination ouverte — aucune restriction géographique"

    for uc in user_countries:
        for sc in scholarship_countries:
            if _norm(uc) in _norm(sc) or _norm(sc) in _norm(uc):
                return 15, f"Destination souhaitée disponible : {sc}"

    return 6, "Pays de destination non prioritaire pour vous"


def _match_language(user_level: str, required_level: str) -> tuple[int, bool, str]:
    """
    Filtre dur si écart critique §4.4 — 15 pts max.
    Niveaux : A1 < A2 < B1 < B2 < C1 < C2
    """
    order = {"a1": 1, "a2": 2, "b1": 3, "b2": 4, "c1": 5, "c2": 6}

    if not required_level:
        return 12, True, "Aucun niveau de langue exigé"
    if not user_level:
        return 8, True, "Niveau de langue non renseigné — vérifiez les exigences"

    u_score = order.get(_norm(user_level), 0)
    r_score = order.get(_norm(required_level), 0)

    if u_score == 0 or r_score == 0:
        return 10, True, f"Niveau de langue à vérifier : {required_level} requis"

    gap = r_score - u_score
    if gap > 1:
        return 0, False, f"Niveau de langue insuffisant — {required_level} requis, vous avez {user_level}"
    elif gap == 1:
        return 10, True, f"Niveau de langue légèrement en dessous — {required_level} requis"
    else:
        return 15, True, f"Niveau de langue satisfait : {user_level} ≥ {required_level}"


def _match_funding(user_needs_full: bool, funding_type: str) -> tuple[int, str]:
    """Score souple §4.4 — 15 pts max."""
    ft = _norm(funding_type)
    if ft in ("total", "complète", "full"):
        return 15, "Financement complet — frais de scolarité et allocation inclus"
    elif ft in ("partiel", "partial"):
        score = 8 if user_needs_full else 12
        return score, "Financement partiel"
    return 6, "Type de financement non précisé"


# ─────────────────────────────────────────────────────────────
# Fonction principale
# ─────────────────────────────────────────────────────────────

def calculate_compatibility_score(
    profile: dict[str, Any],
    scholarship: dict[str, Any],
) -> dict[str, Any]:
    """
    Calcule le score de compatibilité (0–100) entre un profil et une bourse.
    Retourne un dict avec le score total et la décomposition ligne par ligne.

    Terminologie §4.4 : JAMAIS "probabilité d'admission".
    """
    degree_score, degree_ok, degree_reason = _match_degree(
        profile.get("degree_level", ""),
        scholarship.get("niveau_etude", []) or scholarship.get("degree_level", []),
    )

    domain_score, domain_reason = _match_domain(
        profile.get("field_of_study", "") or profile.get("fieldOfStudy", ""),
        scholarship.get("domaines", []),
    )

    country_score, country_reason = _match_country(
        profile.get("target_countries", []) or profile.get("targetCountries", []),
        scholarship.get("pays_destination", []) or scholarship.get("country", []),
    )

    lang_score, lang_ok, lang_reason = _match_language(
        profile.get("language_level", "") or profile.get("languageLevel", ""),
        scholarship.get("niveau_langue", "") or scholarship.get("language_required", ""),
    )

    funding_score, funding_reason = _match_funding(
        profile.get("needs_full_funding", False),
        scholarship.get("financement", "") or scholarship.get("funding_type", ""),
    )

    # Filtre dur : si niveau d'études incompatible, score plafonné à 40
    raw = degree_score + domain_score + country_score + lang_score + funding_score
    if not degree_ok:
        overall = min(40, raw)
        summary = "Niveau d'études non compatible avec cette bourse"
    elif not lang_ok:
        overall = min(50, raw)
        summary = "Niveau de langue insuffisant pour cette bourse"
    else:
        overall = min(100, max(30, raw))
        summary = "Dossier potentiellement compatible"

    breakdown = [
        {"criterion": "Niveau d'études", "weight": 25, "score": degree_score, "max": 25, "detail": degree_reason, "is_hard_filter": True},
        {"criterion": "Domaine d'études", "weight": 20, "score": domain_score, "max": 20, "detail": domain_reason, "is_hard_filter": False},
        {"criterion": "Pays de destination", "weight": 15, "score": country_score, "max": 15, "detail": country_reason, "is_hard_filter": False},
        {"criterion": "Niveau de langue", "weight": 15, "score": lang_score, "max": 15, "detail": lang_reason, "is_hard_filter": True},
        {"criterion": "Type de financement", "weight": 15, "score": funding_score, "max": 15, "detail": funding_reason, "is_hard_filter": False},
        {"criterion": "Cohérence du projet", "weight": 10, "score": 10, "max": 10, "detail": "Score de base (affinement via RAG en Phase B)", "is_hard_filter": False},
    ]

    return {
        "overall_score": overall,
        "summary": summary,
        "breakdown": breakdown,
        "degree_ok": degree_ok,
        "lang_ok": lang_ok,
    }


def store_matching_score(
    user_id: str,
    scholarship_id: str,
    result: dict[str, Any],
) -> Optional[str]:
    """
    Persiste le score calculé dans matching_scores (Supabase).
    Retourne l'ID du score inséré ou None en cas d'erreur.
    """
    try:
        supabase = _get_supabase()
        row = {
            "user_id": user_id,
            "scholarship_id": scholarship_id,
            "overall_score": result["overall_score"],
            "degree_score": next((b["score"] for b in result["breakdown"] if b["criterion"] == "Niveau d'études"), 0),
            "domain_score": next((b["score"] for b in result["breakdown"] if b["criterion"] == "Domaine d'études"), 0),
            "country_score": next((b["score"] for b in result["breakdown"] if b["criterion"] == "Pays de destination"), 0),
            "language_score": next((b["score"] for b in result["breakdown"] if b["criterion"] == "Niveau de langue"), 0),
            "funding_score": next((b["score"] for b in result["breakdown"] if b["criterion"] == "Type de financement"), 0),
            "semantic_score": next((b["score"] for b in result["breakdown"] if b["criterion"] == "Cohérence du projet"), 0),
            "breakdown": result["breakdown"],
            "computed_at": datetime.utcnow().isoformat(),
        }
        resp = supabase.table("matching_scores").insert(row).execute()
        return resp.data[0]["id"] if resp.data else None
    except Exception as e:
        print(f"[matching_service] Failed to store score: {e}")
        return None


def get_top_scholarships(
    user_id: str,
    profile: dict[str, Any],
    limit: int = 7,
) -> list[dict[str, Any]]:
    """
    Retourne les `limit` meilleures bourses pour ce profil.
    Calcule et stocke les scores en BDD.
    """
    supabase = _get_supabase()

    # Récupérer toutes les bourses actives
    resp = supabase.table("bourses").select("*").eq("active", True).execute()
    scholarships = resp.data or []

    scored = []
    for sch in scholarships:
        result = calculate_compatibility_score(profile, sch)
        score_id = store_matching_score(user_id, sch.get("id", ""), result)
        scored.append({
            **sch,
            "compatibility_score": result["overall_score"],
            "compatibility_summary": result["summary"],
            "compatibility_breakdown": result["breakdown"],
            "score_id": score_id,
        })

    # Trier par score décroissant et retourner les N premières
    scored.sort(key=lambda x: x["compatibility_score"], reverse=True)
    return scored[:limit]
