"""
FlyAI Matching API — §4.4 §10.2
Endpoints pour le score de compatibilité, le top des bourses, et le feedback utilisateur.
"""

from __future__ import annotations

import os
from datetime import date, datetime
from typing import Any, Optional
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel
from supabase import create_client

from app.domain.services.matching_service import (
    calculate_compatibility_score,
    store_matching_score,
    get_top_scholarships,
)
from app.domain.services.document_service import (
    generate_checklist,
    generate_cover_letter_draft,
    generate_work_plan,
)

router = APIRouter(prefix="/matching", tags=["matching"])


def _supabase():
    return create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])


# ─────────────────────────────────────────────────────────────
# Schemas Pydantic
# ─────────────────────────────────────────────────────────────

class ScoreRequest(BaseModel):
    user_id: str
    bourse_id: str
    profile: dict[str, Any]


class FeedbackRequest(BaseModel):
    user_id: str
    bourse_id: str
    score_id: Optional[str] = None
    feedback: str  # "up" | "down"


class DossierRequest(BaseModel):
    user_id: str
    bourse_id: str
    profile: dict[str, Any]


# ─────────────────────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────────────────────

@router.post("/score")
async def compute_score(req: ScoreRequest) -> dict[str, Any]:
    """
    Calcule et stocke le score de compatibilité pour une paire utilisateur/bourse.
    §4.4 — Terminologie : "score de compatibilité", jamais "probabilité d'admission".
    """
    supabase = _supabase()

    resp = supabase.table("bourses").select("*").eq("id", req.bourse_id).single().execute()
    if not resp.data:
        raise HTTPException(status_code=404, detail="Bourse not found")

    scholarship = resp.data
    result = calculate_compatibility_score(req.profile, scholarship)
    score_id = store_matching_score(req.user_id, req.bourse_id, result)

    return {
        "score_id": score_id,
        "bourse_id": req.bourse_id,
        "overall_score": result["overall_score"],
        "summary": result["summary"],
        "breakdown": result["breakdown"],
        "label": "Score de compatibilité",
        "disclaimer": "Ce score mesure l'adéquation de votre profil avec les critères de la bourse. Il ne constitue en aucun cas une garantie ou une prédiction d'admission.",
    }


@router.get("/top/{user_id}")
async def get_top_matches(
    user_id: str,
    limit: int = Query(default=7, ge=1, le=20),
    profile_degree: Optional[str] = None,
    profile_field: Optional[str] = None,
    profile_countries: Optional[str] = None,
) -> dict[str, Any]:
    """
    Retourne les meilleures bourses pour ce profil (3–7 par défaut).
    §4.2 : sélection resserrée, jamais une liste infinie.
    """
    supabase = _supabase()

    profile: dict[str, Any] = {}
    try:
        resp = supabase.table("profiles").select("*").eq("id", user_id).single().execute()
        if resp.data:
            profile = resp.data
    except Exception:
        pass

    if profile_degree:
        profile["degree_level"] = profile_degree
    if profile_field:
        profile["field_of_study"] = profile_field
    if profile_countries:
        profile["target_countries"] = [c.strip() for c in profile_countries.split(",")]

    top = get_top_scholarships(user_id, profile, limit=limit)

    return {
        "user_id": user_id,
        "total": len(top),
        "label": "Mes meilleures options",
        "scholarships": top,
    }


@router.post("/feedback")
async def record_feedback(req: FeedbackRequest) -> dict[str, Any]:
    """
    Enregistre le feedback utilisateur §10.2 — alimente la boucle d'amélioration §14.
    """
    if req.feedback not in ("up", "down"):
        raise HTTPException(status_code=422, detail="feedback doit être 'up' ou 'down'")

    supabase = _supabase()
    row = {
        "user_id": req.user_id,
        "bourse_id": req.bourse_id,
        "score_id": req.score_id,
        "feedback": req.feedback,
        "created_at": datetime.utcnow().isoformat(),
    }
    try:
        supabase.table("matching_feedback").insert(row).execute()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur enregistrement feedback : {e}")

    return {"status": "ok", "feedback": req.feedback}


@router.post("/dossier")
async def prepare_dossier(req: DossierRequest) -> dict[str, Any]:
    """
    Génère le dossier pré-rempli : checklist exacte + trame lettre + plan de travail.
    §4.5 — Point d'entrée du bouton "Préparer ce dossier".
    """
    supabase = _supabase()

    resp = supabase.table("bourses").select("*").eq("id", req.bourse_id).single().execute()
    if not resp.data:
        raise HTTPException(status_code=404, detail="Bourse not found")

    scholarship = resp.data
    checklist = generate_checklist(scholarship)
    cover_letter = generate_cover_letter_draft(scholarship, req.profile)

    deadline_str = scholarship.get("deadline")
    days_remaining = 60
    if deadline_str:
        try:
            deadline_date = date.fromisoformat(str(deadline_str))
            days_remaining = max(0, (deadline_date - date.today()).days)
        except (ValueError, TypeError):
            pass

    work_plan = generate_work_plan(scholarship, days_remaining)

    try:
        app_resp = supabase.table("applications").select("id").eq("user_id", req.user_id).eq("bourse_id", req.bourse_id).execute()
        if not app_resp.data:
            supabase.table("applications").insert({
                "user_id": req.user_id,
                "bourse_id": req.bourse_id,
                "status": "draft",
                "checklist": {doc["type"]: False for doc in checklist},
            }).execute()
    except Exception as e:
        print(f"[matching_api] Could not create application: {e}")

    return {
        "bourse_id": req.bourse_id,
        "scholarship_name": scholarship.get("titre") or scholarship.get("title"),
        "days_remaining": days_remaining,
        "deadline": deadline_str,
        "checklist": checklist,
        "cover_letter_draft": cover_letter,
        "work_plan": work_plan,
        "message": f"Il vous reste {days_remaining} jour(s) pour préparer ce dossier.",
    }
