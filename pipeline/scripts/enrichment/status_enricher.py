"""
Enrichissement : recalcul du statut selon la date du jour.
Peut être relancé quotidiennement sur toutes les bourses actives.
"""
from __future__ import annotations
import logging
from datetime import date

from models.scholarship import ScholarshipModel

logger = logging.getLogger("pipeline.enricher")


def enrich_statuses(scholarships: list) -> dict:
    """
    Recalcule le status de chaque bourse et retourne un résumé des changements.
    """
    counts = {"upcoming": 0, "open": 0, "closing_soon": 0, "closed": 0, "unknown": 0}
    changed = []

    for s in scholarships:
        old_status = s.status
        s.status = s.compute_status()
        counts[s.status] = counts.get(s.status, 0) + 1
        if old_status != s.status:
            changed.append((s.title[:60], old_status, s.status))

    if changed:
        logger.info("%d status mis à jour :", len(changed))
        for title, old, new in changed:
            logger.info("  %s  →  %s  [%s]", old, new, title)

    logger.info("Statuts : %s", counts)
    return {"counts": counts, "changed": changed}
