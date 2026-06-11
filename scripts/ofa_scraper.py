"""
FlyAI — Scraper OpportunitiesForAfricans.com
=============================================
Collecte les bourses et les structure pour la base de données FlyAI.

Structure de sortie par bourse :
  - id, titre, url, deadline, pays_destination, niveau_etude,
    financement (TOTAL/PARTIEL/INCONNU), domaines, langues_requises,
    nationalites_eligibles, description, date_publication, image_url

Usage :
    python ofa_scraper.py                          # scrape tout
    python ofa_scraper.py --pages 3                # 3 pages seulement
    python ofa_scraper.py --output bourses.json    # fichier de sortie
    python ofa_scraper.py --push-supabase          # insert dans Supabase
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

BASE_URL = "https://www.opportunitiesforafricans.com"
CATEGORY_URL = f"{BASE_URL}/category/scholarships"
DELAY_BETWEEN_REQUESTS = 2.0   # secondes — sois respectueux du serveur

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "fr-FR,fr;q=0.9,en-US;q=0.8",
    "Referer": "https://www.google.com/",
}

# Mots-clés pour détecter le type de financement
FULLY_FUNDED_KEYWORDS = [
    "fully funded", "entièrement financ", "entierement financ",
    "full scholarship", "bourse complète", "bourse complete",
    "all expenses", "full tuition", "frais entièrement", "100%",
]
PARTIAL_KEYWORDS = [
    "partial", "partiellement", "partiel", "partial funding",
    "bourse partielle", "covers tuition only",
]

# Mots-clés niveaux d'études — regex avec word boundaries pour éviter les faux positifs
# ex: "ma " dans "programs" ne doit pas matcher "master"
STUDY_LEVELS = {
    "licence":   [r"\bbachelor\b", r"\blicence\b", r"\bundergraduate\b", r"\blicense\b"],
    "master":    [r"\bmaster\b", r"\bmasters\b", r"\bmsc\b", r"\bm\.sc\b", r"\bma\b", r"\bgraduate\b"],
    "doctorat":  [r"\bphd\b", r"\bdoctorate\b", r"\bdoctoral\b", r"\bdoctorat\b"],
    "postdoc":   [r"\bpostdoc\b", r"post-doctoral", r"post-doc"],
    "formation": [r"\btraining\b", r"\bcertificate\b", r"\bdiploma\b", r"\bformation\b"],
}

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("flyai_scraper")


# ─── Modèle de données ─────────────────────────────────────────────────────────

@dataclass
class Bourse:
    id: str = ""                          # hash SHA1 de l'URL
    titre: str = ""
    url: str = ""
    deadline: Optional[str] = None        # ISO date string "2026-06-30"
    deadline_raw: str = ""                # texte brut "30 June 2026"
    pays_destination: list = field(default_factory=list)
    niveau_etude: list = field(default_factory=list)   # ["master", "doctorat"]
    financement: str = "INCONNU"          # TOTAL | PARTIEL | INCONNU
    domaines: list = field(default_factory=list)
    langues_requises: list = field(default_factory=list)
    nationalites_eligibles: list = field(default_factory=list)
    description: str = ""
    avantages: list = field(default_factory=list)   # ce que couvre la bourse
    criteres: list = field(default_factory=list)    # critères d'éligibilité
    lien_candidature: str = ""
    image_url: str = ""
    date_publication: Optional[str] = None
    source: str = "opportunitiesforafricans.com"
    active: bool = True                   # False si deadline dépassée


# ─── Utilitaires ───────────────────────────────────────────────────────────────

def make_id(url: str) -> str:
    return hashlib.sha1(url.encode()).hexdigest()[:12]


def fetch(url: str, session: requests.Session) -> Optional[BeautifulSoup]:
    """Fetch une page et retourne un BeautifulSoup, ou None si erreur."""
    try:
        r = session.get(url, headers=HEADERS, timeout=15)
        r.raise_for_status()
        return BeautifulSoup(r.text, "lxml")
    except requests.RequestException as e:
        log.warning(f"Erreur fetch {url}: {e}")
        return None


MONTH_MAP_FR = {
    "janvier": "01", "février": "02", "fevrier": "02", "mars": "03",
    "avril": "04", "mai": "05", "juin": "06", "juillet": "07",
    "août": "08", "aout": "08", "septembre": "09", "octobre": "10",
    "novembre": "11", "décembre": "12", "decembre": "12",
    # anglais
    "january": "01", "february": "02", "march": "03", "april": "04",
    "may": "05", "june": "06", "july": "07", "august": "08",
    "september": "09", "october": "10", "november": "11", "december": "12",
}

def parse_deadline(raw: str) -> Optional[str]:
    """
    Convertit un texte deadline en date ISO (YYYY-MM-DD).
    Supporte : "29 April 2026", "September 30, 2026", "31 octobre 2026",
               "2026-04-29", "31/12/2026"
    """
    text = raw.strip().lower()
    text_clean = re.sub(r"[^\w\s/]", " ", text)

    # "29 april 2026" — jour puis mois
    m = re.search(r"(\d{1,2})\s+(\w+)\s+(\d{4})", text_clean)
    if m:
        day, month_word, year = m.groups()
        month = MONTH_MAP_FR.get(month_word)
        if month:
            return f"{year}-{month}-{day.zfill(2)}"

    # "september 30 2026" ou "september 30, 2026" — mois puis jour
    m = re.search(r"(\w+)\s+(\d{1,2})[,\s]+(\d{4})", text_clean)
    if m:
        month_word, day, year = m.groups()
        month = MONTH_MAP_FR.get(month_word)
        if month:
            return f"{year}-{month}-{day.zfill(2)}"

    # ISO: "2026-04-29"
    m = re.search(r"(\d{4})-(\d{2})-(\d{2})", text_clean)
    if m:
        return m.group(0)

    # "31/12/2026" — DD/MM/YYYY
    m = re.search(r"(\d{2})/(\d{2})/(\d{4})", text_clean)
    if m:
        d, mo, y = m.groups()
        return f"{y}-{mo}-{d}"

    return None


def extract_deadline(text: str) -> tuple[str, Optional[str]]:
    """Extrait deadline brute + parsée depuis un texte."""
    patterns = [
        r"Application Deadline[:\s]*(.+?)(?:\n|$|\.|Applications are)",
        r"Date limite[:\s]*(.+?)(?:\n|$|\.|Les candidatures)",
        r"Closing Date[:\s]*(.+?)(?:\n|$|\.)",
        r"Deadline[:\s]*(.+?)(?:\n|$|\.)",
    ]
    for pat in patterns:
        m = re.search(pat, text, re.IGNORECASE)
        if m:
            raw = m.group(1).strip()
            # Nettoyer le texte brut
            raw = re.sub(r"\s+", " ", raw)[:80]
            return raw, parse_deadline(raw)
    return "", None


def detect_financing(text: str) -> str:
    text_lower = text.lower()
    for kw in FULLY_FUNDED_KEYWORDS:
        if kw in text_lower:
            return "TOTAL"
    for kw in PARTIAL_KEYWORDS:
        if kw in text_lower:
            return "PARTIEL"
    return "INCONNU"


def detect_levels(text: str) -> list:
    text_lower = text.lower()
    found = []
    for level, patterns in STUDY_LEVELS.items():
        for pat in patterns:
            if re.search(pat, text_lower):
                found.append(level)
                break
    return list(dict.fromkeys(found))  # dédupliqué, ordre préservé


def extract_countries_from_title(title: str) -> list:
    """Extrait le(s) pays de destination depuis le titre."""
    # Pattern : "to [Country]", "in [Country]", "at [City], [Country]"
    patterns = [
        r"to ([A-Z][a-zA-Z\s]+?)(?:\)|\.|,|$)",
        r"in ([A-Z][a-zA-Z\s]+?)(?:\)|\.|,|$)",
        r"at .+?,\s*([A-Z][a-zA-Z]+)",
    ]
    countries = []
    for pat in patterns:
        for m in re.finditer(pat, title):
            c = m.group(1).strip()
            if len(c) > 2 and c not in ["the", "a", "an"]:
                countries.append(c)
    return list(set(countries))


def extract_eligibility_section(soup: BeautifulSoup) -> list:
    """Trouve la section Eligibility / Éligibilité dans l'article."""
    content = soup.select_one(".entry-content") or soup.select_one("article")
    if not content:
        return []

    eligibility = []
    headers = content.find_all(["h2", "h3", "h4", "strong"])
    for h in headers:
        h_text = h.get_text(strip=True).lower()
        if any(kw in h_text for kw in ["eligib", "éligib", "requirement", "criteria", "who can"]):
            # Récupérer les points suivants (ul > li)
            next_el = h.find_next_sibling()
            while next_el and next_el.name in ["ul", "ol", "p"]:
                if next_el.name in ["ul", "ol"]:
                    eligibility += [li.get_text(strip=True) for li in next_el.find_all("li")]
                elif next_el.name == "p":
                    text = next_el.get_text(strip=True)
                    if text:
                        eligibility.append(text)
                next_el = next_el.find_next_sibling()
            break
    return eligibility[:10]  # max 10 critères


def extract_benefits_section(soup: BeautifulSoup) -> list:
    """Trouve la section Benefits / Avantages."""
    content = soup.select_one(".entry-content") or soup.select_one("article")
    if not content:
        return []

    benefits = []
    headers = content.find_all(["h2", "h3", "h4", "strong"])
    for h in headers:
        h_text = h.get_text(strip=True).lower()
        if any(kw in h_text for kw in ["benefit", "award", "cover", "include", "offre", "avantage", "financ"]):
            next_el = h.find_next_sibling()
            while next_el and next_el.name in ["ul", "ol", "p"]:
                if next_el.name in ["ul", "ol"]:
                    benefits += [li.get_text(strip=True) for li in next_el.find_all("li")]
                next_el = next_el.find_next_sibling()
            break
    return benefits[:10]


def find_application_link(soup: BeautifulSoup) -> str:
    """Cherche le lien "Apply Here" / "Postuler" dans l'article."""
    content = soup.select_one(".entry-content") or soup.select_one("article")
    if not content:
        return ""

    for a in content.find_all("a", href=True):
        text = a.get_text(strip=True).lower()
        if any(kw in text for kw in ["apply", "postuler", "candidature", "click here", "apply now", "apply online"]):
            href = a["href"]
            if href.startswith("http") and BASE_URL not in href:
                return href
    return ""


# ─── Scraping listing page ─────────────────────────────────────────────────────

def scrape_listing_page(soup: BeautifulSoup) -> list[dict]:
    """Extrait les liens + métadonnées basiques des articles sur une page listing."""
    items = []
    articles = soup.select("article")

    for article in articles:
        # Titre + URL
        link_el = article.select_one("h2 a") or article.select_one("h3 a")
        if not link_el:
            continue

        title = link_el.get_text(strip=True)
        url = link_el.get("href", "")
        if not url.startswith("http"):
            continue

        # Date de publication
        time_el = article.select_one("time")
        pub_date = time_el.get("datetime", "") if time_el else ""

        # Excerpt (contient souvent la deadline)
        excerpt_el = article.select_one(".entry-summary") or article.select_one(".entry-content")
        excerpt = excerpt_el.get_text(" ", strip=True) if excerpt_el else ""

        # Deadline rapide depuis l'excerpt
        deadline_raw, deadline_iso = extract_deadline(excerpt)

        # Image
        img = article.select_one("img")
        image_url = img.get("src", "") if img else ""
        # Parfois l'image est en data-src (lazy load)
        if not image_url or image_url.startswith("data:"):
            image_url = img.get("data-src", "") if img else ""

        items.append({
            "titre": title,
            "url": url,
            "pub_date": pub_date,
            "excerpt": excerpt,
            "deadline_raw": deadline_raw,
            "deadline": deadline_iso,
            "image_url": image_url,
        })

    return items


def get_next_page_url(soup: BeautifulSoup, current_url: str) -> Optional[str]:
    """Retourne l'URL de la page suivante, ou None."""
    # WordPress standard
    next_a = soup.select_one("a.next.page-numbers") or soup.select_one(".nav-next a")
    if next_a:
        return next_a.get("href")

    # Pattern URL /page/N/
    m = re.search(r"/page/(\d+)/?$", current_url)
    if m:
        n = int(m.group(1)) + 1
        return re.sub(r"/page/\d+/?$", f"/page/{n}/", current_url)

    return current_url.rstrip("/") + "/page/2/"


# ─── Scraping article complet ──────────────────────────────────────────────────

def scrape_article(url: str, base_info: dict, session: requests.Session) -> Bourse:
    """Scrape un article complet et retourne une Bourse structurée."""
    log.info(f"  Scraping: {base_info['titre'][:60]}...")

    bourse = Bourse(
        id=make_id(url),
        titre=base_info["titre"],
        url=url,
        deadline_raw=base_info.get("deadline_raw", ""),
        deadline=base_info.get("deadline"),
        image_url=base_info.get("image_url", ""),
        date_publication=base_info.get("pub_date", ""),
    )

    soup = fetch(url, session)
    if not soup:
        # Fallback sur les données de listing
        bourse.description = base_info.get("excerpt", "")
        return bourse

    # ── Contenu principal ──
    content = soup.select_one(".entry-content") or soup.select_one("article")
    full_text = content.get_text(" ", strip=True) if content else ""

    # Améliorer la deadline si pas trouvée dans l'excerpt
    if not bourse.deadline:
        bourse.deadline_raw, bourse.deadline = extract_deadline(full_text)

    # ── Financement ──
    title_and_text = bourse.titre + " " + full_text
    bourse.financement = detect_financing(title_and_text)

    # ── Niveaux d'études ──
    bourse.niveau_etude = detect_levels(title_and_text)

    # ── Pays de destination ──
    bourse.pays_destination = extract_countries_from_title(bourse.titre)

    # ── Description (premiers 500 caractères utiles) ──
    paragraphs = content.select("p") if content else []
    useful_paras = [
        p.get_text(strip=True) for p in paragraphs
        if len(p.get_text(strip=True)) > 50
    ]
    bourse.description = " ".join(useful_paras[:3])[:600]

    # ── Avantages ──
    bourse.avantages = extract_benefits_section(soup)

    # ── Critères d'éligibilité ──
    bourse.criteres = extract_eligibility_section(soup)

    # ── Lien candidature direct ──
    bourse.lien_candidature = find_application_link(soup)

    # ── Image (lazy-loaded sur OFA) ──
    if not bourse.image_url:
        img = soup.select_one(".entry-content img, .post-thumbnail img")
        if img:
            bourse.image_url = img.get("src") or img.get("data-src", "")

    # ── Active ? ──
    if bourse.deadline:
        try:
            dl = datetime.fromisoformat(bourse.deadline).date()
            bourse.active = dl >= date.today()
        except ValueError:
            pass

    return bourse


# ─── Pipeline principal ────────────────────────────────────────────────────────

def scrape_ofa(max_pages: int = 999, delay: float = DELAY_BETWEEN_REQUESTS) -> list[Bourse]:
    """
    Scrape toutes les bourses depuis OpportunitiesForAfricans.
    Retourne une liste de Bourse.
    """
    session = requests.Session()
    session.headers.update(HEADERS)

    all_bourses: list[Bourse] = []
    seen_urls: set[str] = set()

    current_url = CATEGORY_URL
    page = 1

    while page <= max_pages:
        log.info(f"Page {page}: {current_url}")
        soup = fetch(current_url, session)
        if not soup:
            log.error(f"Impossible de récupérer la page {page}, arrêt.")
            break

        items = scrape_listing_page(soup)
        if not items:
            log.info("Plus d'articles trouvés, fin du scraping.")
            break

        log.info(f"  {len(items)} bourses trouvées sur cette page.")

        for item in items:
            url = item["url"]
            if url in seen_urls:
                continue
            seen_urls.add(url)

            time.sleep(delay)
            bourse = scrape_article(url, item, session)
            all_bourses.append(bourse)

        # Page suivante
        next_url = get_next_page_url(soup, current_url)
        if not next_url or next_url == current_url:
            break
        current_url = next_url
        page += 1
        time.sleep(delay)

    log.info(f"\n✅ Total: {len(all_bourses)} bourses collectées.")
    return all_bourses


# ─── Export ────────────────────────────────────────────────────────────────────

def to_json(bourses: list[Bourse], filepath: str) -> None:
    data = [asdict(b) for b in bourses]
    with open(filepath, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2, default=str)
    log.info(f"💾 JSON sauvegardé: {filepath}")


def to_supabase(bourses: list[Bourse], url: str, key: str) -> None:
    """
    Insère/met à jour les bourses dans Supabase.
    Nécessite: pip install supabase
    Table attendue: voir schema_supabase.sql
    """
    try:
        from supabase import create_client
    except ImportError:
        log.error("supabase non installé: pip install supabase")
        return

    client = create_client(url, key)
    data = [asdict(b) for b in bourses]

    # Upsert par id (SHA1 de l'URL = idempotent)
    result = client.table("bourses").upsert(data).execute()
    log.info(f"✅ {len(data)} bourses insérées/mises à jour dans Supabase.")


# ─── CLI ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="FlyAI — Scraper OFA")
    parser.add_argument("--pages", type=int, default=5,
                        help="Nombre max de pages listing (défaut: 5)")
    parser.add_argument("--output", default="bourses_ofa.json",
                        help="Fichier JSON de sortie")
    parser.add_argument("--delay", type=float, default=2.0,
                        help="Délai entre requêtes en secondes (défaut: 2.0)")
    parser.add_argument("--push-supabase", action="store_true",
                        help="Insérer dans Supabase (nécessite SUPABASE_URL et SUPABASE_KEY)")
    args = parser.parse_args()

    bourses = scrape_ofa(max_pages=args.pages, delay=args.delay)
    to_json(bourses, args.output)

    if args.push_supabase:
        import os
        sb_url = os.environ.get("SUPABASE_URL", "")
        sb_key = os.environ.get("SUPABASE_KEY", "")
        if sb_url and sb_key:
            to_supabase(bourses, sb_url, sb_key)
        else:
            log.error("Variables SUPABASE_URL et SUPABASE_KEY requises.")

    # Résumé
    active = sum(1 for b in bourses if b.active)
    total_funded = sum(1 for b in bourses if b.financement == "TOTAL")
    levels = {}
    for b in bourses:
        for lv in b.niveau_etude:
            levels[lv] = levels.get(lv, 0) + 1

    print("\n📊 Résumé du scraping:")
    print(f"  Total bourses      : {len(bourses)}")
    print(f"  Encore actives     : {active}")
    print(f"  Entièrement financ.: {total_funded}")
    print(f"  Répartition niveaux: {levels}")


if __name__ == "__main__":
    main()
