"""
FlyAI — Scraper scholarshipsads.com
=====================================
Site très riche : +12 000 bourses, filtres par pays/niveau/domaine,
filtres africains disponibles via /categories/tags/african-countries/.

Structure HTML :
  Listing  → cartes avec badges (Fully Funded / Partial, niveau, pays)
  Détail   → bloc "Scholarship Summary" avec champs labellisés (même idée que SP)
             + sections Benefits, Eligibility, Subjects

Avantages vs OFA / Greatyop :
  ✅ Badges structurés sur les cartes listing → pré-classification rapide
  ✅ Bloc "Scholarship Summary" en liste labellisée (comme Brief Description de SP)
  ✅ URL canonique propre → ID stable via SHA1
  ✅ meta og:image → image HD
  ✅ meta article:published_time → date ISO complète
  ✅ Pagination simple ?page=N (1 225 pages disponibles)
  ✅ Catégories dédiées Afrique, niveau, pays

Catégories disponibles :
  african-countries, masters, phd, bachelor, undergraduate,
  fellowship, uk-scholarships, france-scholarships, germany-scholarships,
  usa-scholarships, fully-funded (via tag interne)

Usage :
    python sa_scraper.py                                  # défaut : africa + masters + phd
    python sa_scraper.py --categories african masters phd bachelor
    python sa_scraper.py --pages 20 --output bourses_sa.json
    python sa_scraper.py --pages 5 --delay 1.0 --push-supabase
    python sa_scraper.py --test-url https://www.scholarshipsads.com/stanford-...
"""

import re
import json
import time
import hashlib
import logging
import argparse
from datetime import datetime, date
from dataclasses import dataclass, field, asdict
from typing import Optional

import requests
from bs4 import BeautifulSoup

# ─── Config ────────────────────────────────────────────────────────────────────

BASE_URL = "https://www.scholarshipsads.com"
DELAY    = 2.0   # secondes — légèrement plus conservateur qu'un site WordPress

# Catégories → URL listing + hint niveau FlyAI
# Format URL : /categories/tags/<tag>/ ou /category/degree/<degree>/ ou ?page=N
CATEGORIES = {
    "african"       : {"url": f"{BASE_URL}/categories/tags/african-countries/", "hint": None},
    "masters"       : {"url": f"{BASE_URL}/category/degree/masters/",           "hint": "master"},
    "phd"           : {"url": f"{BASE_URL}/category/degree/phd/",               "hint": "doctorat"},
    "bachelor"      : {"url": f"{BASE_URL}/category/degree/bachelor/",          "hint": "licence"},
    "undergraduate" : {"url": f"{BASE_URL}/category/degree/undergraduate/",     "hint": "licence"},
    "fellowship"    : {"url": f"{BASE_URL}/category/degree/fellowship/",        "hint": "recherche"},
    "postdoc"       : {"url": f"{BASE_URL}/category/degree/post-doctorate/",    "hint": "postdoc"},
    "latest"        : {"url": f"{BASE_URL}/latest-scholarships/",               "hint": None},
    "uk"            : {"url": f"{BASE_URL}/category/country/uk-scholarships/",  "hint": None},
    "france"        : {"url": f"{BASE_URL}/category/country/france-scholarships/", "hint": None},
    "germany"       : {"url": f"{BASE_URL}/category/country/germany-scholarships/", "hint": None},
    "usa"           : {"url": f"{BASE_URL}/category/country/usa-scholarships/", "hint": None},
}

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept":          "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9,fr;q=0.8",
    "Referer":         "https://www.google.com/",
}

# ─── Dictionnaires ─────────────────────────────────────────────────────────────

MONTH_MAP = {
    "january": "01", "february": "02", "march": "03",    "april": "04",
    "may":     "05", "june":     "06", "july":  "07",    "august": "08",
    "september": "09", "october": "10", "november": "11", "december": "12",
    "jan": "01", "feb": "02", "mar": "03", "apr": "04",
    "jun": "06", "jul": "07", "aug": "08", "sep": "09",
    "oct": "10", "nov": "11", "dec": "12",
}

# Labels du bloc "Scholarship Summary" → champs FlyAI
# Exactement comme BRIEF_LABELS dans sp_scraper.py
SUMMARY_LABELS = {
    "host country":           "pays_destination_raw",
    "country":                "pays_destination_raw",
    "university":             "universite",
    "host university":        "universite",
    "institution":            "universite",
    "scholarship program":    "programme",
    "degree level":           "niveau_raw",
    "level":                  "niveau_raw",
    "funding type":           "financement_raw",
    "funding":                "financement_raw",
    "scholarship type":       "financement_raw",
    "coverage":               "couverture_raw",
    "benefits":               "couverture_raw",
    "eligible nationalities": "nationalite_raw",
    "nationality":            "nationalite_raw",
    "open to":                "nationalite_raw",
    "application deadline":   "deadline_raw",
    "final deadline":         "deadline_raw",
    "deadline":               "deadline_raw",
    "application opens":      "date_ouverture_raw",
    "opens":                  "date_ouverture_raw",
    "study location":         "lieu_etude",
    "number of awards":       "nb_bourses",
    "number of scholarships": "nb_bourses",
}

# Patterns de niveaux — mêmes clés que sp_scraper.py pour compatibilité DB
LEVEL_PATTERNS = {
    "licence":   [r"\bundergraduate\b", r"\bbachelor\b", r"\blicence\b", r"\bbs\b", r"\bba\b"],
    "master":    [r"\bmaster\b", r"\bmasters\b", r"\bmsc\b", r"\bma\b", r"\bmba\b", r"\bgraduate\b", r"\bpostgraduate\b"],
    "doctorat":  [r"\bphd\b", r"\bdoctorate\b", r"\bdoctoral\b", r"\bjd\b"],
    "postdoc":   [r"\bpostdoc\b", r"post-doctoral", r"post doctorate"],
    "recherche": [r"\bfellowship\b", r"\bresearch\b"],
    "formation": [r"\bcertificate\b", r"\bdiploma\b", r"\btraining\b", r"\bshort\b", r"\bnon-degree\b"],
}

# Pays africains pour flag africains_eligibles
AFRICAN_KEYWORDS = {
    "africa", "african", "nigeria", "kenya", "ghana", "ethiopia", "tanzania",
    "senegal", "cameroon", "côte d'ivoire", "ivory coast", "togo", "benin",
    "burkina faso", "mali", "niger", "guinea", "rwanda", "uganda", "mozambique",
    "zambia", "zimbabwe", "malawi", "namibia", "botswana", "south africa",
    "egypt", "morocco", "tunisia", "algeria", "libya", "angola", "congo",
    "drc", "somalia", "eritrea", "sudan", "developing countries",
    "all nationalities", "all countries", "international students", "worldwide",
    "tous", "open to all",
}

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("flyai.sa")


# ─── Modèle de données ─────────────────────────────────────────────────────────
# Aligné sur le dataclass Bourse de sp_scraper.py pour compatibilité pipeline

@dataclass
class Bourse:
    id:                     str  = ""
    titre:                  str  = ""
    url:                    str  = ""
    deadline:               Optional[str] = None   # ISO YYYY-MM-DD
    deadline_raw:           str  = ""
    date_ouverture:         str  = ""
    universite:             str  = ""
    programme:              str  = ""
    pays_destination:       list = field(default_factory=list)
    lieu_etude:             str  = ""
    niveau_etude:           list = field(default_factory=list)
    financement:            str  = "INCONNU"       # TOTAL | PARTIEL | INCONNU
    couverture:             list = field(default_factory=list)   # tuition, stipend...
    nb_bourses:             str  = ""
    nationalites_eligibles: list = field(default_factory=list)
    africains_eligibles:    bool = False
    domaines:               list = field(default_factory=list)
    langues_requises:       list = field(default_factory=list)
    description:            str  = ""
    avantages:              list = field(default_factory=list)
    criteres:               list = field(default_factory=list)
    lien_candidature:       str  = ""
    image_url:              str  = ""
    date_publication:       Optional[str] = None
    annee:                  Optional[int] = None
    tags_sa:                list = field(default_factory=list)   # badges SA
    categories_sa:          list = field(default_factory=list)   # catégories scraping
    source:                 str  = "scholarshipsads.com"
    active:                 bool = True


# ─── Utilitaires ───────────────────────────────────────────────────────────────

def make_id(url: str) -> str:
    """SHA1 court — même logique que sp_scraper.py."""
    return "sa_" + hashlib.sha1(url.encode()).hexdigest()[:12]


def fetch(url: str, session: requests.Session, retries: int = 3) -> Optional[BeautifulSoup]:
    """Fetch avec retry exponentiel — même interface que sp_scraper.py."""
    for attempt in range(1, retries + 1):
        try:
            r = session.get(url, headers=HEADERS, timeout=15)
            if r.status_code == 404:
                log.warning(f"404: {url}")
                return None
            r.raise_for_status()
            return BeautifulSoup(r.text, "lxml")
        except requests.RequestException as e:
            log.warning(f"Fetch error (tentative {attempt}/{retries}) {url}: {e}")
            if attempt < retries:
                time.sleep(2 ** attempt)
    log.error(f"Échec définitif : {url}")
    return None


def parse_deadline(raw: str) -> Optional[str]:
    """
    Supporte tous les formats trouvés sur scholarshipsads.com :
    "October 6, 2026", "6 October 2026", "2026-10-06", "Oct 6 2026"
    Retourne ISO YYYY-MM-DD ou None.
    """
    text = raw.strip().lower()
    text = re.sub(r"[^\w\s/\-,]", " ", text)

    # "31 october 2025" ou "31 oct 2025"
    m = re.search(r"(\d{1,2})\s+(\w+)\s+(\d{4})", text)
    if m:
        day, month_word, year = m.groups()
        month = MONTH_MAP.get(month_word)
        if month:
            return f"{year}-{month}-{day.zfill(2)}"

    # "october 6, 2026" ou "october 6 2026"
    m = re.search(r"(\w+)\s+(\d{1,2})[,\s]+(\d{4})", text)
    if m:
        month_word, day, year = m.groups()
        month = MONTH_MAP.get(month_word)
        if month:
            return f"{year}-{month}-{day.zfill(2)}"

    # ISO "2026-10-06"
    m = re.search(r"(\d{4})-(\d{2})-(\d{2})", text)
    if m:
        return m.group(0)

    return None


def normalize_financement(raw: str) -> str:
    """Même logique que sp_scraper.py — TOTAL | PARTIEL | INCONNU."""
    r = raw.lower()
    fully_kws = [
        "fully funded", "fully-funded", "full scholarship", "complete funding",
        "all expenses", "100%", "full tuition", "covers tuition", "cover tuition",
        "includes tuition", "tuition waiver", "tuition and", "stipend and",
        "accommodation", "living expenses",
    ]
    partial_kws = ["partial", "part-funded", "stipend only", "tuition only"]
    if any(k in r for k in fully_kws):
        return "TOTAL"
    if any(k in r for k in partial_kws):
        return "PARTIEL"
    return "INCONNU"


def normalize_niveaux(raw: str, hint: Optional[str] = None) -> list:
    """Même logique que sp_scraper.py — retourne liste de niveaux FlyAI."""
    text = raw.lower()
    found = []
    for level, patterns in LEVEL_PATTERNS.items():
        for pat in patterns:
            if re.search(pat, text):
                found.append(level)
                break
    if not found and hint:
        found = [hint]
    return list(dict.fromkeys(found))  # déduplique en préservant l'ordre


def parse_countries_field(raw: str) -> list:
    """
    Même logique que parse_countries_field de sp_scraper.py.
    "All nationalities", "Nigeria, Kenya, Ghana" → liste normalisée.
    """
    text = re.sub(r"\([^)]*\)", "", raw).strip()

    if re.search(r"\b(all|international|worldwide|open to all|any nationality)\b", text, re.I):
        return ["Tous"]

    parts = re.split(r",|;|\band\b|\bor\b", text)
    countries = []
    for p in parts:
        p = p.strip()
        if 2 < len(p) < 60 and p[0].isupper():
            p = re.sub(r"\s+(etc\.?|only|citizens|nationals|students|applicants)$",
                       "", p, flags=re.I).strip()
            if p:
                countries.append(p)
    return countries[:20]


def parse_couverture(raw: str) -> list:
    """Décompose la chaîne de couverture en liste de bénéfices."""
    if not raw:
        return []
    # Séparer par virgule, point-virgule, "and", "+"
    items = re.split(r",|;|\band\b|\+", raw, flags=re.I)
    return [i.strip() for i in items if len(i.strip()) > 3][:10]


def detect_language(text: str) -> list:
    """Détecte les langues requises — même fonction que sp_scraper.py."""
    langs = []
    if re.search(r"\benglish\b", text, re.I):
        langs.append("Anglais")
    if re.search(r"\bfrench\b|\bfrançais\b", text, re.I):
        langs.append("Français")
    if re.search(r"\bgerman\b|\bdeutsch\b", text, re.I):
        langs.append("Allemand")
    if re.search(r"\bspanish\b|\bespañol\b", text, re.I):
        langs.append("Espagnol")
    if re.search(r"\bportuguese\b", text, re.I):
        langs.append("Portugais")
    return langs


def extract_year(titre: str) -> Optional[int]:
    """Extrait l'année depuis le titre (ex: 'Knight-Hennessy 2027')."""
    m = re.search(r"\b(202[4-9]|203\d)\b", titre)
    return int(m.group(0)) if m else None


def is_african_eligible(text: str, nationalites: list) -> bool:
    """Vérifie si les étudiants africains sont éligibles."""
    combined = (text + " ".join(nationalites)).lower()
    return any(kw in combined for kw in AFRICAN_KEYWORDS)


# ─── Extraction du bloc "Scholarship Summary" ──────────────────────────────────
# Équivalent du extract_brief_field de sp_scraper.py
# Structure SA :  <ul><li>Key: Value</li>...</ul>  ou  <p><strong>Key:</strong> Value</p>

def extract_summary_field(soup: BeautifulSoup, label: str) -> str:
    """
    Extrait un champ labellisé du bloc Scholarship Summary.

    Structure typique scholarshipsads.com :
      <ul>
        <li>Host Country: United States</li>
        <li>Funding Type: Fully Funded</li>
        <li>Final Deadline: October 6, 2026</li>
      </ul>

    Ou dans un <p> :
      <p><strong>Deadline:</strong> October 6, 2026</p>

    Label recherché en lowercase, insensible à la casse.
    """
    label_l = label.lower()

    # Priorité 1 : <li> contenant le label
    for li in soup.find_all("li"):
        text = li.get_text(separator=" ", strip=True)
        if label_l in text.lower():
            # Format "Key: Value" — prendre ce qui suit le ":"
            if ":" in text:
                parts = text.split(":", 1)
                key = parts[0].strip().lower()
                # Vérifier que c'est bien le bon label (pas juste une coïncidence)
                if any(lbl in key for lbl in label_l.split()):
                    return parts[1].strip()

    # Priorité 2 : <strong> contenant le label
    for strong in soup.find_all(["strong", "b"]):
        if label_l in strong.get_text().lower():
            parent = strong.parent
            full = parent.get_text(separator=" ", strip=True)
            if ":" in full:
                parts = full.split(":", 1)
                return parts[1].strip()

    return ""


def extract_all_summary(soup: BeautifulSoup) -> dict:
    """
    Extrait tous les champs du bloc Scholarship Summary en une passe.
    Retourne un dict {champ_flyai: valeur}.
    Plus efficace qu'appeler extract_summary_field N fois.
    """
    result = {}

    # Chercher le bloc summary (h2/h3 "Summary" ou "Scholarship Summary")
    summary_section = None
    for h in soup.find_all(["h2", "h3", "h4"]):
        if "summary" in h.get_text(strip=True).lower():
            summary_section = h
            break

    # Si trouvé, parser la liste qui suit
    if summary_section:
        next_el = summary_section.find_next(["ul", "ol", "table"])
        if next_el:
            items = next_el.find_all("li") if next_el.name in ["ul", "ol"] else []
            for li in items:
                text = li.get_text(separator=" ", strip=True)
                if ":" in text:
                    key, _, val = text.partition(":")
                    key_l = key.strip().lower()
                    val = val.strip()
                    # Mapper vers champ FlyAI
                    for label, field_name in SUMMARY_LABELS.items():
                        if label in key_l:
                            if field_name not in result:  # premier match = meilleur
                                result[field_name] = val
                            break

    # Fallback global : scanner tous les <li> avec "Key: Value"
    if not result:
        for li in soup.find_all("li"):
            text = li.get_text(separator=" ", strip=True)
            if ":" in text and len(text) < 200:
                key, _, val = text.partition(":")
                key_l = key.strip().lower()
                val = val.strip()
                for label, field_name in SUMMARY_LABELS.items():
                    if label in key_l:
                        if field_name not in result:
                            result[field_name] = val
                        break

    return result


def extract_deadline_sa(soup: BeautifulSoup) -> tuple[str, Optional[str]]:
    """
    Deadline sur SA :
      - Dans le bloc Summary "Final Deadline: October 6, 2026"
      - Dans un <strong>Deadline:</strong>
      - Dans le texte libre de l'article

    Retourne (raw_string, ISO_date_or_None).
    """
    # Priorité 1 : bloc Summary
    raw = extract_summary_field(soup, "deadline")
    if raw:
        return raw, parse_deadline(raw)

    raw = extract_summary_field(soup, "application deadline")
    if raw:
        return raw, parse_deadline(raw)

    # Priorité 2 : texte libre de l'article
    content = soup.select_one(".entry-content, article, .post-content, main")
    if content:
        text = content.get_text(" ", strip=True)
        m = re.search(
            r"(?:deadline|closing date|last date|apply before)[:\s]*([A-Za-z0-9\s,]+?\d{4})",
            text, re.IGNORECASE
        )
        if m:
            raw = m.group(1).strip()[:80]
            return raw, parse_deadline(raw)

    return "", None


def extract_benefits_sa(soup: BeautifulSoup) -> list:
    """
    Avantages depuis la section Benefits/Coverage de scholarshipsads.com.
    Structure : h3 "Benefits" → ul > li
    """
    content = soup.select_one(".entry-content, article, .post-content, main")
    if not content:
        return []

    for h in content.find_all(["h2", "h3", "h4"]):
        h_text = h.get_text(strip=True).lower()
        if any(kw in h_text for kw in ["benefit", "coverage", "cover", "what you get", "package"]):
            # Chercher la liste qui suit
            el = h.find_next_sibling()
            while el:
                if el.name in ["ul", "ol"]:
                    return [li.get_text(strip=True) for li in el.find_all("li", recursive=False)][:10]
                if el.name in ["h2", "h3", "h4"]:
                    break
                el = el.find_next_sibling()

    return []


def extract_eligibility_sa(soup: BeautifulSoup) -> list:
    """
    Critères d'éligibilité depuis la section Eligibility.
    """
    content = soup.select_one(".entry-content, article, .post-content, main")
    if not content:
        return []

    criteria = []
    for h in content.find_all(["h2", "h3", "h4"]):
        h_text = h.get_text(strip=True).lower()
        if any(kw in h_text for kw in ["eligib", "requirement", "who can apply", "criteria"]):
            el = h.find_next_sibling()
            while el:
                if el.name in ["ul", "ol"]:
                    for li in el.find_all("li", recursive=False):
                        text = li.get_text(" ", strip=True)
                        # Gérer sous-listes éventuelles
                        sub_ul = li.find("ul")
                        if sub_ul:
                            for sub_li in sub_ul.find_all("li"):
                                criteria.append(sub_li.get_text(strip=True))
                        elif len(text) > 10:
                            criteria.append(text)
                elif el.name in ["h2", "h3", "h4"]:
                    break
                el = el.find_next_sibling()
            break

    return criteria[:12]


def extract_subjects_sa(soup: BeautifulSoup) -> list:
    """
    Domaines disponibles depuis la section "Available Subjects".
    """
    content = soup.select_one(".entry-content, article, .post-content, main")
    if not content:
        return []

    for h in content.find_all(["h2", "h3", "h4"]):
        h_text = h.get_text(strip=True).lower()
        if any(kw in h_text for kw in ["subject", "field", "discipline", "area", "program"]):
            next_ul = h.find_next_sibling(["ul", "ol"])
            if next_ul:
                items = [li.get_text(strip=True) for li in next_ul.find_all("li")]
                # "All Subjects" → tag unique
                if any("all" in i.lower() for i in items):
                    return ["Tous domaines"]
                return items[:10]
            # Sinon, texte du paragraphe suivant
            next_p = h.find_next_sibling("p")
            if next_p:
                raw = next_p.get_text(strip=True)
                if "all subjects" in raw.lower() or "all fields" in raw.lower():
                    return ["Tous domaines"]
                return [s.strip() for s in re.split(r",|;|\band\b", raw) if s.strip()][:10]

    return []


def find_apply_link_sa(soup: BeautifulSoup) -> str:
    """
    Lien de candidature — même logique que sp_scraper.py.
    SA utilise souvent un lien "Apply Here" ou "Official Website".
    """
    content = soup.select_one(".entry-content, article, .post-content, main")
    if not content:
        return ""

    apply_kws = [
        "apply now", "apply here", "apply online", "official website",
        "application link", "click here to apply", "submit application",
        "application form", "apply for", "official link",
    ]
    for a in content.find_all("a", href=True):
        href = a.get("href", "")
        text = a.get_text(strip=True).lower()
        # Lien externe uniquement (pas interne au site SA)
        if BASE_URL not in href and href.startswith("http"):
            if any(kw in text for kw in apply_kws):
                return href

    # Fallback : dernier lien externe de l'article
    for a in reversed(content.find_all("a", href=True)):
        href = a.get("href", "")
        if href.startswith("http") and BASE_URL not in href:
            return href

    return ""


# ─── Scraping listing ─────────────────────────────────────────────────────────

def scrape_listing(soup: BeautifulSoup, level_hint: Optional[str]) -> list[dict]:
    """
    Extrait les cartes de bourses depuis une page listing scholarshipsads.com.

    Structure HTML réelle :
      <h3><a href="URL">TITRE</a></h3>
      <ul>
        <li>Fully Funded</li>
        <li>USA Universities</li>
        <li>Masters, PhD</li>
        <li>All Subjects</li>
        <li>International Students</li>
        <li>USA</li>
      </ul>
      <img src="...">

    Les badges <li> donnent : financement, pays, niveau, domaine, nationalité.
    On les extrait ici pour pré-remplir sans fetch détail quand possible.
    """
    items = []
    seen_urls: set = set()

    # SA structure : liens h3 avec href vers article
    # Sélecteurs par ordre de fiabilité
    entry_links = (
        soup.select("h3 > a[href]")
        or soup.select(".entry-title a")
        or soup.select("h2 > a[href]")
    )

    for a_el in entry_links:
        url = a_el.get("href", "").strip()
        titre = a_el.get_text(strip=True)

        if not url.startswith("http") or not titre:
            continue
        # Exclure pages de navigation SA
        skip = ["/category/", "/categories/", "/blog/", "/universities/",
                "/latest-scholarships", "/scholarships-in-", "/subject-wise",
                "/user-onboard", "?page=", "#", "whatsapp", "facebook", "twitter"]
        if any(s in url for s in skip):
            continue
        # Titre trop court = lien de nav
        if len(titre) < 15:
            continue
        if url in seen_urls:
            continue
        seen_urls.add(url)

        # Remonter au conteneur pour capturer les badges et l'image
        container = a_el.parent  # <h3>
        for _ in range(5):
            if container is None:
                break
            container = container.parent
            # Chercher le div qui contient à la fois le <h3> et le <ul> de badges
            ul = container.find("ul")
            img = container.find("img")
            if ul or img:
                break

        # Extraire les badges de la carte (pré-classification)
        badges = []
        image_url = ""
        if container:
            ul = container.find("ul")
            if ul:
                badges = [li.get_text(strip=True) for li in ul.find_all("li")
                          if li.get_text(strip=True)]
            img = container.find("img")
            if img:
                image_url = (img.get("data-src") or img.get("data-lazy-src")
                             or img.get("src", ""))
                if image_url and image_url.startswith("data:"):
                    image_url = img.get("data-src") or img.get("data-lazy-src", "")

        items.append({
            "titre":      titre,
            "url":        url,
            "image_url":  image_url,
            "level_hint": level_hint,
            "badges":     badges,   # ex: ["Fully Funded", "USA", "Masters, PhD", ...]
        })

    # Fallback regex si sélecteurs CSS retournent vide
    if not items:
        log.debug("Sélecteurs CSS vides — fallback regex URL")
        article_re = re.compile(
            r'href="(https://www\.scholarshipsads\.com/[a-z0-9\-]+-\d+[a-z]{3}\d{4}[^"]*)"'
        )
        for url in dict.fromkeys(article_re.findall(str(soup))):
            if url in seen_urls:
                continue
            seen_urls.add(url)
            slug = url.rstrip("/").split("/")[-1]
            titre = re.sub(r"-\d+[a-z]{3}\d{4}$", "", slug).replace("-", " ").title()
            items.append({
                "titre":      titre,
                "url":        url,
                "image_url":  "",
                "level_hint": level_hint,
                "badges":     [],
            })

    return items


def get_next_page_sa(soup: BeautifulSoup, current_url: str, page_num: int) -> Optional[str]:
    """
    SA utilise ?page=N. Chercher le lien "next" ou incrémenter.
    """
    # Chercher lien "next" dans la pagination
    for a in soup.find_all("a", href=True):
        text = a.get_text(strip=True).lower()
        href = a.get("href", "")
        if text in ["»", "next", ">"] and "page=" in href:
            return href

    # Chercher le lien page suivante par numéro
    next_page_links = soup.find_all("a", href=lambda h: h and f"page={page_num + 1}" in h)
    if next_page_links:
        return next_page_links[0].get("href")

    # Incrémenter dans l'URL
    base = current_url.split("?")[0].rstrip("/")
    return f"{base}?page={page_num + 1}"


def get_total_pages_sa(soup: BeautifulSoup) -> int:
    """Extrait le nombre total de pages depuis la pagination SA."""
    max_page = 1
    for a in soup.find_all("a", href=True):
        href = a.get("href", "")
        m = re.search(r"page=(\d+)", href)
        if m:
            max_page = max(max_page, int(m.group(1)))
    return max_page


# ─── Scraping article ─────────────────────────────────────────────────────────

def scrape_article(url: str, base_info: dict, session: requests.Session) -> Bourse:
    """
    Scrape une page de bourse scholarshipsads.com.
    Extraction structurée du bloc Scholarship Summary (≈ Brief Description de SP).
    """
    log.info(f"  → {base_info['titre'][:65]}...")

    # Pré-remplir depuis les badges de la carte listing
    badges = base_info.get("badges", [])
    badges_text = " ".join(badges).lower()

    bourse = Bourse(
        id          = make_id(url),
        url         = url,
        titre       = base_info["titre"],
        image_url   = base_info.get("image_url", ""),
        tags_sa     = badges,
        annee       = extract_year(base_info["titre"]),
        categories_sa = base_info.get("categories_sa", []),
    )

    # Pré-classification depuis les badges (sans fetch détail)
    if "fully funded" in badges_text:
        bourse.financement = "TOTAL"
    elif "partial" in badges_text:
        bourse.financement = "PARTIEL"

    # Niveaux depuis badges
    bourse.niveau_etude = normalize_niveaux(badges_text, base_info.get("level_hint"))

    # ── Fetch page de détail ──────────────────────────────────────────────────
    soup = fetch(url, session)
    if not soup:
        return bourse

    # ── Image HD via meta og ──────────────────────────────────────────────────
    og_img = soup.select_one("meta[property='og:image']")
    if og_img:
        bourse.image_url = og_img.get("content", bourse.image_url)

    # ── Date publication via meta ─────────────────────────────────────────────
    pub_meta = soup.select_one("meta[property='article:published_time']")
    if pub_meta:
        bourse.date_publication = pub_meta.get("content", "")

    # ── Titre depuis h1 (plus fiable que la carte) ───────────────────────────
    h1 = soup.find("h1")
    if h1:
        bourse.titre = h1.get_text(strip=True)
        bourse.annee = extract_year(bourse.titre)

    # ── Extraction du bloc Scholarship Summary ────────────────────────────────
    summary = extract_all_summary(soup)

    # Mapper les champs extraits vers Bourse
    if "pays_destination_raw" in summary:
        bourse.pays_destination = parse_countries_field(summary["pays_destination_raw"])

    if "universite" in summary:
        bourse.universite = summary["universite"]

    if "programme" in summary:
        bourse.programme = summary["programme"]

    if "lieu_etude" in summary:
        bourse.lieu_etude = summary["lieu_etude"]
        # Si pas de pays_destination, utiliser lieu_etude
        if not bourse.pays_destination:
            bourse.pays_destination = parse_countries_field(bourse.lieu_etude)

    if "nb_bourses" in summary:
        bourse.nb_bourses = summary["nb_bourses"]

    if "nationalite_raw" in summary:
        bourse.nationalites_eligibles = parse_countries_field(summary["nationalite_raw"])

    # Niveau depuis summary (plus précis que les badges)
    if "niveau_raw" in summary:
        niveaux_summary = normalize_niveaux(summary["niveau_raw"], base_info.get("level_hint"))
        if niveaux_summary:
            bourse.niveau_etude = niveaux_summary

    # Financement depuis summary (plus précis que les badges)
    if "financement_raw" in summary:
        bourse.financement = normalize_financement(summary["financement_raw"])

    # Couverture depuis summary
    if "couverture_raw" in summary:
        bourse.couverture = parse_couverture(summary["couverture_raw"])

    # Deadline depuis summary (priorité) puis extraction dédiée
    if "deadline_raw" in summary:
        bourse.deadline_raw = summary["deadline_raw"]
        bourse.deadline     = parse_deadline(summary["deadline_raw"])
    else:
        bourse.deadline_raw, bourse.deadline = extract_deadline_sa(soup)

    if "date_ouverture_raw" in summary:
        bourse.date_ouverture = summary["date_ouverture_raw"]

    # ── Avantages ─────────────────────────────────────────────────────────────
    if not bourse.couverture:
        bourse.couverture = extract_benefits_sa(soup)

    # ── Critères d'éligibilité ────────────────────────────────────────────────
    bourse.criteres = extract_eligibility_sa(soup)

    # ── Langues requises depuis critères ──────────────────────────────────────
    criteres_text = " ".join(bourse.criteres)
    bourse.langues_requises = detect_language(criteres_text)

    # ── Domaines ──────────────────────────────────────────────────────────────
    bourse.domaines = extract_subjects_sa(soup)

    # Fallback domaines : tags SA non-géographiques non-niveau
    if not bourse.domaines:
        exclude = {"fully funded", "partial funding", "international students",
                   "domestic students", "master", "masters", "phd", "bachelor",
                   "undergraduate", "fellowship", "postdoc"}
        domaines_from_badges = [
            b for b in badges
            if b.lower() not in exclude
            and not re.search(r"university|universities|students", b, re.I)
            and not re.search(r"\b(usa|uk|germany|france|australia|canada|china|japan)\b", b, re.I)
            and len(b) > 3
        ]
        bourse.domaines = domaines_from_badges[:8]

    # ── Description (meta ou premiers paragraphes) ────────────────────────────
    desc_meta = soup.select_one("meta[name='description']")
    if desc_meta and desc_meta.get("content"):
        bourse.description = desc_meta.get("content", "")[:600]
    else:
        content = soup.select_one(".entry-content, article, .post-content, main")
        if content:
            paras = [p.get_text(strip=True) for p in content.select("p")
                     if len(p.get_text(strip=True)) > 50]
            bourse.description = " ".join(paras[:2])[:600]

    # ── Lien de candidature ───────────────────────────────────────────────────
    bourse.lien_candidature = find_apply_link_sa(soup)

    # ── Éligibilité africaine ─────────────────────────────────────────────────
    eligibles_text = " ".join(bourse.nationalites_eligibles) + " " + " ".join(bourse.criteres)
    bourse.africains_eligibles = is_african_eligible(eligibles_text, bourse.nationalites_eligibles)

    # ── Statut actif ──────────────────────────────────────────────────────────
    if bourse.deadline:
        try:
            dl = datetime.fromisoformat(bourse.deadline).date()
            bourse.active = dl >= date.today()
        except ValueError:
            pass
    else:
        # Sans deadline : supposer active si publiée récemment
        bourse.active = True

    return bourse


# ─── Pipeline de scraping ─────────────────────────────────────────────────────

def scrape_category(
    category: str,
    max_pages: int = 999,
    delay: float = DELAY,
    session: Optional[requests.Session] = None,
) -> list[Bourse]:
    """
    Scrape une catégorie complète de scholarshipsads.com.
    Même signature que scrape_category() de sp_scraper.py.
    """
    if session is None:
        session = requests.Session()

    cat_info   = CATEGORIES[category]
    base_cat_url = cat_info["url"]
    level_hint = cat_info["hint"]

    page = 1
    bourses: list[Bourse] = []
    seen_urls: set[str]   = set()
    current_url = base_cat_url

    while page <= max_pages:
        # SA pagine avec ?page=N (sauf page 1)
        if page == 1:
            current_url = base_cat_url
        else:
            base = base_cat_url.rstrip("/")
            current_url = f"{base}?page={page}"

        log.info(f"[SA/{category}] Page {page}: {current_url}")
        soup = fetch(current_url, session)
        if not soup:
            break

        # Total pages (1ère page uniquement)
        if page == 1:
            total = get_total_pages_sa(soup)
            effective_max = min(max_pages, total)
            log.info(f"  Total pages disponibles: {total} (limité à {effective_max})")
            max_pages = effective_max

        items = scrape_listing(soup, level_hint)
        if not items:
            log.info("  Aucun article trouvé — arrêt.")
            break

        log.info(f"  {len(items)} articles sur cette page")
        new_count = 0

        for item in items:
            url = item["url"]
            if url in seen_urls:
                continue
            seen_urls.add(url)
            item["categories_sa"] = [category]
            time.sleep(delay)
            b = scrape_article(url, item, session)
            bourses.append(b)
            new_count += 1

        log.info(f"  → {new_count} nouvelles bourses (total cat: {len(bourses)})")

        if page >= max_pages:
            break
        page += 1
        time.sleep(delay)

    log.info(f"[SA/{category}] {len(bourses)} bourses collectées")
    return bourses


def scrape_sa(
    categories: list[str] = None,
    max_pages: int = 999,
    delay: float = DELAY,
) -> list[Bourse]:
    """
    Pipeline principal — plusieurs catégories, déduplication globale.
    Même signature que scrape_sp() de sp_scraper.py.
    """
    if categories is None:
        categories = ["african", "masters", "phd"]

    session = requests.Session()
    session.headers.update(HEADERS)

    all_bourses: list[Bourse] = []
    seen: set[str] = set()

    for cat in categories:
        if cat not in CATEGORIES:
            log.warning(f"Catégorie inconnue: {cat} — disponibles: {list(CATEGORIES.keys())}")
            continue
        log.info(f"\n{'='*50}\nCatégorie: {cat}\n{'='*50}")
        for b in scrape_category(cat, max_pages, delay, session):
            if b.url not in seen:
                seen.add(b.url)
                all_bourses.append(b)
        time.sleep(5)

    log.info(f"\n✅ TOTAL: {len(all_bourses)} bourses")
    return all_bourses


# ─── Export ────────────────────────────────────────────────────────────────────

def to_json(bourses: list[Bourse], path: str) -> None:
    """Même interface que sp_scraper.py."""
    with open(path, "w", encoding="utf-8") as f:
        json.dump([asdict(b) for b in bourses], f,
                  ensure_ascii=False, indent=2, default=str)
    log.info(f"💾 {path} ({len(bourses)} bourses)")


def to_supabase(bourses: list[Bourse], url: str, key: str) -> None:
    """Push vers Supabase — même interface que sp_scraper.py."""
    try:
        from supabase import create_client
    except ImportError:
        log.error("pip install supabase")
        return
    client = create_client(url, key)
    # Retirer les champs spécifiques SA non présents dans le schéma partagé
    data = []
    for b in bourses:
        d = asdict(b)
        d.pop("tags_sa", None)
        d.pop("categories_sa", None)
        data.append(d)
    client.table("bourses").upsert(data).execute()
    log.info(f"✅ {len(data)} bourses → Supabase")


def print_stats(bourses: list[Bourse]) -> None:
    """
    Rapport format FlyAI — même style que print_stats de sp_scraper.py.
    """
    total = len(bourses)
    if not total:
        return

    active          = sum(1 for b in bourses if b.active)
    funded          = sum(1 for b in bourses if b.financement == "TOTAL")
    partial         = sum(1 for b in bourses if b.financement == "PARTIEL")
    with_dl         = sum(1 for b in bourses if b.deadline)
    with_pays       = sum(1 for b in bourses if b.pays_destination)
    with_uni        = sum(1 for b in bourses if b.universite)
    with_domaines   = sum(1 for b in bourses if b.domaines)
    africains       = sum(1 for b in bourses if b.africains_eligibles)

    levels = {}
    for b in bourses:
        for lv in b.niveau_etude:
            levels[lv] = levels.get(lv, 0) + 1

    pays_count = {}
    for b in bourses:
        for p in b.pays_destination:
            pays_count[p] = pays_count.get(p, 0) + 1
    top_pays = sorted(pays_count.items(), key=lambda x: -x[1])[:5]

    print(f"\n📊 Rapport scholarshipsads.com :")
    print(f"  Total              : {total}")
    print(f"  Actives            : {active} ({active*100//total}%)")
    print(f"  Entièrement fin.   : {funded} ({funded*100//total}%)")
    print(f"  Partiellement fin. : {partial} ({partial*100//total}%)")
    print(f"  Avec deadline      : {with_dl} ({with_dl*100//total}%)")
    print(f"  Avec université    : {with_uni} ({with_uni*100//total}%)")
    print(f"  Avec pays          : {with_pays} ({with_pays*100//total}%)")
    print(f"  Avec domaines      : {with_domaines} ({with_domaines*100//total}%)")
    print(f"  Africains élig.    : {africains} ({africains*100//total}%)")
    print(f"  Par niveau         : {levels}")
    print(f"  Top 5 pays étude   : {top_pays}")


# ─── CLI ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="FlyAI — Scraper scholarshipsads.com",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Exemples :
  python sa_scraper.py
  python sa_scraper.py --categories african masters phd
  python sa_scraper.py --categories african --pages 10
  python sa_scraper.py --categories latest --pages 5 --output bourses_sa.json
  python sa_scraper.py --push-supabase
  python sa_scraper.py --test-url https://www.scholarshipsads.com/stanford-university-knight-hennessy-scholarships-usa-5jun2026
        """,
    )
    parser.add_argument(
        "--categories", nargs="+",
        default=["african", "masters", "phd"],
        choices=list(CATEGORIES.keys()),
        help="Catégories à scraper (défaut: african masters phd)",
    )
    parser.add_argument("--pages",  type=int,   default=5,
                        help="Nombre max de pages par catégorie (défaut: 5)")
    parser.add_argument("--delay",  type=float, default=DELAY,
                        help=f"Délai entre requêtes en secondes (défaut: {DELAY})")
    parser.add_argument("--output", default="bourses_sa.json",
                        help="Fichier de sortie JSON (défaut: bourses_sa.json)")
    parser.add_argument("--push-supabase", action="store_true",
                        help="Push vers Supabase (SUPABASE_URL + SUPABASE_KEY requis)")
    parser.add_argument("--test-url", type=str, default=None,
                        help="Tester le scraper sur une URL unique")

    args = parser.parse_args()

    # ── Mode test unitaire ────────────────────────────────────────────────────
    if args.test_url:
        log.info(f"🧪 Mode test — URL: {args.test_url}")
        session = requests.Session()
        session.headers.update(HEADERS)
        item = {
            "titre":        "Test",
            "url":          args.test_url,
            "image_url":    "",
            "level_hint":   None,
            "badges":       [],
            "categories_sa": ["test"],
        }
        bourse = scrape_article(args.test_url, item, session)
        print("\n" + "="*60)
        print("🧪 Résultat test :")
        print(json.dumps(asdict(bourse), ensure_ascii=False, indent=2, default=str))
        print("="*60)
        return

    # ── Pipeline complet ──────────────────────────────────────────────────────
    bourses = scrape_sa(args.categories, args.pages, args.delay)
    to_json(bourses, args.output)
    print_stats(bourses)

    if args.push_supabase:
        import os
        sb_url = os.environ.get("SUPABASE_URL", "")
        sb_key = os.environ.get("SUPABASE_KEY", "")
        if sb_url and sb_key:
            to_supabase(bourses, sb_url, sb_key)
        else:
            log.error("SUPABASE_URL et SUPABASE_KEY requis (variables d'environnement)")


if __name__ == "__main__":
    main()
