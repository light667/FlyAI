#!/usr/bin/env python3
"""
=================================================================
clean_existing.py — Nettoyage one-shot des 100 bourses existantes
=================================================================
Ce script :
  1. Lit bourses_rows.csv
  2. Parse les deadlines (deadline_raw → date ISO)
  3. Calcule le statut (upcoming/open/closing_soon/closed/unknown)
  4. Normalise vers le schéma Supabase cible
  5. Déduplique (fuzzy)
  6. Valide la qualité
  7. Produit un CSV propre + rapport JSON
  8. (Optionnel) Upsert vers Supabase si --push est passé

Usage:
  python clean_existing.py --input bourses_rows.csv
  python clean_existing.py --input bourses_rows.csv --push
  python clean_existing.py --input bourses_rows.csv --output clean.csv
"""
from __future__ import annotations

import argparse
import dotenv
dotenv.load_dotenv()
import json
import logging
import os
import sys
from datetime import datetime
from pathlib import Path

import pandas as pd

# Ajouter le répertoire scripts au path
sys.path.insert(0, str(Path(__file__).parent))

from deduplicators.deduplicator import deduplicate
from enrichment.status_enricher import enrich_statuses
from monitoring.pipeline_monitor import PipelineReport
from normalizers.scholarship_normalizer import normalize_csv_row
from validators.scholarship_validator import validate

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s : %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("clean_existing")


def load_csv(path: str) -> list[dict]:
    df = pd.read_csv(path)
    df = df.where(pd.notna(df), None)
    return df.to_dict(orient="records")


def run(input_path: str, output_path: str, push: bool = False) -> PipelineReport:
    report = PipelineReport()

    # ── 1. Chargement ────────────────────────────────────────────────────────
    logger.info("Chargement : %s", input_path)
    rows = load_csv(input_path)
    report.collected = len(rows)
    report.sources_analyzed = len(set(r.get("source", "") for r in rows))
    logger.info("%d lignes chargées depuis %d sources", len(rows), report.sources_analyzed)

    # ── 2. Normalisation ─────────────────────────────────────────────────────
    logger.info("Normalisation...")
    normalized = []
    for row in rows:
        try:
            s = normalize_csv_row(row)
            normalized.append(s)
        except Exception as e:
            report.errors.append(f"Normalisation [{row.get('id', '?')}]: {e}")
            logger.warning("Erreur normalisation : %s", e)

    # ── 3. Enrichissement des statuts ─────────────────────────────────────
    logger.info("Enrichissement des statuts...")
    status_report = enrich_statuses(normalized)
    report.status_refreshed = len(status_report["changed"])

    # ── 4. Déduplication ─────────────────────────────────────────────────────
    logger.info("Déduplication...")
    dedup_result = deduplicate(normalized, fuzzy_threshold=88)
    report.deduplicated = len(dedup_result.duplicates)

    # ── 5. Validation ─────────────────────────────────────────────────────────
    logger.info("Validation...")
    val_result = validate(dedup_result.unique)
    report.validated = len(val_result.valid)
    report.rejected = len(val_result.rejected)

    # ── 6. Rapport CSV ───────────────────────────────────────────────────────
    clean_rows = []
    for s in val_result.valid:
        clean_rows.append({
            "source_id": s.source_id,
            "title": s.title,
            "university": s.university,
            "country": s.country,
            "funding_type": s.funding_type,
            "degree_level": s.degree_level,
            "deadline": s.deadline.isoformat() if s.deadline else None,
            "deadline_raw": s.deadline_raw,
            "status": s.status,
            "fields": json.dumps(s.fields, ensure_ascii=False),
            "requirements": json.dumps(s.requirements, ensure_ascii=False),
            "language_requirements": json.dumps(s.language_requirements, ensure_ascii=False),
            "application_url": s.application_url,
            "source_url": s.source_url,
            "image_url": s.image_url,
            "source": s.source,
            "quality_score": s.quality_score,
            "fingerprint": s.fingerprint,
            "active": s.active,
        })

    df_out = pd.DataFrame(clean_rows)
    df_out.to_csv(output_path, index=False)
    logger.info("CSV propre écrit : %s (%d lignes)", output_path, len(clean_rows))

    # ── 7. Rapport JSON ───────────────────────────────────────────────────────
    report.finish()
    report_path = output_path.replace(".csv", "_report.json")
    report_data = {
        **report.to_dict(),
        "status_distribution": status_report["counts"],
        "quality_score_avg": round(df_out["quality_score"].mean(), 1) if not df_out.empty else 0,
        "quality_score_min": int(df_out["quality_score"].min()) if not df_out.empty else 0,
        "quality_score_max": int(df_out["quality_score"].max()) if not df_out.empty else 0,
        "sources": df_out["source"].value_counts().to_dict() if not df_out.empty else {},
        "funding_distribution": df_out["funding_type"].value_counts().to_dict() if not df_out.empty else {},
        "degree_distribution": df_out["degree_level"].value_counts().to_dict() if not df_out.empty else {},
        "warnings": val_result.warnings,
        "fuzzy_duplicates": dedup_result.duplicate_pairs,
    }
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(report_data, f, ensure_ascii=False, indent=2)
    logger.info("Rapport JSON : %s", report_path)

    # ── 8. Push Supabase (optionnel) ─────────────────────────────────────────
    if push:
        supabase_url = os.getenv("SUPABASE_URL", "")
        supabase_key = os.getenv("SUPABASE_KEY", "")
        if not supabase_url or not supabase_key:
            logger.error("SUPABASE_URL / SUPABASE_KEY manquants dans .env — push annulé")
        else:
            from importers.supabase_importer import SupabaseImporter
            importer = SupabaseImporter(supabase_url, supabase_key)
            import_result = importer.upsert_batch(val_result.valid)
            report.new_inserted = import_result.inserted
            report.errors.extend(import_result.errors)
            logger.info("Push Supabase : %d upsertés", import_result.inserted)

    report.log_summary()
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Nettoie les bourses existantes")
    parser.add_argument("--input",  required=True, help="Chemin vers bourses_rows.csv")
    parser.add_argument("--output", default=None,  help="CSV de sortie (défaut: clean_<input>)")
    parser.add_argument("--push",   action="store_true", help="Upsert vers Supabase")
    args = parser.parse_args()

    out = args.output or str(Path(args.input).parent / f"clean_{Path(args.input).name}")
    run(args.input, out, push=args.push)
