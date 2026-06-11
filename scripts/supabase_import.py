"""
╔══════════════════════════════════════════════════════════════════════════════╗
║  FlyAI — Import Supabase                                                    ║
║  flyai_bourses.json → table `bourses` (upsert par lots de 100)              ║
╚══════════════════════════════════════════════════════════════════════════════╝

Installation :
    pip install supabase python-dotenv

Configuration (fichier .env ou variables d'environnement) :
    SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co
    SUPABASE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...   ← service_role key

Usage :
    python supabase_import.py                              # import complet
    python supabase_import.py --file ./data/flyai.json    # fichier custom
    python supabase_import.py --batch-size 50             # lots plus petits
    python supabase_import.py --dry-run                   # valider sans écrire
    python supabase_import.py --active-only               # actives seulement
    python supabase_import.py --min-score 40              # filtre qualité
    python supabase_import.py --resume-from 300           # reprendre à l'index 300
    python supabase_import.py --table bourses_staging     # table cible custom
    python supabase_import.py --delete-orphans            # purger les anciens IDs

Colonnes Supabase attendues (voir schéma SQL dans flyai_normalize.py) :
    TEXT     : id (PK), slug, titre, url, source, deadline_raw, date_publication,
               universite, lieu_etude, financement, montant_bourse, nb_bourses,
               lien_candidature, image_url, description
    DATE     : deadline
    INTEGER  : annee, qualite_score
    BOOLEAN  : africains_eligibles, active
    JSONB    : sources, sources_ids, pays_destination, niveau_etude, domaines,
               langues_requises, nationalites_eligibles, avantages, criteres,
               couverture, qualite_details
    TIMESTAMPTZ : created_at, updated_at
"""

from __future__ import annotations

import os
import sys
import json
import time
import logging
import argparse
import re
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Optional

# ─── Logging ──────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler("supabase_import.log", encoding="utf-8"),
    ],
)
log = logging.getLogger("flyai.import")

# ─── Constantes ────────────────────────────────────────────────────────────────

DEFAULT_FILE       = "flyai_bourses.json"
DEFAULT_TABLE      = "bourses"
DEFAULT_BATCH      = 100
DEFAULT_RETRY      = 3
DEFAULT_RETRY_WAIT = 2.0    # secondes (doublé à chaque retry)
CHECKPOINT_FILE    = ".import_checkpoint.json"

# Colonnes TEXT qui doivent être None (pas "") quand vides → Supabase préfère NULL
NULLABLE_TEXT_FIELDS = {
    "universite", "lieu_etude", "montant_bourse", "nb_bourses",
    "lien_candidature", "image_url", "deadline_raw", "date_publication",
    "description", "slug", "source",
}

# Colonnes INTEGER qui ne peuvent pas être "" ou une chaîne vide
NULLABLE_INT_FIELDS = {"annee", "qualite_score"}

# Colonnes DATE — None si absent, format ISO YYYY-MM-DD requis
DATE_FIELDS = {"deadline"}

# Colonnes JSONB (list) — [] si absent, jamais None
JSONB_LIST_FIELDS = {
    "sources", "pays_destination", "niveau_etude", "domaines",
    "langues_requises", "nationalites_eligibles", "avantages",
    "criteres", "couverture",
}

# Colonnes JSONB (dict) — {} si absent
JSONB_DICT_FIELDS = {"sources_ids", "qualite_details"}

# Colonnes à exclure de l'import (non présentes dans le schéma Supabase)
EXCLUDE_FIELDS: set[str] = set()  # Ajoutez ici si nécessaire ex: {"champ_temp"}


# ─── Chargement .env ──────────────────────────────────────────────────────────

def load_env() -> None:
    """Charge les variables depuis .env si présent."""
    env_path = Path(".env")
    if not env_path.exists():
        return
    with open(env_path) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, _, value = line.partition("=")
                key = key.strip()
                value = value.strip().strip('"').strip("'")
                if key not in os.environ:  # Ne pas écraser les vars déjà définies
                    os.environ[key] = value
    log.info("✅ .env chargé")


# ─── Nettoyage & validation des records ───────────────────────────────────────

def clean_record(raw: dict) -> dict:
    """
    Prépare un record JSON pour Supabase :
    - Convertit "" → None pour les champs TEXT nullable
    - Garantit les types JSONB (list/dict)
    - Valide le format DATE
    - Tronque les textes trop longs (sécurité)
    - Exclut les champs non présents dans le schéma

    Retourne un dict propre ou lève ValueError si le record est invalide.
    """
    r = deepcopy(raw)

    # ── Supprimer les champs exclus ───────────────────────────────────────────
    for field in EXCLUDE_FIELDS:
        r.pop(field, None)

    # ── Champs obligatoires ───────────────────────────────────────────────────
    if not r.get("id") or not str(r["id"]).startswith("fly_"):
        raise ValueError(f"id invalide : {r.get('id')!r}")
    if not r.get("titre") or len(str(r["titre"])) < 5:
        raise ValueError(f"titre invalide : {r.get('titre')!r}")
    if not r.get("url") or not str(r["url"]).startswith("http"):
        raise ValueError(f"url invalide : {r.get('url')!r}")

    # ── Champs TEXT : "" → None ───────────────────────────────────────────────
    for field in NULLABLE_TEXT_FIELDS:
        val = r.get(field)
        if val == "" or val is None:
            r[field] = None
        else:
            r[field] = str(val).strip() or None

    # ── Tronquer les champs texte trop longs ──────────────────────────────────
    LIMITS = {
        "titre":           512,
        "slug":            200,
        "url":             2048,
        "universite":      256,
        "description":     5000,
        "montant_bourse":  100,
        "lieu_etude":      200,
        "lien_candidature": 2048,
        "image_url":       2048,
    }
    for field, max_len in LIMITS.items():
        val = r.get(field)
        if val and len(str(val)) > max_len:
            r[field] = str(val)[:max_len - 3] + "…"
            log.debug(f"  Tronqué {field} à {max_len} chars (id={r['id']})")

    # ── Champs INTEGER ────────────────────────────────────────────────────────
    for field in NULLABLE_INT_FIELDS:
        val = r.get(field)
        if val is None or val == "":
            r[field] = None
        else:
            try:
                r[field] = int(val)
            except (TypeError, ValueError):
                r[field] = None

    # ── Champs DATE ───────────────────────────────────────────────────────────
    for field in DATE_FIELDS:
        val = r.get(field)
        if not val:
            r[field] = None
        elif re.match(r"^\d{4}-\d{2}-\d{2}$", str(val)):
            r[field] = str(val)
        else:
            log.warning(f"  Format date invalide ({field}={val!r}) pour id={r['id']} → None")
            r[field] = None

    # ── Champs JSONB (list) ───────────────────────────────────────────────────
    for field in JSONB_LIST_FIELDS:
        val = r.get(field)
        if val is None:
            r[field] = []
        elif not isinstance(val, list):
            r[field] = [str(val)] if val else []
        else:
            # Nettoyer les éléments None dans les listes
            r[field] = [str(x) for x in val if x is not None and str(x).strip()]

    # ── Champs JSONB (dict) ───────────────────────────────────────────────────
    for field in JSONB_DICT_FIELDS:
        val = r.get(field)
        if val is None:
            r[field] = {}
        elif not isinstance(val, dict):
            r[field] = {}

    # ── Champs BOOLEAN ────────────────────────────────────────────────────────
    for field in ("africains_eligibles", "active"):
        val = r.get(field)
        r[field] = bool(val) if val is not None else False

    # ── Timestamps ────────────────────────────────────────────────────────────
    now_iso = datetime.now(timezone.utc).isoformat()
    if not r.get("created_at"):
        r["created_at"] = now_iso
    if not r.get("updated_at"):
        r["updated_at"] = now_iso

    # Garantir que financement a une valeur valide
    fin = str(r.get("financement", "INCONNU")).upper()
    r["financement"] = fin if fin in ("TOTAL", "PARTIEL", "INCONNU") else "INCONNU"

    return r


def validate_batch(batch: list[dict]) -> tuple[list[dict], list[dict]]:
    """
    Valide et nettoie un batch.
    Retourne (records_valides, records_erreur).
    """
    valid = []
    errors = []
    for raw in batch:
        try:
            cleaned = clean_record(raw)
            valid.append(cleaned)
        except ValueError as e:
            errors.append({"raw": raw, "error": str(e)})
    return valid, errors


# ─── Checkpoint ───────────────────────────────────────────────────────────────

def save_checkpoint(data: dict) -> None:
    """Sauvegarde l'état de progression."""
    with open(CHECKPOINT_FILE, "w") as f:
        json.dump(data, f, indent=2, default=str)


def load_checkpoint(file: str) -> Optional[dict]:
    """Charge un checkpoint existant si le fichier source correspond."""
    if not Path(CHECKPOINT_FILE).exists():
        return None
    try:
        with open(CHECKPOINT_FILE) as f:
            cp = json.load(f)
        if cp.get("source_file") == file:
            return cp
    except Exception:
        pass
    return None


# ─── Import Supabase ──────────────────────────────────────────────────────────

def upsert_batch(
    client,
    table: str,
    batch: list[dict],
    attempt: int = 1,
    max_retries: int = DEFAULT_RETRY,
) -> dict:
    """
    Upsert un batch dans Supabase avec retry exponentiel.
    Retourne {"ok": N, "errors": [...]} .
    """
    try:
        result = (
            client.table(table)
            .upsert(batch, on_conflict="id")
            .execute()
        )
        # Supabase Python SDK v2 retourne un objet avec .data
        n = len(result.data) if hasattr(result, "data") and result.data else len(batch)
        return {"ok": n, "errors": []}

    except Exception as e:
        err_msg = str(e)

        # Cas non-récupérable : problème de schéma ou données invalides
        NON_RETRYABLE = [
            "invalid input syntax",
            "violates check constraint",
            "null value in column",
            "column",          # erreur colonne inconnue
            "permission denied",
            "relation",        # table inexistante
        ]
        is_fatal = any(kw in err_msg.lower() for kw in NON_RETRYABLE)

        if is_fatal or attempt >= max_retries:
            log.error(f"  ❌ Batch échoué (fatal={is_fatal}, attempt={attempt}): {err_msg[:200]}")
            return {"ok": 0, "errors": [{"batch_error": err_msg, "ids": [r.get("id") for r in batch]}]}

        # Retry avec backoff
        wait = DEFAULT_RETRY_WAIT * (2 ** (attempt - 1))
        log.warning(f"  ⚠️  Retry {attempt}/{max_retries} dans {wait:.1f}s : {err_msg[:100]}")
        time.sleep(wait)
        return upsert_batch(client, table, batch, attempt + 1, max_retries)


def upsert_batch_individual_fallback(
    client,
    table: str,
    batch: list[dict],
) -> dict:
    """
    Fallback : quand un batch entier échoue, réessaie record par record.
    Permet d'identifier le record problématique sans perdre les autres.
    """
    log.info(f"  🔄 Fallback individuel sur {len(batch)} records...")
    ok = 0
    errors = []

    for record in batch:
        try:
            result = client.table(table).upsert([record], on_conflict="id").execute()
            ok += 1
        except Exception as e:
            log.warning(f"    ✗ {record.get('id')} : {str(e)[:120]}")
            errors.append({"id": record.get("id"), "titre": record.get("titre","")[:50], "error": str(e)})

    return {"ok": ok, "errors": errors}


# ─── Pipeline d'import ────────────────────────────────────────────────────────

def run_import(
    source_file: str,
    table: str,
    batch_size: int,
    dry_run: bool,
    active_only: bool,
    min_score: int,
    resume_from: int,
    delete_orphans: bool,
    supabase_url: str,
    supabase_key: str,
    max_retries: int,
) -> dict:
    """Pipeline complet d'import."""

    # ── Chargement du JSON ────────────────────────────────────────────────────
    path = Path(source_file)
    if not path.exists():
        log.error(f"Fichier introuvable : {path.absolute()}")
        sys.exit(1)

    log.info(f"📂 Chargement de {path} ...")
    with open(path, encoding="utf-8") as f:
        raw_data: list[dict] = json.load(f)

    if not isinstance(raw_data, list):
        log.error("Le fichier JSON doit contenir une liste de bourses.")
        sys.exit(1)

    log.info(f"   {len(raw_data)} records chargés")

    # ── Filtres pré-import ────────────────────────────────────────────────────
    data = raw_data

    if active_only:
        before = len(data)
        data = [r for r in data if r.get("active") is True]
        log.info(f"   Filtre active_only : {before} → {len(data)}")

    if min_score > 0:
        before = len(data)
        data = [r for r in data if (r.get("qualite_score") or 0) >= min_score]
        log.info(f"   Filtre min_score ≥ {min_score} : {before} → {len(data)}")

    if not data:
        log.warning("Aucun record après filtrage. Import annulé.")
        return {"total": 0, "ok": 0, "errors": 0, "skipped": 0}

    total = len(data)

    # ── Dry run ───────────────────────────────────────────────────────────────
    if dry_run:
        log.info(f"\n🔍 MODE DRY RUN — Validation de {total} records (aucune écriture)")
        valid_count = 0
        error_count = 0
        for i, record in enumerate(data):
            try:
                clean_record(record)
                valid_count += 1
            except ValueError as e:
                log.warning(f"  [#{i}] INVALIDE : {e}")
                error_count += 1
        log.info(f"\n✅ Dry run terminé : {valid_count} valides, {error_count} invalides sur {total}")
        return {"total": total, "ok": valid_count, "errors": error_count, "skipped": 0}

    # ── Connexion Supabase ────────────────────────────────────────────────────
    try:
        from supabase import create_client, Client
    except ImportError:
        log.error("❌ Package manquant : pip install supabase")
        sys.exit(1)

    if not supabase_url or not supabase_key:
        log.error("❌ SUPABASE_URL et SUPABASE_KEY requis (env vars ou .env)")
        sys.exit(1)

    log.info(f"\n🔌 Connexion à Supabase : {supabase_url[:40]}...")
    try:
        client: Client = create_client(supabase_url, supabase_key)
        # Test de connexion : compter les lignes existantes
        test = client.table(table).select("id", count="exact").limit(1).execute()
        existing_count = test.count if hasattr(test, "count") and test.count is not None else "?"
        log.info(f"   ✅ Connexion OK — Table `{table}` : {existing_count} lignes existantes")
    except Exception as e:
        log.error(f"❌ Connexion Supabase échouée : {e}")
        sys.exit(1)

    # ── Checkpoint : reprendre si interrupted ─────────────────────────────────
    start_index = resume_from
    if resume_from == 0:
        cp = load_checkpoint(source_file)
        if cp:
            last = cp.get("last_ok_index", 0)
            log.info(f"   🔖 Checkpoint trouvé : reprise depuis l'index {last + 1}")
            start_index = last + 1

    if start_index > 0:
        data = data[start_index:]
        log.info(f"   Reprise depuis l'index {start_index} ({len(data)} records restants)")

    # ── Import par batch ──────────────────────────────────────────────────────
    log.info(f"\n🚀 Import de {len(data)} records en lots de {batch_size} → `{table}`\n")

    stats = {
        "total": total,
        "processed": 0,
        "ok": 0,
        "invalid": 0,       # Rejetés à la validation Python
        "failed": 0,        # Erreurs Supabase non récupérées
        "retried": 0,
        "errors": [],       # Liste des erreurs détaillées
        "start_time": datetime.now(timezone.utc).isoformat(),
    }

    all_ids_imported: list[str] = []

    for batch_start in range(0, len(data), batch_size):
        batch_raw  = data[batch_start:batch_start + batch_size]
        global_idx = start_index + batch_start
        batch_num  = batch_start // batch_size + 1
        total_batches = (len(data) + batch_size - 1) // batch_size

        log.info(f"[Batch {batch_num:3d}/{total_batches}] "
                 f"Records {global_idx + 1}–{global_idx + len(batch_raw)} "
                 f"({stats['ok']}/{total} OK jusqu'ici)")

        # Validation Python
        valid_batch, validation_errors = validate_batch(batch_raw)

        if validation_errors:
            log.warning(f"  ⚠️  {len(validation_errors)} records invalides ignorés :")
            for ve in validation_errors:
                log.warning(f"    ✗ {ve['raw'].get('id','?')} : {ve['error']}")
            stats["invalid"] += len(validation_errors)
            stats["errors"].extend([{
                "type": "validation",
                "id": ve["raw"].get("id"),
                "titre": str(ve["raw"].get("titre",""))[:60],
                "error": ve["error"],
            } for ve in validation_errors])

        if not valid_batch:
            log.warning("  Batch entièrement invalide, ignoré.")
            continue

        # Upsert avec retry
        result = upsert_batch(client, table, valid_batch, max_retries=max_retries)

        if result["ok"] == 0 and result["errors"]:
            # Batch échoué : fallback individuel
            log.warning(f"  Batch échoué → fallback individuel sur {len(valid_batch)} records")
            stats["retried"] += 1
            result = upsert_batch_individual_fallback(client, table, valid_batch)

        stats["ok"]     += result["ok"]
        stats["failed"] += len(result["errors"])
        stats["errors"].extend([{
            "type": "supabase",
            **e
        } for e in result["errors"]])
        stats["processed"] += len(batch_raw)

        # Collecter les IDs importés avec succès
        if result["ok"] > 0:
            all_ids_imported.extend([r["id"] for r in valid_batch[:result["ok"]]])

        # Checkpoint
        save_checkpoint({
            "source_file":    source_file,
            "table":          table,
            "last_ok_index":  global_idx + len(batch_raw) - 1,
            "ok_so_far":      stats["ok"],
            "failed_so_far":  stats["failed"],
            "timestamp":      datetime.now(timezone.utc).isoformat(),
        })

        # Affichage progression
        pct = stats["ok"] * 100 // total
        log.info(f"  ✅ +{result['ok']} OK | Total : {stats['ok']}/{total} ({pct}%)"
                 + (f" | ❌ {len(result['errors'])} erreurs" if result["errors"] else ""))

        # Petite pause entre les batches (rate-limiting Supabase Free tier)
        if batch_num < total_batches:
            time.sleep(0.1)

    # ── Suppression des orphelins (optionnel) ─────────────────────────────────
    if delete_orphans and all_ids_imported:
        log.info(f"\n🗑️  Suppression des orphelins...")
        try:
            # Récupérer tous les IDs existants dans la table
            existing = []
            page = 0
            PAGE_SIZE = 1000
            while True:
                res = (
                    client.table(table)
                    .select("id")
                    .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1)
                    .execute()
                )
                if not res.data:
                    break
                existing.extend([r["id"] for r in res.data])
                if len(res.data) < PAGE_SIZE:
                    break
                page += 1

            ids_to_delete = [eid for eid in existing if eid not in set(all_ids_imported)]
            log.info(f"   {len(existing)} IDs en base, {len(ids_to_delete)} orphelins à supprimer")

            if ids_to_delete:
                # Supprimer par lot de 100
                deleted = 0
                for i in range(0, len(ids_to_delete), 100):
                    chunk = ids_to_delete[i:i + 100]
                    client.table(table).delete().in_("id", chunk).execute()
                    deleted += len(chunk)
                log.info(f"   ✅ {deleted} orphelins supprimés")
        except Exception as e:
            log.error(f"   Erreur suppression orphelins : {e}")

    # ── Rapport final ─────────────────────────────────────────────────────────
    stats["end_time"] = datetime.now(timezone.utc).isoformat()

    log.info("\n" + "=" * 60)
    log.info("📊 RAPPORT IMPORT SUPABASE")
    log.info("=" * 60)
    log.info(f"   Source          : {source_file}")
    log.info(f"   Table Supabase  : {table}")
    log.info(f"   Batch size      : {batch_size}")
    log.info(f"   Total chargés   : {total}")
    log.info(f"   ✅ Importés OK  : {stats['ok']}")
    log.info(f"   ⚠️  Invalides    : {stats['invalid']}")
    log.info(f"   ❌ Échoués      : {stats['failed']}")
    log.info(f"   🔄 Retries      : {stats['retried']}")

    if stats["errors"]:
        log.info(f"\n   Erreurs détaillées ({len(stats['errors'])}) :")
        for err in stats["errors"][:10]:     # Afficher max 10
            err_type = err.get("type", "?")
            err_id   = err.get("id", "?")
            err_msg  = err.get("error") or err.get("batch_error", "?")
            log.info(f"     [{err_type}] {err_id} : {str(err_msg)[:120]}")
        if len(stats["errors"]) > 10:
            log.info(f"     ... et {len(stats['errors']) - 10} autres (voir supabase_import.log)")

        # Sauvegarder toutes les erreurs dans un fichier
        error_file = Path("import_errors.json")
        with open(error_file, "w", encoding="utf-8") as f:
            json.dump(stats["errors"], f, ensure_ascii=False, indent=2, default=str)
        log.info(f"\n   📄 Erreurs complètes → {error_file}")

    if stats["ok"] == total:
        # Import complet : nettoyer le checkpoint
        if Path(CHECKPOINT_FILE).exists():
            Path(CHECKPOINT_FILE).unlink()
        log.info("\n🎉 Import complet réussi ! Checkpoint supprimé.")
    else:
        log.info(f"\n⚠️  Import partiel. Relancez avec --resume-from {stats['processed'] + start_index}")

    log.info("=" * 60)
    return stats


# ─── Vérification post-import ─────────────────────────────────────────────────

def verify_import(client, table: str, expected: int) -> None:
    """Vérifie rapidement que l'import s'est bien passé."""
    log.info("\n🔎 Vérification post-import...")
    try:
        res = client.table(table).select("id", count="exact").execute()
        count = res.count if hasattr(res, "count") and res.count is not None else "?"
        log.info(f"   Lignes dans `{table}` : {count} (attendu : ~{expected})")

        # Vérifier quelques métriques
        active_res = (
            client.table(table)
            .select("id", count="exact")
            .eq("active", True)
            .execute()
        )
        african_res = (
            client.table(table)
            .select("id", count="exact")
            .eq("africains_eligibles", True)
            .execute()
        )
        log.info(f"   Actives : {active_res.count if hasattr(active_res,'count') else '?'}")
        log.info(f"   Africains éligibles : {african_res.count if hasattr(african_res,'count') else '?'}")
    except Exception as e:
        log.warning(f"   Vérification impossible : {e}")


# ─── CLI ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="FlyAI — Import Supabase (upsert par lots)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Variables d'environnement (ou fichier .env) :
  SUPABASE_URL   URL de votre projet Supabase
  SUPABASE_KEY   Clé service_role (pas la clé anon)

Exemples :
  python supabase_import.py
  python supabase_import.py --dry-run
  python supabase_import.py --file ./data/flyai_bourses.json --batch-size 50
  python supabase_import.py --active-only --min-score 40
  python supabase_import.py --resume-from 400
  python supabase_import.py --table bourses_v2 --delete-orphans
        """,
    )

    parser.add_argument("--file",          default=DEFAULT_FILE,
                        help=f"Fichier JSON source (défaut: {DEFAULT_FILE})")
    parser.add_argument("--table",         default=DEFAULT_TABLE,
                        help=f"Table Supabase cible (défaut: {DEFAULT_TABLE})")
    parser.add_argument("--batch-size",    type=int, default=DEFAULT_BATCH,
                        help=f"Taille des lots (défaut: {DEFAULT_BATCH})")
    parser.add_argument("--dry-run",       action="store_true",
                        help="Valider sans écrire dans Supabase")
    parser.add_argument("--active-only",   action="store_true",
                        help="N'importer que les bourses actives")
    parser.add_argument("--min-score",     type=int, default=0,
                        help="Score qualité minimum (0–100, défaut: 0 = tout)")
    parser.add_argument("--resume-from",   type=int, default=0,
                        help="Reprendre depuis l'index N (0 = auto-checkpoint)")
    parser.add_argument("--delete-orphans", action="store_true",
                        help="Supprimer les IDs en base non présents dans le fichier")
    parser.add_argument("--max-retries",   type=int, default=DEFAULT_RETRY,
                        help=f"Tentatives max par batch (défaut: {DEFAULT_RETRY})")
    parser.add_argument("--supabase-url",  default="",
                        help="URL Supabase (surcharge SUPABASE_URL)")
    parser.add_argument("--supabase-key",  default="",
                        help="Clé Supabase (surcharge SUPABASE_KEY)")
    parser.add_argument("--verify",        action="store_true",
                        help="Vérification post-import (compte les lignes)")

    args = parser.parse_args()

    # Charger les vars d'environnement
    load_env()

    supabase_url = args.supabase_url or os.environ.get("SUPABASE_URL", "")
    supabase_key = args.supabase_key or os.environ.get("SUPABASE_KEY", "")

    # Header
    log.info("=" * 60)
    log.info("🚀 FlyAI — Import Supabase")
    log.info(f"   Fichier  : {args.file}")
    log.info(f"   Table    : {args.table}")
    log.info(f"   Batch    : {args.batch_size}")
    log.info(f"   Dry run  : {args.dry_run}")
    log.info(f"   Actives  : {args.active_only}")
    log.info(f"   Min score: {args.min_score}")
    log.info("=" * 60)

    stats = run_import(
        source_file    = args.file,
        table          = args.table,
        batch_size     = args.batch_size,
        dry_run        = args.dry_run,
        active_only    = args.active_only,
        min_score      = args.min_score,
        resume_from    = args.resume_from,
        delete_orphans = args.delete_orphans,
        supabase_url   = supabase_url,
        supabase_key   = supabase_key,
        max_retries    = args.max_retries,
    )

    # Vérification post-import
    if args.verify and not args.dry_run and stats.get("ok", 0) > 0:
        try:
            from supabase import create_client
            client = create_client(supabase_url, supabase_key)
            verify_import(client, args.table, stats["ok"])
        except Exception as e:
            log.warning(f"Vérification ignorée : {e}")

    # Code de sortie
    sys.exit(0 if stats.get("failed", 0) == 0 else 1)


if __name__ == "__main__":
    main()
