from __future__ import annotations
import hashlib, re
from datetime import date, datetime
from typing import Any, Optional
from pydantic import BaseModel, Field, field_validator

FUNDING_MAP = {
    "total": "Fully Funded", "fully funded": "Fully Funded", "full": "Fully Funded",
    "partiel": "Partial", "partial": "Partial",
    "inconnu": "Unknown", "unknown": "Unknown", "varies": "Unknown",
}

DEGREE_MAP = {
    "licence": "Bachelor's Degree", "bachelor": "Bachelor's Degree",
    "undergraduate": "Bachelor's Degree", "master": "Master's Degree",
    "msc": "Master's Degree", "doctorat": "PhD / Doctorate",
    "doctorate": "PhD / Doctorate", "phd": "PhD / Doctorate",
    "postdoc": "Post-Doctorate", "recherche": "Research", "research": "Research",
    "formation": "Short Course / Training", "training": "Short Course / Training",
}


class ScholarshipModel(BaseModel):
    id: Optional[str] = None
    source_id: Optional[str] = None
    slug: Optional[str] = None
    title: str
    provider: Optional[str] = None
    university: Optional[str] = None
    country: str = "Unknown"
    description: Optional[str] = None
    funding_type: str = "Unknown"
    degree_level: str = "All Levels"
    fields: list = Field(default_factory=list)
    eligibility: dict = Field(default_factory=dict)
    requirements: list = Field(default_factory=list)
    language_requirements: dict = Field(default_factory=dict)
    benefits: list = Field(default_factory=list)
    deadline: Optional[date] = None
    deadline_raw: Optional[str] = None
    publication_date: Optional[datetime] = None
    status: str = "unknown"
    application_url: Optional[str] = None
    source_url: Optional[str] = None
    image_url: Optional[str] = None
    source: Optional[str] = None
    active: bool = True
    quality_score: int = 0
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None
    fingerprint: Optional[str] = None

    @field_validator("title")
    @classmethod
    def clean_title(cls, v: str) -> str:
        return " ".join(v.strip().split())

    def compute_status(self) -> str:
        if not self.deadline:
            return "unknown"
        delta = (self.deadline - date.today()).days
        if delta < 0: return "closed"
        if delta <= 7: return "closing_soon"
        if delta <= 30: return "open"
        return "upcoming"

    def compute_fingerprint(self) -> str:
        def norm(s):
            if not s: return ""
            s = re.sub(r"[^\w\s]", " ", str(s).lower())
            s = re.sub(r"\b20\d{2}\b", "", s)
            return re.sub(r"\s+", " ", s).strip()
        parts = "|".join([norm(self.title), norm(self.university), norm(self.country)])
        return hashlib.md5(parts.encode()).hexdigest()

    def refresh(self) -> None:
        self.status = self.compute_status()
        self.fingerprint = self.compute_fingerprint()

    def to_supabase_dict(self) -> dict:
        now = datetime.utcnow().isoformat()
        return {
            "title": self.title,
            "provider": self.provider,
            "university": self.university,
            "country": self.country,
            "description": self.description,
            "funding_type": self.funding_type,
            "degree_level": self.degree_level,
            "fields": self.fields,
            "eligibility": self.eligibility,
            "requirements": self.requirements,
            "language_requirements": self.language_requirements,
            "deadline": self.deadline.isoformat() if self.deadline else None,
            "application_url": self.application_url,
            "image_url": self.image_url,
            "source": self.source,
            "source_url": self.source_url,
            "status": self.status,
            "active": self.active,
            "quality_score": self.quality_score,
            "fingerprint": self.fingerprint,
            "updated_at": now,
        }
