"""
FlyAI Scholarships API
Endpoint pour récupérer les bourses avec matching et filtrage
"""

from __future__ import annotations

import os
from typing import Any, Optional
from fastapi import APIRouter, HTTPException, Query
from supabase import create_client

router = APIRouter(prefix="/scholarships", tags=["scholarships"])


def _supabase():
    return create_client(os.environ["SUPABASE_URL"], os.environ["SUPABASE_KEY"])


@router.get("/")
async def get_scholarships(
    search: Optional[str] = Query(None, description="Search term for title, description, university"),
    country: Optional[str] = Query(None, description="Filter by destination country"),
    degree: Optional[str] = Query(None, description="Filter by degree level"),
    funding: Optional[str] = Query(None, description="Filter by funding type"),
    user_id: Optional[str] = Query(None, description="User ID for personalized matching"),
    limit: int = Query(50, description="Maximum number of scholarships to return"),
    offset: int = Query(0, description="Pagination offset"),
) -> dict[str, Any]:
    """
    Retrieve scholarships with optional filtering and personalized matching.
    
    If user_id is provided, scholarships are sorted by match score.
    Otherwise, they are returned in default order.
    """
    supabase = _supabase()
    
    # Build the base query
    query = supabase.table("bourses").select("*")
    
    # Apply filters
    if search:
        query = query.or_(f"titre.ilike.%{search}%,description.ilike.%{search}%,universite.ilike.%{search}%")
    
    if country:
        query = query.contains("pays_destination", [country])
    
    if degree:
        query = query.contains("niveau_etude", [degree])
    
    if funding:
        query = query.eq("financement", funding)
    
    # Execute query
    resp = query.order("deadline", desc=False).range(offset, offset + limit - 1).execute()
    
    if not resp.data:
        return {"data": [], "total": 0, "offset": offset, "limit": limit}
    
    scholarships = resp.data
    
    # If user provided, calculate match scores and sort
    if user_id:
        try:
            # Get user profile
            profile_resp = supabase.table("profiles").select("*").eq("id", user_id).single().execute()
            profile = profile_resp.data if profile_resp.data else {}
            
            # Calculate match scores for each scholarship
            from app.domain.services.matching_service import calculate_compatibility_score
            
            for sch in scholarships:
                if profile:
                    result = calculate_compatibility_score(profile, sch)
                    sch["matchScore"] = result["overall_score"]
                    sch["matchBreakdown"] = result["breakdown"]
                else:
                    sch["matchScore"] = 85  # Default score if no profile
            
            # Sort by match score (descending)
            scholarships.sort(key=lambda x: x.get("matchScore", 0), reverse=True)
            
        except Exception as e:
            print(f"Error calculating match scores: {e}")
            # If error, just return unsorted scholarships
            pass
    
    # Get total count for pagination
    count_resp = supabase.table("bourses").select("*", count="exact").execute()
    total = count_resp.count if count_resp.count else len(scholarships)
    
    return {
        "data": scholarships,
        "total": total,
        "offset": offset,
        "limit": limit,
        "has_more": offset + len(scholarships) < total
    }