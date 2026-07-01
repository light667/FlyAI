"""
Validation et scoring qualité des bourses normalisées.
"""
from __future__ import annotations
import logging
from dataclasses import dataclass, field

from models.scholarship import ScholarshipModel

logger = logging.getLogger("pipeline.validator")


@dataclass
class ValidationResult:
    valid: list = field(default_factory=list)
    rejected: list = field(default_factory=list)
    warnings: dict = field(default_factory=dict)   # id → [messages]


def _score(s: ScholarshipModel) -> int:
    score = 0
    if s.deadline:                                  score += 15
    if s.university:                                score += 10
    if s.application_url:                           score += 15
    if s.description and len(s.description) > 100: score += 10
    if s.image_url:                                 score += 5
    if s.fields:                                    score += 10
    if s.requirements:                              score += 10
    if s.benefits:                                  score += 10
    if s.funding_type != "Unknown":                 score += 10
    if s.language_requirements:                     score += 5
    return min(score, 100)


def validate(scholarships: list) -> ValidationResult:
    result = ValidationResult()
    for s in scholarships:
        warnings = []
        errors = []

        # Titre vide → rejet
        if not s.title or len(s.title.strip()) < 5:
            errors.append("Titre trop court ou vide")

        # Deadline passée → on garde (status=closed) mais on avertit
        if s.status == "closed":
            warnings.append("Deadline expirée — statut: closed")

        # Pas d'URL de candidature
        if not s.application_url:
            warnings.append("Pas d'URL de candidature")

        # Score qualité
        s.quality_score = _score(s)

        key = s.source_id or s.slug or s.title[:40]
        if errors:
            result.rejected.append(s)
            result.warnings[key] = errors
            logger.warning("Rejeté [%s]: %s", key, errors)
        else:
            if warnings:
                result.warnings[key] = warnings
            result.valid.append(s)

    logger.info(
        "Validation : %d valides, %d rejetés",
        len(result.valid), len(result.rejected),
    )
    return result
