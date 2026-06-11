"""
FlyAI — Pipeline multi-sources
================================
Orchestrateur qui lance le scraping sur plusieurs sites
et fusionne les résultats dans un seul fichier JSON.

Usage:
    python pipeline.py                  # scrape toutes les sources
    python pipeline.py --sources ofa    # ofa seulement
    python pipeline.py --dry-run        # teste sans sauvegarder
"""

import json
import time
import logging
import argparse
from pathlib import Path
from datetime import datetime

log = logging.getLogger("flyai.pipeline")
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")


# ─── Importation des scrapers disponibles ────────────────────────────────────

def scrape_ofa(pages=5):
    """Scraper OpportunitiesForAfricans.com"""
    from ofa_scraper import scrape_ofa as _scrape
    return _scrape(max_pages=pages)


def scrape_greatyop(pages=5):
    """
    Scraper Greatyop.com — même logique que OFA.
    Adapter les sélecteurs CSS si nécessaire.
    """
    # TODO: implémenter quand le scraper Greatyop est prêt
    log.warning("Scraper Greatyop pas encore implémenté")
    return []


def scrape_portailbourses(pages=5):
    """
    Scraper PortailBourses.com
    """
    # TODO: implémenter
    log.warning("Scraper PortailBourses pas encore implémenté")
    return []


# ─── Sources disponibles ──────────────────────────────────────────────────────

SOURCES = {
    "ofa": {
        "name": "OpportunitiesForAfricans",
        "fn": scrape_ofa,
        "priority": 1,
    },
    "greatyop": {
        "name": "Greatyop.com",
        "fn": scrape_greatyop,
        "priority": 2,
    },
    "portailbourses": {
        "name": "PortailBourses.com",
        "fn": scrape_portailbourses,
        "priority": 3,
    },
}


# ─── Déduplication ────────────────────────────────────────────────────────────

def deduplicate(bourses_list: list) -> list:
    """
    Supprime les doublons par URL normalisée.
    Préférence donnée à la bourse avec le plus de champs remplis.
    """
    seen = {}
    for b in bourses_list:
        url = b.get("url", "").rstrip("/").lower()
        if url not in seen:
            seen[url] = b
        else:
            # Garder celui avec plus de données
            existing_score = sum(1 for v in seen[url].values() if v)
            new_score = sum(1 for v in b.values() if v)
            if new_score > existing_score:
                seen[url] = b
    return list(seen.values())


# ─── Validation qualité ───────────────────────────────────────────────────────

def quality_report(bourses: list) -> dict:
    """Retourne un rapport de qualité des données."""
    total = len(bourses)
    if total == 0:
        return {}

    return {
        "total": total,
        "avec_deadline": sum(1 for b in bourses if b.get("deadline")),
        "avec_pays": sum(1 for b in bourses if b.get("pays_destination")),
        "avec_niveau": sum(1 for b in bourses if b.get("niveau_etude")),
        "avec_description": sum(1 for b in bourses if b.get("description")),
        "avec_image": sum(1 for b in bourses if b.get("image_url")),
        "financement_total": sum(1 for b in bourses if b.get("financement") == "TOTAL"),
        "financement_partiel": sum(1 for b in bourses if b.get("financement") == "PARTIEL"),
        "financement_inconnu": sum(1 for b in bourses if b.get("financement") == "INCONNU"),
        "actives": sum(1 for b in bourses if b.get("active", True)),
        "score_completude_moyen": round(
            sum(
                sum(1 for v in b.values() if v) / len(b)
                for b in bourses
            ) / total * 100, 1
        ),
    }


# ─── Pipeline ────────────────────────────────────────────────────────────────

def run_pipeline(sources: list, pages_per_source: int, output_dir: Path, dry_run: bool):
    all_raw = []

    for source_key in sources:
        source = SOURCES.get(source_key)
        if not source:
            log.warning(f"Source inconnue: {source_key}")
            continue

        log.info(f"\n{'='*50}")
        log.info(f"Scraping: {source['name']}")
        log.info(f"{'='*50}")

        try:
            results = source["fn"](pages=pages_per_source)
            log.info(f"  {len(results)} bourses collectées depuis {source['name']}")

            # Convertir en dict si nécessaire (dataclass → dict)
            from dataclasses import asdict
            dicts = []
            for r in results:
                if hasattr(r, "__dataclass_fields__"):
                    dicts.append(asdict(r))
                elif isinstance(r, dict):
                    dicts.append(r)
            all_raw.extend(dicts)

        except Exception as e:
            log.error(f"Erreur sur {source['name']}: {e}", exc_info=True)

        time.sleep(3)  # pause entre sources

    # Déduplication
    log.info(f"\nAvant dédup: {len(all_raw)} bourses")
    all_bourses = deduplicate(all_raw)
    log.info(f"Après dédup: {len(all_bourses)} bourses")

    # Rapport qualité
    report = quality_report(all_bourses)
    log.info("\n📊 Rapport qualité:")
    for k, v in report.items():
        log.info(f"  {k}: {v}")

    if dry_run:
        log.info("\n🔍 Dry run — aucun fichier sauvegardé.")
        return all_bourses

    # Sauvegarde
    output_dir.mkdir(parents=True, exist_ok=True)
    ts = datetime.now().strftime("%Y%m%d_%H%M")

    # Fichier principal
    out_file = output_dir / f"bourses_{ts}.json"
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(all_bourses, f, ensure_ascii=False, indent=2, default=str)
    log.info(f"\n💾 Sauvegardé: {out_file}")

    # Fichier "latest" (toujours le plus récent)
    latest = output_dir / "bourses_latest.json"
    with open(latest, "w", encoding="utf-8") as f:
        json.dump(all_bourses, f, ensure_ascii=False, indent=2, default=str)

    # Rapport JSON
    report_file = output_dir / f"rapport_{ts}.json"
    with open(report_file, "w") as f:
        json.dump({"timestamp": ts, "sources": sources, **report}, f, indent=2)

    return all_bourses


# ─── CLI ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="FlyAI — Pipeline scraping multi-sources")
    parser.add_argument(
        "--sources", nargs="+",
        default=list(SOURCES.keys()),
        choices=list(SOURCES.keys()),
        help="Sources à scraper"
    )
    parser.add_argument("--pages", type=int, default=5, help="Pages par source")
    parser.add_argument("--output-dir", default="./data", help="Dossier de sortie")
    parser.add_argument("--dry-run", action="store_true", help="Ne pas sauvegarder")
    args = parser.parse_args()

    run_pipeline(
        sources=args.sources,
        pages_per_source=args.pages,
        output_dir=Path(args.output_dir),
        dry_run=args.dry_run,
    )


if __name__ == "__main__":
    main()
