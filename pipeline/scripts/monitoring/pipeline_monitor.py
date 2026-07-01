"""
Monitoring et rapport d'exécution du pipeline.
"""
from __future__ import annotations
import logging
import time
from dataclasses import dataclass, field
from datetime import datetime

logger = logging.getLogger("pipeline.monitor")


@dataclass
class PipelineReport:
    started_at: datetime = field(default_factory=datetime.utcnow)
    finished_at: datetime | None = None
    sources_analyzed: int = 0
    collected: int = 0
    validated: int = 0
    rejected: int = 0
    deduplicated: int = 0
    new_inserted: int = 0
    updated: int = 0
    status_refreshed: int = 0
    errors: list = field(default_factory=list)
    source_stats: dict = field(default_factory=dict)

    def finish(self) -> None:
        self.finished_at = datetime.utcnow()

    @property
    def duration_seconds(self) -> float:
        if not self.finished_at:
            return 0.0
        return (self.finished_at - self.started_at).total_seconds()

    def log_summary(self) -> None:
        logger.info("=" * 60)
        logger.info("PIPELINE REPORT — %s", self.started_at.strftime("%Y-%m-%d %H:%M UTC"))
        logger.info("  Sources analysées  : %d", self.sources_analyzed)
        logger.info("  Collectées         : %d", self.collected)
        logger.info("  Validées           : %d", self.validated)
        logger.info("  Rejetées           : %d", self.rejected)
        logger.info("  Doublons supprimés : %d", self.deduplicated)
        logger.info("  Nouvelles insertées: %d", self.new_inserted)
        logger.info("  Mises à jour       : %d", self.updated)
        logger.info("  Status rafraîchis  : %d", self.status_refreshed)
        logger.info("  Erreurs            : %d", len(self.errors))
        logger.info("  Durée              : %.1f s", self.duration_seconds)
        if self.errors:
            for e in self.errors:
                logger.error("  ✗ %s", e)
        logger.info("=" * 60)

    def to_dict(self) -> dict:
        return {
            "started_at": self.started_at.isoformat(),
            "finished_at": self.finished_at.isoformat() if self.finished_at else None,
            "duration_seconds": self.duration_seconds,
            "sources_analyzed": self.sources_analyzed,
            "collected": self.collected,
            "validated": self.validated,
            "rejected": self.rejected,
            "deduplicated": self.deduplicated,
            "new_inserted": self.new_inserted,
            "updated": self.updated,
            "status_refreshed": self.status_refreshed,
            "errors": self.errors,
        }
