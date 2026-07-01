#!/usr/bin/env python3
"""
=================================================================
pipeline.py — Orchestrateur principal du pipeline Fly AI
=================================================================
Séquence : Collect → Validate → Normalize → Deduplicate → Enrich → Import → Monitor

Usage:
  python pipeline.py                   # exécution complète
  python pipeline.py --status-only     # refresh statuts uniquement
  python pipeline.py --dry-run         # sans push Supabase
"""
from __future__ import annotations
import argparse
import logging
import os
import sys
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()
sys.path.insert(0, str(Path(__file__).parent))

from collectors.base_collector import CollectorConfig
from deduplicators.deduplicator import deduplicate
from enrichment.status_enricher import enrich_statuses
from importers.supabase_importer import SupabaseImporter
from monitoring.pipeline_monitor import PipelineReport
from validators.scholarship_validator import validate

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s : %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("pipeline")


def get_collectors() -> list:
    """
    Retourne tous les collecteurs actifs.
    Ajouter une nouvelle source ici uniquement.
    """
    collectors = []

    # ── ScholarshipsAds ──
    try:
        from collectors.scholarshipsads_collector import ScholarshipsAdsCollector
        collectors.append(ScholarshipsAdsCollector())
    except Exception as e:
        logger.warning("ScholarshipsAds non chargé : %s", e)

    # ── Opportunities For Africans ──
    try:
        from collectors.ofa_collector import OFACollector
        collectors.append(OFACollector())
    except Exception as e:
        logger.warning("OFA non chargé : %s", e)

    # ── Greatyop ──
    try:
        from collectors.greatyop_collector import GreatyopCollector
        collectors.append(GreatyopCollector())
    except Exception as e:
        logger.warning("Greatyop non chargé : %s", e)

    # ── RSS feeds ──
    try:
        from collectors.rss_collector import RSSCollector
        collectors.append(RSSCollector())
    except Exception as e:
        logger.warning("RSS non chargé : %s", e)

    return collectors


def run(dry_run: bool = False, status_only: bool = False) -> PipelineReport:
    report = PipelineReport()

    supabase_url = os.getenv("SUPABASE_URL", "")
    supabase_key = os.getenv("SUPABASE_KEY", "")

    importer = None
    if supabase_url and supabase_key:
        importer = SupabaseImporter(supabase_url, supabase_key)
    else:
        logger.warning("Supabase non configuré — mode dry-run forcé")
        dry_run = True

    # ── Status-only mode ────────────────────────────────────────────────────
    if status_only:
        logger.info("Mode refresh statuts uniquement...")
        if importer:
            report.status_refreshed = importer.refresh_statuses()
        report.finish()
        report.log_summary()
        return report

    # ── Collecte ────────────────────────────────────────────────────────────
    collectors = get_collectors()
    report.sources_analyzed = len(collectors)
    all_scholarships = []

    for collector in collectors:
        results = collector.run()
        all_scholarships.extend(results)
        report.errors.extend(collector.errors)
        report.source_stats[collector.config.name] = len(results)

    report.collected = len(all_scholarships)
    logger.info("Total collecté : %d bourses depuis %d sources", report.collected, report.sources_analyzed)

    if not all_scholarships:
        logger.warning("Aucune bourse collectée — pipeline arrêté")
        report.finish()
        return report

    # ── Enrich statuts ──────────────────────────────────────────────────────
    enrich_statuses(all_scholarships)

    # ── Déduplication ───────────────────────────────────────────────────────
    existing_fps = importer.get_existing_fingerprints() if importer else set()
    dedup = deduplicate(all_scholarships, existing_fingerprints=existing_fps)
    report.deduplicated = len(dedup.duplicates)

    # ── Validation ──────────────────────────────────────────────────────────
    val = validate(dedup.unique)
    report.validated = len(val.valid)
    report.rejected = len(val.rejected)

    # ── Import ──────────────────────────────────────────────────────────────
    if not dry_run and importer and val.valid:
        import_result = importer.upsert_batch(val.valid)
        report.new_inserted = import_result.inserted
        report.errors.extend(import_result.errors)

    # ── Refresh statuts en base ─────────────────────────────────────────────
    if not dry_run and importer:
        report.status_refreshed = importer.refresh_statuses()

    report.finish()
    report.log_summary()
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run",     action="store_true")
    parser.add_argument("--status-only", action="store_true")
    args = parser.parse_args()
    run(dry_run=args.dry_run, status_only=args.status_only)
