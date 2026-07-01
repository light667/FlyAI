"""
Import / upsert vers Supabase.
Utilise le fingerprint comme clé de déduplication côté base.
"""
from __future__ import annotations
import logging
import os
from dataclasses import dataclass, field
from typing import Optional

from models.scholarship import ScholarshipModel

logger = logging.getLogger("pipeline.importer")


@dataclass
class ImportResult:
    inserted: int = 0
    updated: int = 0
    errors: list = field(default_factory=list)
    existing_fingerprints: set = field(default_factory=set)


class SupabaseImporter:
    def __init__(self, supabase_url: str, supabase_key: str, table: str = "scholarships"):
        self.url = supabase_url.rstrip("/")
        self.key = supabase_key
        self.table = table
        self._headers = {
            "apikey": supabase_key,
            "Authorization": f"Bearer {supabase_key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates,return=minimal",
        }

    def _request(self, method: str, endpoint: str, **kwargs):
        import requests
        url = f"{self.url}/rest/v1/{endpoint}"
        resp = requests.request(method, url, headers=self._headers, timeout=20, **kwargs)
        if not resp.ok:
            raise Exception(f"Supabase {method} {endpoint} → {resp.status_code}: {resp.text[:200]}")
        return resp

    def get_existing_fingerprints(self) -> set:
        """Charge tous les fingerprints existants pour la déduplication."""
        try:
            resp = self._request(
                "GET", self.table,
                params={"select": "fingerprint", "fingerprint": "not.is.null"},
            )
            data = resp.json()
            fps = {row["fingerprint"] for row in data if row.get("fingerprint")}
            logger.info("%d fingerprints existants chargés", len(fps))
            return fps
        except Exception as e:
            logger.error("Impossible de charger les fingerprints : %s", e)
            return set()

    def upsert_batch(self, scholarships: list, batch_size: int = 25) -> ImportResult:
        """
        Upsert par lots.
        Conflict key : fingerprint (colonne UNIQUE dans le schema).
        """
        result = ImportResult()
        batches = [scholarships[i:i+batch_size] for i in range(0, len(scholarships), batch_size)]

        for batch_num, batch in enumerate(batches, 1):
            rows = [s.to_supabase_dict() for s in batch]
            try:
                self._request("POST", self.table, json=rows)
                result.inserted += len(batch)
                logger.debug("Batch %d/%d : %d rows upsertés", batch_num, len(batches), len(batch))
            except Exception as e:
                err = f"Batch {batch_num}: {e}"
                result.errors.append(err)
                logger.error(err)

        logger.info("Import terminé : %d upsertés, %d erreurs", result.inserted, len(result.errors))
        return result

    def refresh_statuses(self) -> int:
        """
        Met à jour le status de toutes les bourses actives selon la date du jour.
        Exécuté quotidiennement via le scheduler.
        """
        from datetime import date
        today = date.today().isoformat()
        updated = 0

        updates = [
            # Fermées
            ({"status": "closed"},       f"deadline=lt.{today}&active=eq.true&status=neq.closed"),
            # Fermeture imminente (≤ 7j)
            ({"status": "closing_soon"}, f"deadline=gte.{today}&deadline=lte.{(date.today().__class__.fromisocalendar(*date.today().isocalendar()).__class__.fromisoformat)(str(date.today().replace(day=date.today().day+7)) if date.today().day+7 <= 28 else today)}&status=neq.closing_soon"),
        ]

        # Version simplifiée : on délègue à une SQL function ou on fait row par row
        try:
            resp = self._request(
                "GET", self.table,
                params={"select": "id,deadline,status", "active": "eq.true", "deadline": f"not.is.null"},
            )
            rows = resp.json()
            for row in rows:
                if not row.get("deadline"):
                    continue
                dl = date.fromisoformat(row["deadline"])
                delta = (dl - date.today()).days
                if delta < 0:
                    new_status = "closed"
                elif delta <= 7:
                    new_status = "closing_soon"
                elif delta <= 30:
                    new_status = "open"
                else:
                    new_status = "upcoming"

                if new_status != row.get("status"):
                    self._request(
                        "PATCH", self.table,
                        params={"id": f"eq.{row['id']}"},
                        json={"status": new_status},
                    )
                    updated += 1

            logger.info("%d statuts mis à jour en base", updated)
            return updated
        except Exception as e:
            logger.error("refresh_statuses error: %s", e)
            return 0
