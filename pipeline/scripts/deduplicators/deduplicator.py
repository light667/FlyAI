"""
Détection et suppression des doublons par fingerprint + fuzzy matching.
"""
from __future__ import annotations
import logging
from dataclasses import dataclass, field
from typing import Optional

from rapidfuzz import fuzz

from models.scholarship import ScholarshipModel

logger = logging.getLogger("pipeline.deduplicator")


@dataclass
class DeduplicationResult:
    unique: list = field(default_factory=list)
    duplicates: list = field(default_factory=list)
    duplicate_pairs: list = field(default_factory=list)


def _title_key(s: ScholarshipModel) -> str:
    import re
    t = str(s.title).lower()
    t = re.sub(r"\b20\d{2}\b", "", t)
    t = re.sub(r"\b(scholarship|programme|award|fellowship|grant)\b", "", t)
    return re.sub(r"\s+", " ", t).strip()


def deduplicate(
    scholarships: list,
    existing_fingerprints: set | None = None,
    fuzzy_threshold: int = 88,
) -> DeduplicationResult:
    """
    Déduplique une liste de ScholarshipModel.

    Étape 1 : Fingerprint exact (hash md5 titre+université+pays sans année).
    Étape 2 : Fuzzy match sur le titre normalisé (token_sort_ratio >= threshold).
    Étape 3 : Filtrage contre les fingerprints existants en base (existing_fingerprints).
    """
    result = DeduplicationResult()
    seen_fingerprints: set = set(existing_fingerprints or [])
    seen_titles: list = []   # (normalized_title, index) pour fuzzy

    for s in scholarships:
        fp = s.fingerprint or s.compute_fingerprint()
        s.fingerprint = fp

        # ── Étape 1 : fingerprint exact ──
        if fp in seen_fingerprints:
            result.duplicates.append(s)
            logger.debug("Doublon exact éliminé : %s [%s]", s.title[:60], fp[:8])
            continue

        # ── Étape 2 : fuzzy sur le titre ──
        norm_title = _title_key(s)
        is_fuzzy_dup = False
        for existing_title, existing_idx in seen_titles:
            score = fuzz.token_sort_ratio(norm_title, existing_title)
            if score >= fuzzy_threshold:
                is_fuzzy_dup = True
                result.duplicate_pairs.append((s.title, result.unique[existing_idx].title, score))
                result.duplicates.append(s)
                logger.debug(
                    "Doublon fuzzy (score %d) : '%s' ~ '%s'",
                    score, s.title[:50], result.unique[existing_idx].title[:50],
                )
                break

        if not is_fuzzy_dup:
            seen_fingerprints.add(fp)
            seen_titles.append((norm_title, len(result.unique)))
            result.unique.append(s)

    logger.info(
        "Déduplication : %d uniques, %d doublons (%d pairs fuzzy)",
        len(result.unique), len(result.duplicates), len(result.duplicate_pairs),
    )
    return result
