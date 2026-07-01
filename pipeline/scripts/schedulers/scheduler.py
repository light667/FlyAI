#!/usr/bin/env python3
"""
Scheduler quotidien via APScheduler.
Alternative légère à Cron / GitHub Actions.

Usage: python schedulers/scheduler.py
"""
import logging
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("scheduler")

try:
    from apscheduler.schedulers.blocking import BlockingScheduler
    HAS_APSCHEDULER = True
except ImportError:
    HAS_APSCHEDULER = False

from pipeline import run


def daily_full_pipeline():
    logger.info("Démarrage pipeline quotidien complet")
    run(dry_run=False)


def hourly_status_refresh():
    logger.info("Refresh horaire des statuts")
    run(dry_run=False, status_only=True)


if __name__ == "__main__":
    if not HAS_APSCHEDULER:
        logger.error("APScheduler non installé. pip install apscheduler")
        logger.info("Alternative : configurer un cron job :")
        logger.info("  # Pipeline complet à 06:00 UTC chaque jour")
        logger.info("  0 6 * * * cd /path/to/scripts && python pipeline.py")
        logger.info("  # Refresh statuts toutes les heures")
        logger.info("  0 * * * * cd /path/to/scripts && python pipeline.py --status-only")
        sys.exit(1)

    scheduler = BlockingScheduler(timezone="UTC")
    scheduler.add_job(daily_full_pipeline, "cron", hour=6,  minute=0, id="full_pipeline")
    scheduler.add_job(hourly_status_refresh, "cron", minute=0, id="status_refresh")

    logger.info("Scheduler démarré — pipeline: 06:00 UTC, status: chaque heure")
    try:
        scheduler.start()
    except KeyboardInterrupt:
        logger.info("Scheduler arrêté")
