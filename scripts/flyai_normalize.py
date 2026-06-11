"""
╔══════════════════════════════════════════════════════════════════════════════╗
║  FlyAI — Pipeline de Normalisation & Fusion                                 ║
║  Sources : OFA · Greatyop · ScholarshipPositions · ScholarshipsAds          ║
║  Output  : JSON unifié + CSV Supabase-ready, avec déduplication & qualité   ║
╚══════════════════════════════════════════════════════════════════════════════╝

Usage :
    python flyai_normalize.py
    python flyai_normalize.py --input-dir ./data --output flyai_bourses.json
    python flyai_normalize.py --active-only
    python flyai_normalize.py --min-score 40
    python flyai_normalize.py --push-supabase
    python flyai_normalize.py --report

Schéma de sortie (table Supabase `bourses`) :
    id, titre, slug, url, source, sources_ids
    deadline, deadline_raw, date_publication, annee
    universite, pays_destination, lieu_etude
    niveau_etude, financement, montant_bourse
    domaines, langues_requises, nationalites_eligibles
    africains_eligibles, description, avantages, criteres
    lien_candidature, image_url, active
    qualite_score, qualite_details
    created_at, updated_at
"""

from __future__ import annotations

import re
import json
import csv
import hashlib
import logging
import argparse
import unicodedata
from copy import deepcopy
from datetime import datetime, date
from pathlib import Path
from typing import Any, Optional
from dataclasses import dataclass, field, asdict

# ─── Logging ──────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("flyai.normalize")

# ─── Chemins par défaut ────────────────────────────────────────────────────────

DEFAULT_INPUTS = {
    "ofa":      "bourses_ofa.json",
    "greatyop": "bourses_greatyop_v2.json",
    "sp":       "bourses_sp.json",
    "sa":       "bourses_sa.json",
}
DEFAULT_OUTPUT     = "flyai_bourses.json"
DEFAULT_OUTPUT_CSV = "flyai_bourses.csv"

# ─── Dictionnaires de normalisation ───────────────────────────────────────────

# Normalisation des pays (valeurs brutes trouvées dans les fichiers → standard ISO)
PAYS_MAP: dict[str, str] = {
    # Français → Anglais standard
    "allemagne": "Germany",     "france": "France",       "italie": "Italy",
    "espagne": "Spain",         "japon": "Japan",          "chine": "China",
    "corée du sud": "South Korea", "australie": "Australia", "inde": "India",
    "canada": "Canada",         "belgique": "Belgium",    "suisse": "Switzerland",
    "pays-bas": "Netherlands",  "suède": "Sweden",         "norvège": "Norway",
    "danemark": "Denmark",      "finlande": "Finland",     "autriche": "Austria",
    "malaisie": "Malaysia",     "singapour": "Singapore", "maroc": "Morocco",
    "tunisie": "Tunisia",       "sénégal": "Senegal",      "kenya": "Kenya",
    "ghana": "Ghana",           "nigeria": "Nigeria",      "afrique du sud": "South Africa",
    "états-unis": "USA",        "etats-unis": "USA",       "usa": "USA",
    "royaume-uni": "United Kingdom", "uk": "United Kingdom",
    "russie": "Russia",         "turquie": "Turkey",       "brésil": "Brazil",
    "mexique": "Mexico",        "argentine": "Argentina",
    "femmes africaines": "Africa",   # tag Greatyop
    "europe": "Europe",
    # Anglais variants
    "united states": "USA",     "united states of america": "USA",
    "u.s.": "USA",              "u.s.a.": "USA",           "america": "USA",
    "great britain": "United Kingdom", "england": "United Kingdom",
    "south korea": "South Korea", "republic of korea": "South Korea",
    "deutschland": "Germany",   "österreich": "Austria",
    "nederland": "Netherlands", "the netherlands": "Netherlands",
    "sverige": "Sweden",        "norge": "Norway",         "suomi": "Finland",
    "new zealand": "New Zealand",
    # Villes → pays (cas OFA)
    "athens": "Greece",         "berlin": "Germany",       "cape town": "South Africa",
    "capetown": "South Africa",  "nanjing": "China",       "beijing": "China",
    "tokyo": "Japan",           "paris": "France",         "rome": "Italy",
    "madrid": "Spain",          "amsterdam": "Netherlands",
    "rio de janeiro": "Brazil",
    # Bruit à supprimer (tags incorrects dans domaines/pays_destination)
    "health and safety": None,   "journalism": None,        "scholarships": None,
    "online": None,              "jrc ispra": None,
    "seed partner universities": None,
    "approximately 13 host universities in the united states": "USA",
    "american": "USA",
}

# Normalisation des domaines (fragments → catégorie FlyAI)
DOMAINE_MAP: dict[str, str] = {
    # Sciences exactes
    "computer science": "Informatique",       "computer": "Informatique",
    "information technology": "Informatique", "it ": "Informatique",
    "software": "Informatique",               "data science": "Data Science",
    "artificial intelligence": "Intelligence Artificielle", "ai ": "Intelligence Artificielle",
    "machine learning": "Intelligence Artificielle",
    "cybersecurity": "Cybersécurité",         "cyber": "Cybersécurité",
    "mathematics": "Mathématiques",           "maths": "Mathématiques",
    "statistics": "Statistiques",             "physics": "Physique",
    "chemistry": "Chimie",                    "biology": "Biologie",
    "biochemistry": "Biochimie",              "biotechnology": "Biotechnologie",
    "biotech": "Biotechnologie",
    # Ingénierie
    "engineering": "Ingénierie",              "ingenierie": "Ingénierie",
    "ingénierie": "Ingénierie",               "technologies information": "Informatique",
    "electrical": "Ingénierie Électrique",    "mechanical": "Ingénierie Mécanique",
    "civil engineering": "Génie Civil",       "chemical engineering": "Génie Chimique",
    "energy": "Énergie",                      "renewable": "Énergies Renouvelables",
    "sustainable": "Développement Durable",   "environment": "Environnement",
    "climate": "Climat & Environnement",      "agriculture": "Agriculture",
    # Médecine & Santé
    "medicine": "Médecine",                   "medical": "Médecine",
    "health": "Santé Publique",               "public health": "Santé Publique",
    "pharmacy": "Pharmacie",                  "nursing": "Soins Infirmiers",
    "sciences medicales": "Médecine",
    # Sciences sociales
    "economics": "Économie",                  "economie": "Économie",
    "finance": "Finance",                     "business": "Business & Gestion",
    "management": "Business & Gestion",       "mba": "Business & Gestion",
    "law": "Droit",                           "political science": "Sciences Politiques",
    "international relations": "Relations Internationales",
    "psychology": "Psychologie",              "sociology": "Sociologie",
    "social sciences": "Sciences Sociales",   "sciences sociales": "Sciences Sociales",
    # Lettres & Sciences Humaines
    "history": "Histoire",                    "philosophy": "Philosophie",
    "literature": "Littérature",              "arts": "Arts",
    "architecture": "Architecture",           "design": "Design",
    "media": "Médias & Communication",        "journalism": "Journalisme",
    "arts sciences humaines": "Sciences Humaines",
    # Éducation
    "education": "Éducation",                 "teaching": "Éducation",
    # Multi-domaines
    "all subjects": "Tous domaines",          "tous domaines": "Tous domaines",
    "all fields": "Tous domaines",            "any field": "Tous domaines",
    "engineering technology": "Ingénierie & Technologie",
    "ingenierie technologie": "Ingénierie & Technologie",
}

# Niveaux valides FlyAI
NIVEAUX_VALIDES = {"licence", "master", "doctorat", "postdoc", "recherche", "formation"}

# Mots-clés Afrique pour flag africains_eligibles
AFRICAN_KEYWORDS = {
    "africa", "african", "nigeria", "kenya", "ghana", "ethiopia", "tanzania",
    "senegal", "cameroon", "ivory coast", "togo", "benin", "mali", "niger",
    "rwanda", "uganda", "mozambique", "zambia", "zimbabwe", "south africa",
    "egypt", "morocco", "tunisia", "algeria", "congo", "sudan", "eritrea",
    "developing countries", "global south", "all nationalities",
    "all countries", "international students", "worldwide", "tous", "open to all",
    "femmes africaines",
}

# ─── Modèle unifié FlyAI ──────────────────────────────────────────────────────

@dataclass
class BourseFlyAI:
    # Identité
    id:                     str              = ""
    slug:                   str              = ""
    sources_ids:            dict             = field(default_factory=dict)  # {source: original_id}

    # Contenu principal
    titre:                  str              = ""
    description:            str              = ""
    url:                    str              = ""
    source:                 str              = ""
    sources:                list             = field(default_factory=list)  # toutes les sources si dédupliqué

    # Dates
    deadline:               Optional[str]    = None   # ISO YYYY-MM-DD
    deadline_raw:           str              = ""
    date_publication:       Optional[str]    = None
    annee:                  Optional[int]    = None

    # Institution
    universite:             str              = ""
    pays_destination:       list             = field(default_factory=list)
    lieu_etude:             str              = ""

    # Caractéristiques bourse
    niveau_etude:           list             = field(default_factory=list)
    financement:            str              = "INCONNU"  # TOTAL | PARTIEL | INCONNU
    montant_bourse:         str              = ""
    nb_bourses:             str              = ""

    # Éligibilité
    domaines:               list             = field(default_factory=list)
    langues_requises:       list             = field(default_factory=list)
    nationalites_eligibles: list             = field(default_factory=list)
    africains_eligibles:    bool             = False

    # Détails
    avantages:              list             = field(default_factory=list)
    criteres:               list             = field(default_factory=list)
    couverture:             list             = field(default_factory=list)
    lien_candidature:       str              = ""
    image_url:              str              = ""

    # Statut
    active:                 bool             = True

    # Score qualité (0–100)
    qualite_score:          int              = 0
    qualite_details:        dict             = field(default_factory=dict)

    # Métadonnées
    created_at:             str              = field(default_factory=lambda: datetime.utcnow().isoformat())
    updated_at:             str              = field(default_factory=lambda: datetime.utcnow().isoformat())


# ─── Utilitaires ──────────────────────────────────────────────────────────────

def slugify(text: str) -> str:
    """Convertit un titre en slug URL-safe."""
    text = unicodedata.normalize("NFKD", text)
    text = text.encode("ascii", "ignore").decode("ascii")
    text = re.sub(r"[^\w\s-]", "", text.lower())
    text = re.sub(r"[\s_-]+", "-", text)
    text = re.sub(r"^-+|-+$", "", text)
    return text[:100]


def make_flyai_id(url: str, titre: str) -> str:
    """ID stable SHA1 basé sur URL + titre."""
    raw = f"{url}||{titre.lower().strip()}"
    return "fly_" + hashlib.sha1(raw.encode()).hexdigest()[:14]


def clean(v: Any) -> str:
    """Nettoie une chaîne."""
    if not v:
        return ""
    return " ".join(str(v).strip().split())


def clean_list(lst: Any) -> list[str]:
    """Nettoie une liste, élimine les vides."""
    if not lst:
        return []
    if isinstance(lst, str):
        lst = [lst]
    return [clean(x) for x in lst if clean(x)]


def normalize_pays(raw_list: list) -> list[str]:
    """
    Normalise la liste des pays :
    - Traduit FR→EN
    - Supprime le bruit (villes mal classées comme domaines, tags incorrects)
    - Déduplique
    """
    result = []
    for raw in (raw_list or []):
        if not raw:
            continue
        key = str(raw).lower().strip()

        # Chercher dans le mapping (exact)
        if key in PAYS_MAP:
            mapped = PAYS_MAP[key]
            if mapped and mapped not in result:
                result.append(mapped)
            continue

        # Chercher une correspondance partielle (pour cas composés)
        matched = False
        for pat, val in PAYS_MAP.items():
            if pat in key:
                if val and val not in result:
                    result.append(val)
                matched = True
                break

        if not matched:
            # Garder si ça ressemble à un pays (commence par majuscule, < 40 chars)
            cleaned = clean(raw)
            if (cleaned and len(cleaned) < 40
                    and cleaned[0].isupper()
                    and not re.search(r"\d{4}|\$|%|\.com", cleaned)):
                if cleaned not in result:
                    result.append(cleaned)

    return result[:10]


def normalize_domaines(raw_list: list) -> list[str]:
    """
    Normalise les domaines en catégories FlyAI standard.
    Élimine le bruit (IDs, montants, dates qui se retrouvent dans domaines de SA).
    """
    result = []

    for raw in (raw_list or []):
        if not raw:
            continue
        text = str(raw).strip()

        # Filtres de bruit (SA a des artefacts dans domaines)
        if re.search(r"\$\d+|\d{4}-\d{2}-\d{2}|\d+ weeks?|\d+ months?", text):
            continue
        if re.search(r"\.com|\.org|\.edu|http", text):
            continue
        if len(text) > 80:  # Description parasite
            continue
        if re.match(r"^\d", text):  # Commence par un chiffre = montant ou date
            continue

        # Chercher dans le mapping domaines
        text_lower = text.lower()
        mapped = None
        for pat, cat in DOMAINE_MAP.items():
            if pat in text_lower:
                mapped = cat
                break

        if mapped:
            if mapped not in result:
                result.append(mapped)
        else:
            # Garder si raisonnable (propre, < 50 chars, pas de chiffres dominants)
            if (len(text) < 50
                    and text[0].isupper()
                    and not re.search(r"\d{3,}", text)
                    and text not in result):
                result.append(text)

    return result[:8]


def normalize_niveaux(raw_list: list) -> list[str]:
    """Filtre pour ne garder que les niveaux valides FlyAI."""
    if not raw_list:
        return []
    return [n for n in raw_list if n in NIVEAUX_VALIDES]


def normalize_financement(raw: str) -> str:
    """Normalise financement : TOTAL | PARTIEL | INCONNU."""
    if not raw:
        return "INCONNU"
    r = str(raw).upper().strip()
    if r == "TOTAL":
        return "TOTAL"
    if r == "PARTIEL":
        return "PARTIEL"
    return "INCONNU"


def normalize_deadline(raw: Optional[str], raw_text: str = "") -> Optional[str]:
    """Valide et normalise la deadline en ISO YYYY-MM-DD."""
    if raw and re.match(r"^\d{4}-\d{2}-\d{2}$", str(raw)):
        year = int(str(raw)[:4])
        if 2020 <= year <= 2040:
            return str(raw)
        return None
    # Essayer de parser depuis raw_text
    if raw_text:
        MONTH_MAP = {
            "january":"01","february":"02","march":"03","april":"04",
            "may":"05","june":"06","july":"07","august":"08",
            "september":"09","october":"10","november":"11","december":"12",
            "jan":"01","feb":"02","mar":"03","apr":"04","jun":"06",
            "jul":"07","aug":"08","sep":"09","oct":"10","nov":"11","dec":"12",
        }
        text = raw_text.lower().strip()
        # "31 october 2026"
        m = re.search(r"(\d{1,2})\s+(\w+)\s+(\d{4})", text)
        if m:
            d, mo, y = m.groups()
            month = MONTH_MAP.get(mo)
            if month and 2020 <= int(y) <= 2035:
                return f"{y}-{month}-{d.zfill(2)}"
        # "october 31, 2026"
        m = re.search(r"(\w+)\s+(\d{1,2})[,\s]+(\d{4})", text)
        if m:
            mo, d, y = m.groups()
            month = MONTH_MAP.get(mo)
            if month and 2020 <= int(y) <= 2035:
                return f"{y}-{month}-{d.zfill(2)}"
    return None


def detect_africains_eligibles(record: dict) -> bool:
    """
    Détecte si les Africains sont éligibles en analysant plusieurs champs.
    Règle : True si nationalites_eligibles contient "Tous" OU si keywords africains présents.
    """
    # Champ direct (SA)
    if record.get("africains_eligibles") is True:
        return True

    # "Tous" nationalities = ouvert à tous
    nats = record.get("nationalites_eligibles") or []
    if any("tous" in str(n).lower() or "all" in str(n).lower() for n in nats):
        return True

    # Analyser description + critères + titre
    combined = " ".join([
        str(record.get("titre", "")),
        str(record.get("description", "")),
        " ".join(str(x) for x in (record.get("criteres") or [])),
        " ".join(str(x) for x in (record.get("nationalites_eligibles") or [])),
        " ".join(str(x) for x in (record.get("pays_destination") or [])),
        str(record.get("ouvert_pour", "")),  # Greatyop-specific
    ]).lower()

    return any(kw in combined for kw in AFRICAN_KEYWORDS)


def extract_montant(record: dict) -> str:
    """Extrait un montant de bourse depuis avantages/couverture/description."""
    for field in ["avantages", "couverture", "criteres"]:
        for item in (record.get(field) or []):
            m = re.search(r"([\$€£][\d,]+|\d[\d,]+\s*(?:USD|EUR|GBP|€|\$))", str(item))
            if m:
                return m.group(0)
    # Chercher dans description
    m = re.search(
        r"([\$€£][\d,]+(?:\s*(?:per month|monthly|per year|annually))?)",
        str(record.get("description", "")), re.I
    )
    if m:
        return m.group(0)
    return ""


def extract_annee(titre: str, deadline: Optional[str]) -> Optional[int]:
    """Extrait l'année depuis le titre ou la deadline."""
    if titre:
        m = re.search(r"\b(202[4-9]|203\d)\b", titre)
        if m:
            return int(m.group(0))
    if deadline and len(deadline) >= 4:
        try:
            return int(deadline[:4])
        except ValueError:
            pass
    return None


def is_active(deadline: Optional[str], active_raw: Any) -> bool:
    """Détermine si la bourse est active."""
    if deadline:
        try:
            dl = datetime.fromisoformat(deadline).date()
            return dl >= date.today()
        except ValueError:
            pass
    # Fallback : utiliser le flag original
    return bool(active_raw)


def deduplicate(bourses: list[BourseFlyAI], similarity_threshold: float = 0.85) -> list[BourseFlyAI]:
    """
    Déduplication multi-stratégie :
    1. URL exacte
    2. Titre normalisé (Levenshtein approximatif par tokens)
    Fusionne les enregistrements dupliqués en préservant le meilleur de chaque source.
    """
    log.info("Déduplication en cours...")

    # ── Étape 1 : déduplication par URL exacte ────────────────────────────────
    by_url: dict[str, BourseFlyAI] = {}
    for b in bourses:
        url = b.url.rstrip("/").lower()
        if url not in by_url:
            by_url[url] = b
        else:
            # Fusionner : garder le meilleur de chaque
            existing = by_url[url]
            by_url[url] = _merge(existing, b)

    after_url = list(by_url.values())
    log.info(f"  Après dédup URL : {len(bourses)} → {len(after_url)}")

    # ── Étape 2 : déduplication par titre normalisé ───────────────────────────
    def normalize_titre(t: str) -> str:
        """Normalise un titre pour comparaison."""
        t = unicodedata.normalize("NFKD", t.lower())
        t = t.encode("ascii", "ignore").decode("ascii")
        t = re.sub(r"[^\w\s]", " ", t)
        # Supprimer les années et mots trop génériques
        t = re.sub(r"\b(20\d{2}|scholarship|bourse|funded|fully|apply|now)\b", "", t)
        return " ".join(t.split())

    def titre_similarity(a: str, b: str) -> float:
        """Similarité basée sur le ratio de tokens communs (Jaccard)."""
        ta = set(normalize_titre(a).split())
        tb = set(normalize_titre(b).split())
        if not ta or not tb:
            return 0.0
        intersection = ta & tb
        union = ta | tb
        return len(intersection) / len(union)

    # Index par token principal (3 premiers mots du titre normalisé)
    deduped: list[BourseFlyAI] = []
    titre_index: dict[str, list[int]] = {}  # token → indices dans deduped

    for b in after_url:
        tokens = normalize_titre(b.titre).split()[:3]
        key = " ".join(tokens)

        # Chercher parmi les candidats du même cluster de tokens
        candidates = titre_index.get(key, [])
        found_dup = False

        for idx in candidates:
            existing = deduped[idx]
            sim = titre_similarity(b.titre, existing.titre)
            if sim >= similarity_threshold:
                # Fusionner
                deduped[idx] = _merge(existing, b)
                found_dup = True
                break

        if not found_dup:
            idx = len(deduped)
            deduped.append(b)
            # Indexer sous plusieurs clés de tokens
            for n in range(1, len(tokens) + 1):
                k = " ".join(tokens[:n])
                titre_index.setdefault(k, []).append(idx)

    log.info(f"  Après dédup titre : {len(after_url)} → {len(deduped)}")
    return deduped


def _merge(a: BourseFlyAI, b: BourseFlyAI) -> BourseFlyAI:
    """
    Fusionne deux enregistrements en préservant les meilleures valeurs.
    Stratégie : champ non vide > champ vide, liste plus longue > liste courte.
    """
    merged = deepcopy(a)

    # sources_ids : fusionner les deux dicts
    merged.sources_ids.update(b.sources_ids)

    # sources : union des deux listes
    for s in b.sources:
        if s not in merged.sources:
            merged.sources.append(s)

    # Champs scalaires : prendre b si a est vide/inconnu
    for field_name in ["universite", "lieu_etude", "description",
                        "lien_candidature", "image_url", "deadline_raw",
                        "montant_bourse", "nb_bourses", "annee"]:
        val_a = getattr(merged, field_name)
        val_b = getattr(b, field_name)
        if (not val_a or val_a in ["", "NA", "INCONNU"]) and val_b:
            setattr(merged, field_name, val_b)

    # deadline : prendre la plus récente (et la non-None)
    if not merged.deadline and b.deadline:
        merged.deadline = b.deadline
    elif merged.deadline and b.deadline:
        # Garder la deadline la plus éloignée (la moins passée)
        try:
            d_a = datetime.fromisoformat(merged.deadline)
            d_b = datetime.fromisoformat(b.deadline)
            if d_b > d_a:
                merged.deadline = b.deadline
        except ValueError:
            pass

    # financement : TOTAL > PARTIEL > INCONNU
    fin_rank = {"TOTAL": 2, "PARTIEL": 1, "INCONNU": 0}
    if fin_rank.get(b.financement, 0) > fin_rank.get(merged.financement, 0):
        merged.financement = b.financement

    # Listes : union dédupliquée
    for field_name in ["pays_destination", "niveau_etude", "domaines",
                        "langues_requises", "nationalites_eligibles",
                        "avantages", "criteres", "couverture"]:
        list_a = getattr(merged, field_name) or []
        list_b = getattr(b, field_name) or []
        combined = list(dict.fromkeys(list_a + [x for x in list_b if x not in list_a]))
        setattr(merged, field_name, combined)

    # africains_eligibles : True si l'un des deux est True
    if b.africains_eligibles:
        merged.africains_eligibles = True

    # active : True si l'un des deux est True (sauf si deadline passée)
    merged.active = is_active(merged.deadline, merged.active or b.active)

    merged.updated_at = datetime.utcnow().isoformat()
    return merged


# ─── Score de Qualité ─────────────────────────────────────────────────────────

def compute_quality_score(b: BourseFlyAI) -> tuple[int, dict]:
    """
    Score de qualité sur 100 points.
    Critères alignés sur les besoins du matching FlyAI.

    Barème :
        titre non-vide                   :  5 pts (obligatoire)
        url non-vide                     :  5 pts (obligatoire)
        description ≥ 100 chars          : 10 pts
        deadline présente et future      : 15 pts
        deadline présente mais passée    :  5 pts
        pays_destination non-vide        : 10 pts
        université renseignée            :  8 pts
        niveau_etude non-vide            :  8 pts
        financement != INCONNU           : 10 pts
        domaines non-vides               :  8 pts
        nationalites_eligibles           :  5 pts
        avantages ou couverture          :  5 pts
        criteres non-vides               :  5 pts
        lien_candidature valide          :  8 pts
        image_url non-vide               :  3 pts
        langues_requises                 :  2 pts
        ────────────────────────────────  ────
        TOTAL                            : 107 pts → normalisé sur 100
    """
    points = 0
    details = {}

    # Titre
    if b.titre and len(b.titre) > 10:
        points += 5; details["titre"] = 5
    else:
        details["titre"] = 0

    # URL
    if b.url and b.url.startswith("http"):
        points += 5; details["url"] = 5
    else:
        details["url"] = 0

    # Description
    if len(b.description) >= 200:
        points += 10; details["description"] = 10
    elif len(b.description) >= 80:
        points += 5;  details["description"] = 5
    else:
        details["description"] = 0

    # Deadline
    if b.deadline:
        try:
            dl = datetime.fromisoformat(b.deadline).date()
            if dl >= date.today():
                points += 15; details["deadline"] = 15   # Future = maximum
            else:
                points += 5;  details["deadline"] = 5    # Passée = partiel
        except ValueError:
            points += 3;  details["deadline"] = 3         # Format invalide
    else:
        details["deadline"] = 0

    # Pays destination
    if b.pays_destination:
        points += 10; details["pays_destination"] = 10
    else:
        details["pays_destination"] = 0

    # Université
    if b.universite and len(b.universite) > 5:
        points += 8; details["universite"] = 8
    else:
        details["universite"] = 0

    # Niveau étude
    if b.niveau_etude:
        points += 8; details["niveau_etude"] = 8
    else:
        details["niveau_etude"] = 0

    # Financement
    if b.financement == "TOTAL":
        points += 10; details["financement"] = 10
    elif b.financement == "PARTIEL":
        points += 6;  details["financement"] = 6
    else:
        details["financement"] = 0

    # Domaines
    if len(b.domaines) >= 3:
        points += 8; details["domaines"] = 8
    elif b.domaines:
        points += 4; details["domaines"] = 4
    else:
        details["domaines"] = 0

    # Nationalités
    if b.nationalites_eligibles:
        points += 5; details["nationalites"] = 5
    else:
        details["nationalites"] = 0

    # Avantages / Couverture
    if b.avantages or b.couverture:
        points += 5; details["avantages"] = 5
    else:
        details["avantages"] = 0

    # Critères
    if len(b.criteres) >= 2:
        points += 5; details["criteres"] = 5
    elif b.criteres:
        points += 2; details["criteres"] = 2
    else:
        details["criteres"] = 0

    # Lien candidature
    if b.lien_candidature and b.lien_candidature.startswith("http"):
        points += 8; details["lien_candidature"] = 8
    else:
        details["lien_candidature"] = 0

    # Image
    if b.image_url and b.image_url.startswith("http"):
        points += 3; details["image_url"] = 3
    else:
        details["image_url"] = 0

    # Langues
    if b.langues_requises:
        points += 2; details["langues"] = 2
    else:
        details["langues"] = 0

    # Normalisé sur 100 (max théorique = 107)
    score = min(100, round(points * 100 / 107))
    return score, details


# ─── Normalisation par source ─────────────────────────────────────────────────

def normalize_record(record: dict, source_name: str) -> BourseFlyAI:
    """
    Normalise un enregistrement brut vers le schéma BourseFlyAI unifié.
    Gère les particularités de chaque source.
    """
    b = BourseFlyAI()

    # ── Identité ──────────────────────────────────────────────────────────────
    b.titre    = clean(record.get("titre", ""))
    b.url      = clean(record.get("url", ""))
    b.slug     = slugify(b.titre)
    b.id       = make_flyai_id(b.url, b.titre)
    b.source   = record.get("source", source_name)
    b.sources  = [b.source]
    b.sources_ids = {b.source: record.get("id", "")}

    # ── Description ───────────────────────────────────────────────────────────
    b.description = clean(record.get("description", ""))

    # ── Dates ────────────────────────────────────────────────────────────────
    b.deadline_raw = clean(record.get("deadline_raw", ""))
    b.deadline     = normalize_deadline(record.get("deadline"), b.deadline_raw)
    raw_pub = record.get("date_publication", "")
    b.date_publication = clean(raw_pub)[:25] if raw_pub else None

    # annee : depuis record direct, titre, ou deadline
    b.annee = record.get("annee") or extract_annee(b.titre, b.deadline)

    # ── Institution & localisation ────────────────────────────────────────────
    b.universite = clean(record.get("universite", ""))
    # Tronquer les universités trop verbeuses (artefact SA)
    if len(b.universite) > 120:
        b.universite = b.universite[:120] + "…"

    b.pays_destination = normalize_pays(record.get("pays_destination") or [])
    b.lieu_etude = clean(record.get("lieu_etude", ""))

    # Fallback pays depuis lieu_etude
    if not b.pays_destination and b.lieu_etude:
        b.pays_destination = normalize_pays([b.lieu_etude])

    # ── Caractéristiques bourse ───────────────────────────────────────────────
    b.niveau_etude = normalize_niveaux(record.get("niveau_etude") or [])
    b.financement  = normalize_financement(record.get("financement", ""))
    b.nb_bourses   = clean(record.get("nb_bourses", ""))
    b.montant_bourse = extract_montant(record)

    # couverture (champ SA) → fusionner dans avantages
    b.couverture = clean_list(record.get("couverture") or [])
    b.avantages  = clean_list(record.get("avantages") or [])

    # ── Éligibilité ───────────────────────────────────────────────────────────
    b.domaines              = normalize_domaines(record.get("domaines") or [])
    b.langues_requises      = clean_list(record.get("langues_requises") or [])
    b.nationalites_eligibles = clean_list(record.get("nationalites_eligibles") or [])
    b.criteres              = clean_list(record.get("criteres") or [])
    b.africains_eligibles   = detect_africains_eligibles(record)

    # ── Liens & média ─────────────────────────────────────────────────────────
    b.lien_candidature = clean(record.get("lien_candidature", ""))
    b.image_url        = clean(record.get("image_url", ""))

    # ── Statut actif ──────────────────────────────────────────────────────────
    b.active = is_active(b.deadline, record.get("active", True))

    # ── Spécifiques sources ───────────────────────────────────────────────────
    # SP : departement → complément universite si vide
    if source_name == "sp":
        dept = clean(record.get("departement", ""))
        if dept and not b.universite:
            b.universite = dept
        # categories_sp → enrichir domaines si vide
        if not b.domaines:
            cats = record.get("categories_sp") or []
            filtered = [c for c in cats
                        if c not in {"International Scholarships for Students",
                                      "October Scholarships", "June Scholarships",
                                      "July Scholarships", "August Scholarships",
                                      "September Scholarships", "Postgraduate Scholarships"}]
            b.domaines = normalize_domaines(filtered[:4])

    # Greatyop : ouvert_pour → nationalites_eligibles si vide
    if source_name == "greatyop":
        ouvert = clean(record.get("ouvert_pour", ""))
        if ouvert and not b.nationalites_eligibles:
            b.nationalites_eligibles = [ouvert]
        # jours_restants → enrichir actif
        jours = record.get("jours_restants")
        if isinstance(jours, (int, float)) and jours > 0:
            b.active = True

    # SA : programme → complément titre si très court
    if source_name == "sa":
        prog = clean(record.get("programme", ""))
        if prog and len(b.titre) < 20:
            b.titre = prog
        # tags_sa → si domaines vides
        if not b.domaines:
            tags = record.get("tags_sa") or []
            b.domaines = normalize_domaines(tags)

    return b


# ─── Pipeline principal ───────────────────────────────────────────────────────

def load_source(path: Path, source_name: str) -> list[BourseFlyAI]:
    """Charge et normalise un fichier source."""
    if not path.exists():
        log.warning(f"Fichier introuvable : {path}")
        return []

    with open(path, encoding="utf-8") as f:
        data = json.load(f)

    if not isinstance(data, list):
        log.warning(f"{path.name} : format inattendu (attendu: liste)")
        return []

    bourses = []
    errors = 0
    for i, record in enumerate(data):
        try:
            b = normalize_record(record, source_name)
            if b.titre and b.url:  # Filtre minimal de validité
                bourses.append(b)
        except Exception as e:
            log.warning(f"  [{source_name}] Record {i} ignoré : {e}")
            errors += 1

    log.info(f"[{source_name}] {len(bourses)}/{len(data)} records normalisés ({errors} erreurs)")
    return bourses


def run_pipeline(
    input_files: dict[str, Path],
    output_json: Path,
    output_csv: Path,
    active_only: bool = False,
    min_score: int = 0,
    africains_only: bool = False,
    push_supabase: bool = False,
    supabase_url: str = "",
    supabase_key: str = "",
    supabase_table: str = "bourses",
) -> list[BourseFlyAI]:
    """Pipeline complet : load → normalize → deduplicate → score → export."""

    log.info("=" * 65)
    log.info("🚀 FlyAI — Pipeline de Normalisation")
    log.info("=" * 65)

    # ── Phase 1 : Chargement & normalisation ──────────────────────────────────
    log.info("\n📥 Phase 1 — Chargement & normalisation des sources")
    all_bourses: list[BourseFlyAI] = []
    source_counts = {}

    for source_name, path in input_files.items():
        bourses = load_source(path, source_name)
        source_counts[source_name] = len(bourses)
        all_bourses.extend(bourses)

    log.info(f"\n  Total avant déduplication : {len(all_bourses)}")

    # ── Phase 2 : Déduplication ───────────────────────────────────────────────
    log.info("\n🔀 Phase 2 — Déduplication multi-stratégie")
    all_bourses = deduplicate(all_bourses)
    log.info(f"  Total après déduplication : {len(all_bourses)}")

    # ── Phase 3 : Score qualité ───────────────────────────────────────────────
    log.info("\n📊 Phase 3 — Calcul des scores de qualité")
    for b in all_bourses:
        b.qualite_score, b.qualite_details = compute_quality_score(b)

    # ── Phase 4 : Filtres ─────────────────────────────────────────────────────
    log.info("\n🔧 Phase 4 — Application des filtres")
    before = len(all_bourses)

    if active_only:
        all_bourses = [b for b in all_bourses if b.active]
        log.info(f"  Filtre actives : {before} → {len(all_bourses)}")
        before = len(all_bourses)

    if africains_only:
        all_bourses = [b for b in all_bourses if b.africains_eligibles]
        log.info(f"  Filtre Africains : {before} → {len(all_bourses)}")
        before = len(all_bourses)

    if min_score > 0:
        all_bourses = [b for b in all_bourses if b.qualite_score >= min_score]
        log.info(f"  Filtre score ≥ {min_score} : {before} → {len(all_bourses)}")

    # Tri : score desc, deadline asc
    all_bourses.sort(
        key=lambda b: (
            -b.qualite_score,
            b.deadline or "9999-12-31",
        )
    )

    # ── Phase 5 : Export JSON ─────────────────────────────────────────────────
    log.info(f"\n💾 Phase 5 — Export vers {output_json}")
    output_data = []
    for b in all_bourses:
        d = asdict(b)
        # Convertir qualite_details en JSON string pour Supabase (jsonb)
        output_data.append(d)

    with open(output_json, "w", encoding="utf-8") as f:
        json.dump(output_data, f, ensure_ascii=False, indent=2, default=str)
    log.info(f"  ✅ {len(output_data)} bourses → {output_json}")

    # ── Phase 6 : Export CSV (Supabase bulk import) ───────────────────────────
    log.info(f"\n📋 Phase 6 — Export CSV → {output_csv}")
    _export_csv(all_bourses, output_csv)

    # ── Phase 7 : Push Supabase (optionnel) ──────────────────────────────────
    if push_supabase:
        log.info(f"\n☁️  Phase 7 — Push Supabase ({supabase_table})")
        _push_supabase(all_bourses, supabase_url, supabase_key, supabase_table)

    # ── Rapport final ─────────────────────────────────────────────────────────
    _print_report(all_bourses, source_counts)

    return all_bourses


def _export_csv(bourses: list[BourseFlyAI], path: Path) -> None:
    """
    Export CSV Supabase-compatible.
    Les champs liste/dict sont sérialisés en JSON pour les colonnes JSONB.
    """
    if not bourses:
        return

    # Colonnes Supabase (ordre recommandé)
    COLUMNS = [
        "id", "slug", "titre", "url", "source", "sources",
        "deadline", "deadline_raw", "date_publication", "annee",
        "universite", "pays_destination", "lieu_etude",
        "niveau_etude", "financement", "montant_bourse", "nb_bourses",
        "domaines", "langues_requises", "nationalites_eligibles",
        "africains_eligibles", "description", "avantages", "criteres",
        "couverture", "lien_candidature", "image_url", "active",
        "qualite_score", "sources_ids",
        "created_at", "updated_at",
    ]

    # Champs qui doivent être JSON dans Supabase (type jsonb ou text[])
    JSON_FIELDS = {
        "sources", "pays_destination", "niveau_etude", "domaines",
        "langues_requises", "nationalites_eligibles", "avantages",
        "criteres", "couverture", "sources_ids",
    }

    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=COLUMNS, extrasaction="ignore")
        writer.writeheader()

        for b in bourses:
            d = asdict(b)
            row = {}
            for col in COLUMNS:
                val = d.get(col, "")
                if col in JSON_FIELDS:
                    row[col] = json.dumps(val, ensure_ascii=False)
                elif isinstance(val, bool):
                    row[col] = str(val).lower()  # "true"/"false" pour Postgres
                elif val is None:
                    row[col] = ""
                else:
                    row[col] = str(val)
            writer.writerow(row)

    log.info(f"  ✅ {len(bourses)} lignes → {path}")


def _push_supabase(
    bourses: list[BourseFlyAI],
    url: str,
    key: str,
    table: str,
    batch_size: int = 100,
) -> None:
    """
    Push vers Supabase en batches avec upsert (clé: id).
    Nécessite : pip install supabase
    """
    try:
        from supabase import create_client
    except ImportError:
        log.error("pip install supabase requis pour --push-supabase")
        return

    if not url or not key:
        log.error("SUPABASE_URL et SUPABASE_KEY requis (env vars)")
        return

    client = create_client(url, key)
    total = 0

    for i in range(0, len(bourses), batch_size):
        batch = bourses[i:i + batch_size]
        data = []
        for b in batch:
            d = asdict(b)
            # Nettoyer les champs non présents dans le schéma Supabase
            d.pop("qualite_details", None)
            data.append(d)

        try:
            client.table(table).upsert(data, on_conflict="id").execute()
            total += len(batch)
            log.info(f"  Batch {i//batch_size + 1} : {len(batch)} records → OK")
        except Exception as e:
            log.error(f"  Erreur batch {i//batch_size + 1} : {e}")

    log.info(f"  ✅ {total}/{len(bourses)} bourses → Supabase({table})")


def _print_report(bourses: list[BourseFlyAI], source_counts: dict) -> None:
    """Rapport complet du pipeline."""
    total = len(bourses)
    if not total:
        log.info("Aucune bourse à rapporter.")
        return

    active    = sum(1 for b in bourses if b.active)
    funded    = sum(1 for b in bourses if b.financement == "TOTAL")
    partial   = sum(1 for b in bourses if b.financement == "PARTIEL")
    africains = sum(1 for b in bourses if b.africains_eligibles)
    with_dl   = sum(1 for b in bourses if b.deadline)
    with_pays = sum(1 for b in bourses if b.pays_destination)
    with_uni  = sum(1 for b in bourses if b.universite)
    with_dom  = sum(1 for b in bourses if b.domaines)
    with_crit = sum(1 for b in bourses if b.criteres)
    with_link = sum(1 for b in bourses if b.lien_candidature)

    # Distribution niveaux
    niv_count = {}
    for b in bourses:
        for n in b.niveau_etude:
            niv_count[n] = niv_count.get(n, 0) + 1

    # Distribution scores
    scores = [b.qualite_score for b in bourses]
    avg_score = sum(scores) // len(scores) if scores else 0
    high_q    = sum(1 for s in scores if s >= 70)
    med_q     = sum(1 for s in scores if 40 <= s < 70)
    low_q     = sum(1 for s in scores if s < 40)

    # Top pays
    pays_count = {}
    for b in bourses:
        for p in b.pays_destination:
            pays_count[p] = pays_count.get(p, 0) + 1
    top_pays = sorted(pays_count.items(), key=lambda x: -x[1])[:8]

    # Top domaines
    dom_count = {}
    for b in bourses:
        for d in b.domaines:
            dom_count[d] = dom_count.get(d, 0) + 1
    top_dom = sorted(dom_count.items(), key=lambda x: -x[1])[:8]

    print("\n" + "=" * 65)
    print("📊 FlyAI — RAPPORT PIPELINE NORMALISATION")
    print("=" * 65)
    print(f"\n📥 SOURCES :")
    for src, count in source_counts.items():
        print(f"   {src:25s} : {count} records")
    print(f"   {'TOTAL avant dédup':25s} : {sum(source_counts.values())}")
    print(f"   {'TOTAL après dédup':25s} : {total}")

    print(f"\n📈 COUVERTURE :")
    print(f"   Actives              : {active} ({active*100//total}%)")
    print(f"   Entièrement financées: {funded} ({funded*100//total}%)")
    print(f"   Partiellement fin.   : {partial} ({partial*100//total}%)")
    print(f"   Africains éligibles  : {africains} ({africains*100//total}%)")
    print(f"   Avec deadline        : {with_dl} ({with_dl*100//total}%)")
    print(f"   Avec pays d'étude    : {with_pays} ({with_pays*100//total}%)")
    print(f"   Avec université      : {with_uni} ({with_uni*100//total}%)")
    print(f"   Avec domaines        : {with_dom} ({with_dom*100//total}%)")
    print(f"   Avec critères        : {with_crit} ({with_crit*100//total}%)")
    print(f"   Avec lien candidature: {with_link} ({with_link*100//total}%)")

    print(f"\n🎓 NIVEAUX D'ÉTUDES :")
    for niv, cnt in sorted(niv_count.items(), key=lambda x: -x[1]):
        print(f"   {niv:12s} : {cnt}")

    print(f"\n⭐ QUALITÉ (score /100) :")
    print(f"   Score moyen          : {avg_score}")
    print(f"   ≥ 70 (haute qualité) : {high_q} ({high_q*100//total}%)")
    print(f"   40–69 (qualité moy.) : {med_q} ({med_q*100//total}%)")
    print(f"   < 40 (à enrichir)    : {low_q} ({low_q*100//total}%)")

    print(f"\n🌍 TOP PAYS D'ÉTUDE :")
    for pays, cnt in top_pays:
        print(f"   {pays:25s} : {cnt}")

    print(f"\n📚 TOP DOMAINES :")
    for dom, cnt in top_dom:
        print(f"   {dom:30s} : {cnt}")

    print("\n" + "=" * 65)


# ─── Schéma SQL Supabase ──────────────────────────────────────────────────────

SUPABASE_SQL = """
-- ============================================================
-- FlyAI — Schéma Supabase : table bourses
-- ============================================================
-- Exécuter dans SQL Editor de Supabase

CREATE TABLE IF NOT EXISTS public.bourses (
    -- Identité
    id                      TEXT PRIMARY KEY,
    slug                    TEXT NOT NULL,
    titre                   TEXT NOT NULL,
    url                     TEXT NOT NULL,
    source                  TEXT,
    sources                 JSONB DEFAULT '[]',
    sources_ids             JSONB DEFAULT '{}',

    -- Dates
    deadline                DATE,
    deadline_raw            TEXT,
    date_publication        TEXT,
    annee                   INTEGER,

    -- Institution
    universite              TEXT,
    pays_destination        JSONB DEFAULT '[]',
    lieu_etude              TEXT,

    -- Caractéristiques
    niveau_etude            JSONB DEFAULT '[]',
    financement             TEXT CHECK (financement IN ('TOTAL', 'PARTIEL', 'INCONNU')),
    montant_bourse          TEXT,
    nb_bourses              TEXT,

    -- Éligibilité
    domaines                JSONB DEFAULT '[]',
    langues_requises        JSONB DEFAULT '[]',
    nationalites_eligibles  JSONB DEFAULT '[]',
    africains_eligibles     BOOLEAN DEFAULT FALSE,

    -- Contenu
    description             TEXT,
    avantages               JSONB DEFAULT '[]',
    criteres                JSONB DEFAULT '[]',
    couverture              JSONB DEFAULT '[]',
    lien_candidature        TEXT,
    image_url               TEXT,

    -- Statut
    active                  BOOLEAN DEFAULT TRUE,

    -- Qualité
    qualite_score           INTEGER DEFAULT 0,

    -- Timestamps
    created_at              TIMESTAMPTZ DEFAULT NOW(),
    updated_at              TIMESTAMPTZ DEFAULT NOW()
);

-- Index pour le matching FlyAI
CREATE INDEX IF NOT EXISTS idx_bourses_active         ON bourses (active);
CREATE INDEX IF NOT EXISTS idx_bourses_africains      ON bourses (africains_eligibles);
CREATE INDEX IF NOT EXISTS idx_bourses_financement    ON bourses (financement);
CREATE INDEX IF NOT EXISTS idx_bourses_deadline       ON bourses (deadline);
CREATE INDEX IF NOT EXISTS idx_bourses_score          ON bourses (qualite_score DESC);
CREATE INDEX IF NOT EXISTS idx_bourses_niveau         ON bourses USING GIN (niveau_etude);
CREATE INDEX IF NOT EXISTS idx_bourses_pays           ON bourses USING GIN (pays_destination);
CREATE INDEX IF NOT EXISTS idx_bourses_domaines       ON bourses USING GIN (domaines);
CREATE INDEX IF NOT EXISTS idx_bourses_source         ON bourses (source);

-- Full-text search (titre + description)
CREATE INDEX IF NOT EXISTS idx_bourses_fts ON bourses
    USING GIN (to_tsvector('english', coalesce(titre,'') || ' ' || coalesce(description,'')));

-- Row Level Security (à activer selon votre politique)
-- ALTER TABLE bourses ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE bourses IS 'FlyAI — Bourses académiques agrégées, normalisées et dédupliquées';
COMMENT ON COLUMN bourses.qualite_score IS 'Score qualité 0-100 basé sur la complétude des données';
COMMENT ON COLUMN bourses.africains_eligibles IS 'Flag : bourse accessible aux étudiants africains';
"""


# ─── CLI ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="FlyAI — Pipeline de Normalisation & Fusion des sources de bourses",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemples :
  python flyai_normalize.py
  python flyai_normalize.py --input-dir ./data
  python flyai_normalize.py --active-only --min-score 40
  python flyai_normalize.py --africains-only
  python flyai_normalize.py --output flyai_export.json --output-csv flyai_export.csv
  python flyai_normalize.py --push-supabase
  python flyai_normalize.py --print-sql
  python flyai_normalize.py --report
        """,
    )

    parser.add_argument("--input-dir",   default=".",
                        help="Répertoire contenant les fichiers sources (défaut: .)")
    parser.add_argument("--ofa",         default=None, help="Chemin bourses_ofa.json")
    parser.add_argument("--greatyop",    default=None, help="Chemin bourses_greatyop_v2.json")
    parser.add_argument("--sp",          default=None, help="Chemin bourses_sp.json")
    parser.add_argument("--sa",          default=None, help="Chemin bourses_sa.json")
    parser.add_argument("--output",      default=DEFAULT_OUTPUT,     help="Fichier JSON de sortie")
    parser.add_argument("--output-csv",  default=DEFAULT_OUTPUT_CSV, help="Fichier CSV de sortie")
    parser.add_argument("--active-only", action="store_true",   help="Garder uniquement les bourses actives")
    parser.add_argument("--africains-only", action="store_true",help="Garder uniquement les bourses ouvertes aux Africains")
    parser.add_argument("--min-score",   type=int, default=0,   help="Score qualité minimum (0-100)")
    parser.add_argument("--push-supabase", action="store_true", help="Push vers Supabase")
    parser.add_argument("--supabase-url",  default="",          help="URL Supabase (ou var SUPABASE_URL)")
    parser.add_argument("--supabase-key",  default="",          help="Key Supabase (ou var SUPABASE_KEY)")
    parser.add_argument("--supabase-table",default="bourses",   help="Nom de la table Supabase")
    parser.add_argument("--print-sql",   action="store_true",   help="Afficher le schéma SQL Supabase et quitter")
    parser.add_argument("--report",      action="store_true",   help="Afficher uniquement le rapport (sans écrire)")

    args = parser.parse_args()

    # Afficher le SQL
    if args.print_sql:
        print(SUPABASE_SQL)
        return

    # Construire les chemins d'entrée
    input_dir = Path(args.input_dir)
    input_files = {
        "ofa":      Path(args.ofa)      if args.ofa      else input_dir / DEFAULT_INPUTS["ofa"],
        "greatyop": Path(args.greatyop) if args.greatyop else input_dir / DEFAULT_INPUTS["greatyop"],
        "sp":       Path(args.sp)       if args.sp        else input_dir / DEFAULT_INPUTS["sp"],
        "sa":       Path(args.sa)       if args.sa        else input_dir / DEFAULT_INPUTS["sa"],
    }

    # Supabase credentials depuis env vars si non fournis
    import os
    supabase_url = args.supabase_url or os.environ.get("SUPABASE_URL", "")
    supabase_key = args.supabase_key or os.environ.get("SUPABASE_KEY", "")

    run_pipeline(
        input_files      = input_files,
        output_json      = Path(args.output),
        output_csv       = Path(args.output_csv),
        active_only      = args.active_only,
        min_score        = args.min_score,
        africains_only   = args.africains_only,
        push_supabase    = args.push_supabase,
        supabase_url     = supabase_url,
        supabase_key     = supabase_key,
        supabase_table   = args.supabase_table,
    )


if __name__ == "__main__":
    main()
