"""
FlyAI — Scraper Greatyop.com
=============================
Greatyop est STRUCTURELLEMENT SUPÉRIEUR à OFA pour le scraping :
les champs clés (deadline, niveau, financement, pays, statut) sont dans
un bloc meta HTML normalisé sur chaque article — pas dans du texte libre.

Catégories scrapables :
  /category/master/       → ~82 pages (~400 bourses)
  /category/doctorat/     → ~X pages
  /category/licence/      → ~X pages
  /category/postdoc/      → ~X pages
  /category/recherches/   → ~X pages
  /category/bourses/      → toutes catégories confondues

Usage :
    python greatyop_scraper.py                          # tout scraper
    python greatyop_scraper.py --categories master doctorat
    python greatyop_scraper.py --pages 5 --output bourses.json
    python greatyop_scraper.py --push-supabase
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

BASE_URL = "https://greatyop.com"
DELAY    = 2.0   # secondes entre requêtes

# Catégories et leur mapping vers le niveau FlyAI
CATEGORIES = {
    "master":      "master",
    "doctorat":    "doctorat",
    "licence":     "licence",
    "postdoc":     "postdoc",
    "recherches":  "recherche",
    "bourses":     None,   # toutes catégories
}

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept":          "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "fr-FR,fr;q=0.9,en-US;q=0.8",
    "Referer":         "https://www.google.com/",
}

# ─── Dictionnaires de parsing ──────────────────────────────────────────────────

# Mois abrégés ET complets en français (Greatyop utilise les deux)
MONTH_MAP = {
    "janv": "01", "jan": "01",
    "févr": "02", "fevr": "02", "fév": "02", "fev": "02",
    "mars": "03", "mar": "03",
    "avr": "04", "avril": "04",
    "mai": "05",
    "juin": "06",
    "juil": "07", "juillet": "07",
    "août": "08", "aout": "08",
    "sept": "09", "sep": "09", "septembre": "09",
    "oct": "10", "octobre": "10",
    "nov": "11", "novembre": "11",
    "déc": "12", "dec": "12", "décembre": "12", "decembre": "12",
    # anglais (pour les versions bilingues)
    "january": "01", "february": "02", "march": "03", "april": "04",
    "may": "05", "june": "06", "july": "07", "august": "08",
    "september": "09", "october": "10", "november": "11", "december": "12",
}

# Regex sur le bloc meta structuré de Greatyop
# Structure confirmée sur les pages réelles :
#   DATE LIMITE :     NIVEAU :     FINANCE :
#   OUVERT POUR :     PLACE :      STATUT :
META_FIELDS = {
    # DATE LIMITE : peut être sur la ligne suivante (saut de ligne entre label et valeur)
    "deadline_raw": r"DATE\s+LIMITE\s*:\s*\n?\s*(\d{1,2}\s+\w+\.?\s*\d{4})",
    # NIVEAU / FINANCE / PLACE : valeur sur la même ligne
    "niveau_raw":   r"NIVEAU\s*:\s*(.+?)(?:\n|$)",
    "financement":  r"FINANCE\s*:\s*(.+?)(?:\n|$)",
    "ouvert_pour":  r"OUVERT\s+POUR\s*:\s*(.+?)(?:\n|$)",
    "place":        r"PLACE\s*:\s*(.+?)(?:\n|$)",
    # STATUT : parfois sans espace (STATUT:En cours), d'où \s* au lieu de \s+
    "statut":       r"STATUT\s*:\s*(.+?)(?:\n|$)",
}

# Mapping niveau Greatyop → FlyAI
NIVEAU_MAP = {
    "master":        "master",
    "maîtrise":      "master",
    "licence":       "licence",
    "bachelor":      "licence",
    "doctorat":      "doctorat",
    "phd":           "doctorat",
    "postdoctorat":  "postdoc",
    "postdoc":       "postdoc",
    "post-doc":      "postdoc",
    "recherche":     "recherche",
}

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("flyai.greatyop")


# ─── Modèle ────────────────────────────────────────────────────────────────────

@dataclass
class Bourse:
    id:                     str = ""
    titre:                  str = ""
    url:                    str = ""
    deadline:               Optional[str] = None
    deadline_raw:           str = ""
    pays_destination:       list = field(default_factory=list)
    niveau_etude:           list = field(default_factory=list)
    financement:            str = "INCONNU"      # TOTAL | PARTIEL | INCONNU
    ouvert_pour:            str = ""             # "Tous", "Pays spécifiques", etc.
    domaines:               list = field(default_factory=list)
    langues_requises:       list = field(default_factory=list)
    nationalites_eligibles: list = field(default_factory=list)
    description:            str = ""
    avantages:              list = field(default_factory=list)
    criteres:               list = field(default_factory=list)
    lien_candidature:       str = ""
    image_url:              str = ""
    date_publication:       Optional[str] = None
    source:                 str = "greatyop.com"
    active:                 bool = True
    statut_raw:             str = ""    # "61 Jours restant", "En cours", "Clôturé(e)"
    jours_restants:         Optional[int] = None


# ─── Utilitaires ───────────────────────────────────────────────────────────────

def make_id(url: str) -> str:
    return hashlib.sha1(url.encode()).hexdigest()[:12]


def fetch(url: str, session: requests.Session) -> Optional[BeautifulSoup]:
    try:
        r = session.get(url, headers=HEADERS, timeout=15)
        r.raise_for_status()
        return BeautifulSoup(r.text, "lxml")
    except requests.RequestException as e:
        log.warning(f"Fetch error {url}: {e}")
        return None


def parse_deadline(raw: str) -> Optional[str]:
    """
    Deadline Greatyop : "31 Juil 2026", "1 Oct. 2026", "30 November 2026"
    Retourne "YYYY-MM-DD" ou None.
    """
    text = raw.strip().lower().rstrip(".")
    m = re.search(r"(\d{1,2})\s+(\w+\.?)\s+(\d{4})", text)
    if m:
        day, month_word, year = m.groups()
        month_word = month_word.rstrip(".")
        month = MONTH_MAP.get(month_word)
        if month:
            return f"{year}-{month}-{day.zfill(2)}"
    return None


def normalize_financement(raw: str) -> str:
    if not raw:
        return "INCONNU"
    r = raw.lower()
    # "Entièrement" prime sur "Partiellement" si les deux sont présents
    if any(k in r for k in ["entièrement", "entierement", "fully", "complet", "total", "100%"]):
        return "TOTAL"
    if any(k in r for k in ["partiel", "partial"]):
        return "PARTIEL"
    if any(k in r for k in ["non financ", "not funded"]):
        return "NON_FINANCE"
    return "INCONNU"


def normalize_niveaux(raw: str) -> list:
    """
    "Master" → ["master"]
    "Licence, Master, Doctorat, Postdoctorat, Recherche" → ["licence","master","doctorat","postdoc","recherche"]
    """
    parts = [p.strip().lower() for p in raw.replace(";", ",").split(",")]
    result = []
    for part in parts:
        for key, val in NIVEAU_MAP.items():
            if key in part and val not in result:
                result.append(val)
    return result


def parse_jours_restants(statut: str) -> Optional[int]:
    """
    "61 Jours restant" → 61
    "214 Jours restant" → 214
    "En cours" → None
    "Clôturé(e)" → -1 (expiré)
    """
    statut_lower = statut.lower()
    if any(k in statut_lower for k in ["clôturé", "cloture", "closed", "expired"]):
        return -1
    m = re.search(r"(\d+)\s*jours?", statut_lower)
    if m:
        return int(m.group(1))
    return None


def extract_domains_from_links(soup: BeautifulSoup) -> list:
    """
    Greatyop tague les domaines via des liens /subject/slug/.
    Ex: /subject/sciences-informatiques/ → "sciences informatiques"
    """
    domains = []
    for a in soup.select("a[href*='/subject/']"):
        slug = a["href"].rstrip("/").split("/subject/")[-1]
        domain = slug.replace("-", " ").strip()
        if domain and domain not in domains:
            domains.append(domain)
    return domains


def extract_eligible_countries(soup: BeautifulSoup) -> list:
    """
    Extrait la liste des pays éligibles depuis les sections
    'pays éligibles' ou 'countries eligible' dans le contenu.
    """
    content = soup.select_one(".entry-content") or soup.select_one("article")
    if not content:
        return []

    # Chercher un h2/h3 contenant "pays éligibles" ou "countries"
    for h in content.find_all(["h2", "h3"]):
        h_text = h.get_text(strip=True).lower()
        if any(k in h_text for k in ["pays éligibles", "pays eligibles", "countries eligible", "liste des pays"]):
            # Le contenu des pays suit en <p> ou dans le texte directement
            next_el = h.find_next_sibling()
            countries_text = ""
            while next_el and next_el.name in ["p", "ul", "ol"]:
                countries_text += " " + next_el.get_text(strip=True)
                next_el = next_el.find_next_sibling()

            if countries_text:
                # Les pays sont listés avec des virgules
                raw_countries = [c.strip() for c in countries_text.split(",")]
                # Garder uniquement les entrées ressemblant à des noms de pays
                countries = [
                    c for c in raw_countries
                    if 2 < len(c) < 50 and c[0].isupper()
                ]
                return countries[:50]  # cap à 50

    return []


def extract_benefits(soup: BeautifulSoup) -> list:
    """Extrait les avantages de la bourse (liste ol/ul après h2 Avantages)."""
    content = soup.select_one(".entry-content") or soup.select_one("article")
    if not content:
        return []

    for h in content.find_all(["h2", "h3"]):
        h_text = h.get_text(strip=True).lower()
        if any(k in h_text for k in ["avantage", "benefit", "award", "couvert", "offre"]):
            benefits = []
            next_el = h.find_next_sibling()
            while next_el and next_el.name in ["ul", "ol", "p"]:
                if next_el.name in ["ul", "ol"]:
                    benefits += [li.get_text(strip=True) for li in next_el.find_all("li")]
                next_el = next_el.find_next_sibling()
                if benefits:
                    break
            return benefits[:10]
    return []


def extract_eligibility_criteria(soup: BeautifulSoup) -> list:
    """Extrait les critères d'éligibilité."""
    content = soup.select_one(".entry-content") or soup.select_one("article")
    if not content:
        return []

    for h in content.find_all(["h2", "h3"]):
        h_text = h.get_text(strip=True).lower()
        if any(k in h_text for k in ["éligib", "eligib", "critère", "condition", "requis", "requirement"]):
            criteria = []
            next_el = h.find_next_sibling()
            while next_el and next_el.name in ["ul", "ol", "p"]:
                if next_el.name in ["ul", "ol"]:
                    criteria += [li.get_text(strip=True) for li in next_el.find_all("li")]
                elif next_el.name == "p":
                    t = next_el.get_text(strip=True)
                    if t:
                        criteria.append(t)
                next_el = next_el.find_next_sibling()
                if criteria:
                    break
            return criteria[:10]
    return []


def find_apply_link(soup: BeautifulSoup) -> str:
    """Cherche le lien de candidature direct (hors greatyop.com)."""
    content = soup.select_one(".entry-content") or soup.select_one("article")
    if not content:
        return ""
    apply_keywords = [
        "postuler", "apply now", "apply here", "apply online",
        "cliquez ici pour postuler", "soumettre", "candidature",
        "click here to apply", "official website", "site officiel",
    ]
    for a in content.find_all("a", href=True):
        href = a.get("href", "")
        text = a.get_text(strip=True).lower()
        if BASE_URL not in href and href.startswith("http"):
            if any(kw in text for kw in apply_keywords):
                return href
    return ""


# ─── Parsing du bloc meta structuré ───────────────────────────────────────────

def parse_meta_block(full_text: str) -> dict:
    """
    Extrait les 6 champs du bloc meta Greatyop depuis le texte brut.

    Bloc type sur chaque article :
        DATE LIMITE :   31 Juil 2026
        NIVEAU :        Master
        FINANCE :       Entièrement financé(e)
        OUVERT POUR :   Pays spécifiques
        PLACE :         Allemagne
        STATUT :        61 Jours restant
    """
    result = {}
    for field_name, pattern in META_FIELDS.items():
        m = re.search(pattern, full_text, re.IGNORECASE | re.MULTILINE)
        result[field_name] = m.group(1).strip() if m else None
    return result


# ─── Scraping listing ─────────────────────────────────────────────────────────

def scrape_listing(soup: BeautifulSoup, category_level: Optional[str]) -> list[dict]:
    """
    Extrait les cartes d'articles depuis une page listing Greatyop.
    Retourne une liste de dicts avec titre, url, image_url, niveau_hint.
    """
    items = []

    # Sur Greatyop, les articles sont dans des <article> ou <h2.entry-title>
    for h2 in soup.select("h2.entry-title, h2 a, article h2"):
        a_el = h2.find("a") if h2.name != "a" else h2
        if not a_el:
            continue

        url = a_el.get("href", "")
        title = a_el.get_text(strip=True)

        if not url.startswith("http") or not title:
            continue

        # Image de la carte
        parent = h2.parent
        img = parent.find("img") if parent else None
        image_url = ""
        if img:
            image_url = img.get("src", "") or img.get("data-src", "") or img.get("data-lazy-src", "")
            if image_url.startswith("data:"):
                image_url = img.get("data-src", "") or img.get("data-lazy-src", "")

        # Statut affiché dans la card (badge)
        # Greatyop affiche "61 Jours restant", "En cours", "Clôturé(e)" sous l'image
        card_text = parent.get_text(" ", strip=True) if parent else ""
        statut_m = re.search(r"(\d+\s+Jours?\s+restants?|En cours|Clôturé\(e\)|Clotured?)", card_text, re.I)
        statut_card = statut_m.group(0) if statut_m else ""

        items.append({
            "titre":         title,
            "url":           url,
            "image_url":     image_url,
            "niveau_hint":   category_level,
            "statut_card":   statut_card,
        })

    return items


def get_next_page(soup: BeautifulSoup, current_url: str) -> Optional[str]:
    """Retourne l'URL page suivante ou None."""
    # Lien pagination WordPress standard
    next_a = soup.select_one("a.next.page-numbers")
    if next_a:
        return next_a.get("href")

    # Pattern URL /page/N/
    m = re.search(r"/page/(\d+)/?$", current_url.rstrip("/"))
    if m:
        n = int(m.group(1)) + 1
        base = re.sub(r"/page/\d+/?$", "", current_url.rstrip("/"))
        return f"{base}/page/{n}/"

    # Première page → page 2
    base = current_url.rstrip("/")
    return f"{base}/page/2/"


def get_total_pages(soup: BeautifulSoup) -> int:
    """Lit le nombre total de pages depuis le bloc pagination."""
    # Dernier bouton numéroté
    page_numbers = soup.select("a.page-numbers:not(.next):not(.prev)")
    if page_numbers:
        try:
            last = page_numbers[-1].get_text(strip=True)
            return int(last)
        except ValueError:
            pass
    return 1


# ─── Scraping article complet ─────────────────────────────────────────────────

def scrape_article(url: str, base_info: dict, session: requests.Session) -> Bourse:
    """
    Scrape un article Greatyop et retourne une Bourse structurée.
    Point fort : extraction du bloc meta structuré (deadline, niveau, etc.)
    """
    log.info(f"  → {base_info['titre'][:65]}...")

    bourse = Bourse(
        id=make_id(url),
        url=url,
        titre=base_info["titre"],
        image_url=base_info.get("image_url", ""),
        statut_raw=base_info.get("statut_card", ""),
        source="greatyop.com",
    )

    # Déduire active depuis le statut de la card (avant de fetcher)
    if bourse.statut_raw:
        jours = parse_jours_restants(bourse.statut_raw)
        bourse.jours_restants = jours
        bourse.active = (jours is None or jours > 0)

    # Si déjà clôturé d'après la card, pas besoin de scraper le détail
    if not bourse.active:
        niveau_hint = base_info.get("niveau_hint")
        if niveau_hint:
            bourse.niveau_etude = [niveau_hint]
        return bourse

    soup = fetch(url, session)
    if not soup:
        if base_info.get("niveau_hint"):
            bourse.niveau_etude = [base_info["niveau_hint"]]
        return bourse

    # ── Image OG (meilleure qualité) ──────────────────────────
    og_img = soup.select_one("meta[property='og:image']")
    if og_img:
        bourse.image_url = og_img.get("content", bourse.image_url)

    # ── Description meta ──────────────────────────────────────
    desc_meta = soup.select_one("meta[name='description']")
    if desc_meta:
        bourse.description = desc_meta.get("content", "")

    # ── Date de publication ───────────────────────────────────
    time_el = soup.select_one("time[datetime]")
    if time_el:
        bourse.date_publication = time_el.get("datetime", "")

    # ── Texte complet de l'article ────────────────────────────
    # Le bloc meta Greatyop (FINANCE, PLACE, STATUT...) est dans le body
    # AVANT .entry-content — on cherche dans l'article entier pour le meta,
    # et dans .entry-content pour les sections détaillées (avantages, critères)
    content = soup.select_one(".entry-content") or soup.select_one("article")
    article_zone = soup.select_one("article") or soup.find("main") or soup.find("body")
    full_text = article_zone.get_text("\n", strip=True) if article_zone else ""

    # ── BLOC META STRUCTURÉ (point fort Greatyop) ─────────────
    meta = parse_meta_block(full_text)

    # Deadline
    if meta.get("deadline_raw"):
        bourse.deadline_raw = meta["deadline_raw"]
        bourse.deadline = parse_deadline(meta["deadline_raw"])

    # Niveau
    raw_niveau = meta.get("niveau_raw") or ""
    niveaux = normalize_niveaux(raw_niveau)
    # Si pas trouvé dans le bloc meta, utiliser l'indice de la catégorie URL
    if not niveaux and base_info.get("niveau_hint"):
        niveaux = [base_info["niveau_hint"]]
    bourse.niveau_etude = niveaux

    # Financement
    if meta.get("financement"):
        bourse.financement = normalize_financement(meta["financement"])

    # Pays de destination
    if meta.get("place"):
        place = meta["place"].strip()
        if place and place.lower() not in ["n/a", "non spécifié", "varies"]:
            bourse.pays_destination = [p.strip() for p in place.split(",")]

    # Ouvert pour
    bourse.ouvert_pour = meta.get("ouvert_pour") or ""

    # Statut raffiné depuis l'article (plus fiable que la card)
    if meta.get("statut"):
        bourse.statut_raw = meta["statut"]
        jours = parse_jours_restants(meta["statut"])
        bourse.jours_restants = jours
        bourse.active = (jours is None or jours > 0)

    # Double-check avec la deadline parsée
    if bourse.deadline:
        try:
            dl = datetime.fromisoformat(bourse.deadline).date()
            bourse.active = dl >= date.today()
        except ValueError:
            pass

    # ── DOMAINES — via liens /subject/ ─────────────────────────
    bourse.domaines = extract_domains_from_links(soup)

    # ── AVANTAGES ─────────────────────────────────────────────
    bourse.avantages = extract_benefits(soup)

    # ── CRITÈRES ──────────────────────────────────────────────
    bourse.criteres = extract_eligibility_criteria(soup)

    # ── PAYS ÉLIGIBLES ────────────────────────────────────────
    countries = extract_eligible_countries(soup)
    if countries:
        bourse.nationalites_eligibles = countries

    # ── LIEN CANDIDATURE ──────────────────────────────────────
    bourse.lien_candidature = find_apply_link(soup)

    return bourse


# ─── Pipeline de scraping ─────────────────────────────────────────────────────

def scrape_category(
    category: str,
    max_pages: int = 999,
    delay: float = DELAY,
    session: Optional[requests.Session] = None,
) -> list[Bourse]:
    """Scrape une catégorie Greatyop complète (ex: 'master')."""

    if session is None:
        session = requests.Session()
        session.headers.update(HEADERS)

    level_hint = CATEGORIES.get(category)
    base_cat_url = f"{BASE_URL}/category/{category}"
    current_url = base_cat_url
    page = 1
    all_bourses = []
    seen_urls: set[str] = set()

    while page <= max_pages:
        log.info(f"[{category}] Page {page}: {current_url}")
        soup = fetch(current_url, session)
        if not soup:
            log.warning(f"Page {page} inaccessible, arrêt.")
            break

        # Lire total pages sur la première page
        if page == 1:
            total = get_total_pages(soup)
            log.info(f"  → Total pages détecté: {total}")
            max_pages = min(max_pages, total)

        items = scrape_listing(soup, level_hint)
        if not items:
            log.info("  Aucun article, fin.")
            break

        log.info(f"  {len(items)} articles trouvés")

        for item in items:
            url = item["url"]
            if url in seen_urls:
                continue
            seen_urls.add(url)

            time.sleep(delay)
            bourse = scrape_article(url, item, session)
            all_bourses.append(bourse)

        # Vérifier si on continue
        next_url = get_next_page(soup, current_url)
        if not next_url or next_url == current_url:
            break
        current_url = next_url
        page += 1
        time.sleep(delay)

    log.info(f"[{category}] Total: {len(all_bourses)} bourses")
    return all_bourses


def scrape_greatyop(
    categories: list[str] = None,
    max_pages_per_category: int = 999,
    delay: float = DELAY,
) -> list[Bourse]:
    """
    Scrape Greatyop sur plusieurs catégories.
    Déduplique les URLs entre catégories.
    """
    if categories is None:
        categories = list(CATEGORIES.keys())

    session = requests.Session()
    session.headers.update(HEADERS)

    all_bourses: list[Bourse] = []
    seen_urls: set[str] = set()

    for cat in categories:
        log.info(f"\n{'='*50}\nCatégorie: {cat}\n{'='*50}")
        bourses = scrape_category(cat, max_pages_per_category, delay, session)
        for b in bourses:
            if b.url not in seen_urls:
                seen_urls.add(b.url)
                all_bourses.append(b)
        time.sleep(5)  # pause entre catégories

    log.info(f"\n✅ TOTAL: {len(all_bourses)} bourses collectées (tous niveaux)")
    return all_bourses


# ─── Export ────────────────────────────────────────────────────────────────────

def to_json(bourses: list[Bourse], filepath: str) -> None:
    data = [asdict(b) for b in bourses]
    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2, default=str)
    log.info(f"💾 Sauvegardé: {filepath} ({len(data)} bourses)")


def to_supabase(bourses: list[Bourse], url: str, key: str) -> None:
    try:
        from supabase import create_client
    except ImportError:
        log.error("pip install supabase")
        return
    client = create_client(url, key)
    data = [asdict(b) for b in bourses]
    client.table("bourses").upsert(data).execute()
    log.info(f"✅ {len(data)} bourses → Supabase")


def print_stats(bourses: list[Bourse]) -> None:
    total = len(bourses)
    if not total:
        return
    active       = sum(1 for b in bourses if b.active)
    total_fin    = sum(1 for b in bourses if b.financement == "TOTAL")
    with_deadline = sum(1 for b in bourses if b.deadline)
    with_pays    = sum(1 for b in bourses if b.pays_destination)
    with_domains = sum(1 for b in bourses if b.domaines)

    levels = {}
    for b in bourses:
        for lv in b.niveau_etude:
            levels[lv] = levels.get(lv, 0) + 1

    print(f"\n📊 Rapport Greatyop :")
    print(f"  Total            : {total}")
    print(f"  Actives          : {active} ({active*100//total}%)")
    print(f"  Entièrement fin. : {total_fin} ({total_fin*100//total}%)")
    print(f"  Avec deadline    : {with_deadline} ({with_deadline*100//total}%)")
    print(f"  Avec pays        : {with_pays} ({with_pays*100//total}%)")
    print(f"  Avec domaines    : {with_domains} ({with_domains*100//total}%)")
    print(f"  Par niveau       : {levels}")


# ─── CLI ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="FlyAI — Scraper Greatyop.com")
    parser.add_argument(
        "--categories", nargs="+",
        default=["master", "doctorat", "licence"],
        choices=list(CATEGORIES.keys()),
        help="Catégories à scraper",
    )
    parser.add_argument("--pages", type=int, default=5,
                        help="Pages max par catégorie")
    parser.add_argument("--output", default="bourses_greatyop.json")
    parser.add_argument("--delay", type=float, default=2.0)
    parser.add_argument("--push-supabase", action="store_true")
    args = parser.parse_args()

    bourses = scrape_greatyop(
        categories=args.categories,
        max_pages_per_category=args.pages,
        delay=args.delay,
    )

    to_json(bourses, args.output)
    print_stats(bourses)

    if args.push_supabase:
        import os
        sb_url = os.environ.get("SUPABASE_URL", "")
        sb_key = os.environ.get("SUPABASE_KEY", "")
        if sb_url and sb_key:
            to_supabase(bourses, sb_url, sb_key)
        else:
            log.error("SUPABASE_URL et SUPABASE_KEY requis")


if __name__ == "__main__":
    main()