"""
Convertit une ligne CSV brute (format Fly AI actuel) vers ScholarshipModel.
"""
from __future__ import annotations
import ast
import re
from datetime import datetime
from typing import Any

from models.scholarship import ScholarshipModel, FUNDING_MAP, DEGREE_MAP
from parsers.deadline_parser import parse_deadline


def _safe_json(value: Any, fallback: Any = None) -> Any:
    if value is None or (isinstance(value, float) and value != value):
        return fallback if fallback is not None else []
    if isinstance(value, (list, dict)):
        return value
    try:
        return ast.literal_eval(str(value))
    except Exception:
        return fallback if fallback is not None else []


def _parse_country(pays_destination: Any) -> str:
    items = _safe_json(pays_destination, [])
    if not items:
        return "International"
    cleaned = [c.strip() for c in items if c.strip() and c.strip().lower() not in ("varies", "multiple")]
    return ", ".join(cleaned) if cleaned else "International"


def _parse_degree(niveau_etude: Any) -> str:
    levels = _safe_json(niveau_etude, [])
    if not levels:
        return "All Levels"
    canonical = []
    seen = set()
    for lvl in levels:
        mapped = DEGREE_MAP.get(str(lvl).strip().lower())
        if mapped and mapped not in seen:
            canonical.append(mapped)
            seen.add(mapped)
    return ", ".join(canonical) if canonical else "All Levels"


def _parse_funding(financement: str | None) -> str:
    if not financement:
        return "Unknown"
    return FUNDING_MAP.get(str(financement).strip().lower(), "Unknown")


def _parse_language_requirements(langues: Any) -> dict:
    items = _safe_json(langues, [])
    result = {}
    for lang in items:
        l = str(lang).strip().lower()
        if "english" in l or "anglais" in l:
            result["english"] = "required"
        elif "french" in l or "français" in l or "francais" in l:
            result["french"] = "required"
        else:
            result[lang] = "required"
    return result


def _parse_eligibility(nationalites: Any, africains: Any) -> dict:
    nats = _safe_json(nationalites, [])
    result: dict = {}
    if nats:
        result["nationalities"] = nats
    if africains is True or africains == "True":
        result["africans_eligible"] = True
    return result


def _compute_quality(row: dict) -> int:
    score = 0
    if row.get("deadline") or row.get("deadline_raw"):
        score += 15
    if row.get("universite"):
        score += 10
    if row.get("lien_candidature"):
        score += 15
    if row.get("description") and len(str(row.get("description", ""))) > 100:
        score += 10
    if row.get("image_url"):
        score += 5
    if _safe_json(row.get("domaines")):
        score += 10
    if _safe_json(row.get("criteres")):
        score += 10
    if _safe_json(row.get("avantages")):
        score += 10
    if row.get("financement") != "INCONNU":
        score += 10
    if _safe_json(row.get("langues_requises")):
        score += 5
    return min(score, 100)


def normalize_csv_row(row: dict) -> ScholarshipModel:
    """
    Convertit une ligne CSV brute → ScholarshipModel normalisé.
    Compatible avec le format actuel de bourses_rows.csv
    """
    ref_year = None
    if row.get("annee") and str(row["annee"]) != "nan":
        try:
            ref_year = int(float(row["annee"]))
        except (ValueError, TypeError):
            pass

    # Deadline : d'abord la colonne deadline parsée, sinon deadline_raw
    deadline_val = None
    raw_deadline = row.get("deadline_raw") or row.get("deadline")

    # La colonne `deadline` dans le CSV est la date ISO quand disponible
    if row.get("deadline") and str(row["deadline"]) not in ("nan", "", "None"):
        try:
            from datetime import date
            deadline_val = datetime.strptime(str(row["deadline"])[:10], "%Y-%m-%d").date()
        except Exception:
            pass

    if not deadline_val and raw_deadline:
        deadline_val = parse_deadline(str(raw_deadline), ref_year)

    s = ScholarshipModel(
        id=row.get("id") if str(row.get("id", "")).startswith("fly_") else None,
        source_id=row.get("id"),
        slug=row.get("slug"),
        title=str(row.get("titre", "")).strip(),
        university=row.get("universite") if row.get("universite") and str(row.get("universite")) != "nan" else None,
        country=_parse_country(row.get("pays_destination")),
        description=row.get("description") if row.get("description") and str(row.get("description")) != "nan" else None,
        funding_type=_parse_funding(row.get("financement")),
        degree_level=_parse_degree(row.get("niveau_etude")),
        fields=_safe_json(row.get("domaines"), []),
        eligibility=_parse_eligibility(row.get("nationalites_eligibles"), row.get("africains_eligibles")),
        requirements=_safe_json(row.get("criteres"), []),
        language_requirements=_parse_language_requirements(row.get("langues_requises")),
        benefits=_safe_json(row.get("avantages"), []),
        deadline=deadline_val,
        deadline_raw=str(raw_deadline) if raw_deadline and str(raw_deadline) != "nan" else None,
        application_url=row.get("lien_candidature") if row.get("lien_candidature") and str(row.get("lien_candidature")) != "nan" else None,
        source_url=row.get("url"),
        image_url=row.get("image_url") if row.get("image_url") and str(row.get("image_url")) != "nan" else None,
        source=row.get("source"),
        active=bool(row.get("active", True)),
        quality_score=_compute_quality(row),
    )
    s.refresh()
    return s
