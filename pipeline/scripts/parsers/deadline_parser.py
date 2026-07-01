"""
Parser de dates de deadline — gère tous les formats messy du CSV.
"""
from __future__ import annotations
import re
from datetime import date, datetime
from typing import Optional

import dateparser

FR_MONTHS = {
    "janvier": "january", "février": "february", "mars": "march",
    "avril": "april", "mai": "may", "juin": "june",
    "juillet": "july", "juil": "july", "août": "august",
    "septembre": "september", "octobre": "october",
    "novembre": "november", "décembre": "december",
}

# Strings trop longues ou non-parseable → None directement
NOISE_PATTERNS = [
    r"the last date to apply for",
    r"applications for the academic year",
    r"applications are reviewed in multiple rounds",
    r"applicants should always check",
    r"s application procedure",
    r"deadlines? vary",
]


def parse_deadline(raw: str | None, reference_year: int | None = None) -> Optional[date]:
    """
    Parse une deadline depuis un string brut vers un objet date Python.
    Retourne None si le string est vide, trop ambigu ou non parseable.
    """
    if not raw or not isinstance(raw, str):
        return None

    s = raw.strip()
    if not s:
        return None

    # Rejeter les strings clairement non-date (noise)
    sl = s.lower()
    for pattern in NOISE_PATTERNS:
        if re.search(pattern, sl):
            return None

    # Rejeter les textes trop longs (probablement du contenu HTML scraped)
    if len(s) > 80:
        return None

    # Noms de mois français → anglais
    for fr, en in FR_MONTHS.items():
        s = re.sub(fr, en, s, flags=re.I)

    # Supprimer les suffixes ordinaux : "31st" → "31", "2nd" → "2"
    s = re.sub(r"(\d+)(st|nd|rd|th)\.?", r"\1", s)

    # Supprimer le point final : "February 1." → "February 1"
    s = re.sub(r"\.$", "", s).strip()

    # Supprimer les préfixes de timezone : "23:59 Eastern Africa Time, 27 August 2026"
    s = re.sub(r"\d{1,2}:\d{2}\s+\w+(?:\s+\w+)*\s+Time,?\s*", "", s).strip()

    # Supprimer les virgules parasites : "7 June, 2026" → "7 June 2026"
    s = re.sub(r",\s*(\d{4})", r" \1", s)

    ref = reference_year or datetime.now().year
    settings = {
        "PREFER_DAY_OF_MONTH": "first",
        "PREFER_DATES_FROM": "future",
        "RELATIVE_BASE": datetime(ref, 1, 1),
        "RETURN_AS_TIMEZONE_AWARE": False,
    }

    parsed = dateparser.parse(s, settings=settings)
    return parsed.date() if parsed else None
