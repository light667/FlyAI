"""
FlyAI — Scraper scholarship-positions.com
==========================================
Le site le mieux structuré de l'écosystème :
chaque article contient un bloc "Brief Description" avec des champs
labelisés (University, Level, Award, Nationality, Country...).
Extraction fiable à ~98%, sans regex complexe sur du texte libre.

Avantages vs OFA / Greatyop :
  ✅ Champs nommés explicitement dans le HTML (label:valeur)
  ✅ Pas de Cloudflare agressif — scrapable depuis serveur
  ✅ 4500+ bourses actives
  ✅ Tags = pays + université + domaine → matching FlyAI précis
  ✅ meta article:published_time → date ISO complète
  ✅ meta og:image → image HD

Catégories disponibles :
  africa-scholarships, masters-scholarships, phd-scholarships-positions,
  under-graduate-scholarship, postgraduate-scholarships, fellowships,
  fully-funded-scholarships

Usage :
    python sp_scraper.py                          # toutes catégories
    python sp_scraper.py --categories africa-scholarships masters-scholarships
    python sp_scraper.py --pages 10 --output bourses_sp.json
    python sp_scraper.py --push-supabase
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

BASE_URL = "https://scholarship-positions.com"
DELAY    = 1.5   # secondes — le site est accessible sans être agressif

# Catégories → niveau FlyAI
CATEGORIES = {
    "africa-scholarships":            None,       # toutes, Afrique
    "masters-scholarships":           "master",
    "phd-scholarships-positions":     "doctorat",
    "under-graduate-scholarship":     "licence",
    "postgraduate-scholarships":      None,       # master + doctorat
    "fellowships":                    "recherche",
    "fully-funded-scholarships":      None,       # toutes, entièrement financées
}

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept":          "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer":         "https://www.google.com/",
}

# ─── Dictionnaires ─────────────────────────────────────────────────────────────

MONTH_MAP = {
    "january": "01", "february": "02", "march": "03", "april": "04",
    "may": "05", "june": "06", "july": "07", "august": "08",
    "september": "09", "october": "10", "november": "11", "december": "12",
    "jan": "01", "feb": "02", "mar": "03", "apr": "04",
    "jun": "06", "jul": "07", "aug": "08", "sep": "09",
    "oct": "10", "nov": "11", "dec": "12",
}

# Labels du bloc "Brief Description" → champs FlyAI
# Chaque clé est le texte du <strong> sur la page
BRIEF_LABELS = {
    "university or organization": "universite",
    "department":                  "departement",
    "course level":                "niveau_raw",
    "award":                       "award_raw",
    "access mode":                 "access_mode",
    "number of awards":            "nb_bourses",
    "nationality":                 "nationalite_raw",
    "the award can be taken in":   "pays_destination_raw",
}

# Mots-clés niveaux dans le champ "Course Level"
LEVEL_PATTERNS = {
    "licence":   [r"\bundergraduate\b", r"\bbachelor\b", r"\blicence\b"],
    "master":    [r"\bmaster\b", r"\bmasters\b", r"\bmsc\b", r"\bma\b", r"\bgraduate\b"],
    "doctorat":  [r"\bphd\b", r"\bdoctorate\b", r"\bdoctoral\b", r"\bdoctorat\b"],
    "postdoc":   [r"\bpostdoc\b", r"post-doctoral"],
    "recherche": [r"\bfellowship\b", r"\bresearch\b"],
    "formation": [r"\bcertificate\b", r"\bdiploma\b", r"\btraining\b"],
}

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("flyai.sp")


# ─── Modèle de données ─────────────────────────────────────────────────────────

@dataclass
class Bourse:
    id:                     str  = ""
    titre:                  str  = ""
    url:                    str  = ""
    deadline:               Optional[str] = None   # ISO YYYY-MM-DD
    deadline_raw:           str  = ""
    universite:             str  = ""
    departement:            str  = ""
    pays_destination:       list = field(default_factory=list)
    niveau_etude:           list = field(default_factory=list)
    financement:            str  = "INCONNU"       # TOTAL | PARTIEL | INCONNU
    nb_bourses:             str  = ""
    nationalites_eligibles: list = field(default_factory=list)
    domaines:               list = field(default_factory=list)
    langues_requises:       list = field(default_factory=list)
    description:            str  = ""
    avantages:              list = field(default_factory=list)
    criteres:               list = field(default_factory=list)
    lien_candidature:       str  = ""
    image_url:              str  = ""
    date_publication:       Optional[str] = None
    categories_sp:          list = field(default_factory=list)  # catégories WordPress
    tags_sp:                list = field(default_factory=list)  # tags WordPress
    source:                 str  = "scholarship-positions.com"
    active:                 bool = True


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
    Supporte tous les formats trouvés sur le site :
    "31 October 2025", "October 31, 2025", "31 Oct 2025", "2025-10-31"
    """
    text = raw.strip().lower()
    text = re.sub(r"[^\w\s/\-]", " ", text)

    # "31 october 2025" ou "31 oct 2025"
    m = re.search(r"(\d{1,2})\s+(\w+)\s+(\d{4})", text)
    if m:
        day, month_word, year = m.groups()
        month = MONTH_MAP.get(month_word)
        if month:
            return f"{year}-{month}-{day.zfill(2)}"

    # "october 31 2025" ou "october 31, 2025"
    m = re.search(r"(\w+)\s+(\d{1,2})[,\s]+(\d{4})", text)
    if m:
        month_word, day, year = m.groups()
        month = MONTH_MAP.get(month_word)
        if month:
            return f"{year}-{month}-{day.zfill(2)}"

    # ISO "2025-10-31"
    m = re.search(r"(\d{4})-(\d{2})-(\d{2})", text)
    if m:
        return m.group(0)

    return None


def normalize_financement(raw: str) -> str:
    r = raw.lower()
    fully_kws = [
        "fully funded", "full scholarship", "fully-funded",
        "complete funding", "all expenses", "100%", "full tuition",
        "covers tuition", "cover tuition", "includes tuition",
        "tuition waiver", "tuition and", "stipend and",
    ]
    partial_kws = ["partial", "part-funded", "stipend only", "tuition only"]
    if any(k in r for k in fully_kws):
        return "TOTAL"
    if any(k in r for k in partial_kws):
        return "PARTIEL"
    # Si "funded" ou "scholarship" sans qualification → TOTAL probable
    if "funded" in r or "scholarship" in r:
        return "TOTAL"
    return "INCONNU"


def normalize_niveaux(raw: str, category_hint: Optional[str] = None) -> list:
    text = raw.lower()
    found = []
    for level, patterns in LEVEL_PATTERNS.items():
        for pat in patterns:
            if re.search(pat, text):
                found.append(level)
                break
    if not found and category_hint:
        found = [category_hint]
    return list(dict.fromkeys(found))


def parse_countries_field(raw: str) -> list:
    """
    "South Africa (Stellenbosch University) with mobility to TUM"
    → ["South Africa"]

    "Citizens from developing countries in Africa, Asia, Latin America"
    → ["Africa", "Asia", "Latin America"]  (régions conservées si pas de pays précis)
    """
    # Retirer le contenu entre parenthèses
    text = re.sub(r"\([^)]*\)", "", raw).strip()

    # Cas "all countries" / "international" / "all nationalities"
    if re.search(r"\b(all|international|worldwide|open to all)\b", text, re.I):
        return ["Tous"]

    # Extraire les tokens qui ressemblent à des noms de pays/régions
    parts = re.split(r",|;|\band\b|\bor\b", text)
    countries = []
    for p in parts:
        p = p.strip()
        # Garder seulement si c'est en majuscule (nom propre) et longueur raisonnable
        if 2 < len(p) < 60 and p[0].isupper():
            # Nettoyer suffixes courants
            p = re.sub(r"\s+(etc\.?|only|citizens|nationals|students)$", "", p, flags=re.I).strip()
            if p:
                countries.append(p)
    return countries[:20]


def detect_language(text: str) -> list:
    """Détecte les langues requises depuis le texte d'éligibilité."""
    langs = []
    if re.search(r"\benglish\b", text, re.I):
        langs.append("Anglais")
    if re.search(r"\bfrench\b|\bfrançais\b", text, re.I):
        langs.append("Français")
    if re.search(r"\bgerman\b|\bdeutsch\b", text, re.I):
        langs.append("Allemand")
    if re.search(r"\bspanish\b|\bespañol\b", text, re.I):
        langs.append("Espagnol")
    return langs


# ─── Extraction du bloc "Brief Description" ────────────────────────────────────

def extract_brief_field(soup: BeautifulSoup, label: str) -> str:
    """
    Extrait la valeur d'un champ labelisé dans la liste Brief Description.

    Structure HTML :
      <ul>
        <li><strong>University or Organization:</strong> Stellenbosch University</li>
        <li><strong>Course Level:</strong> <a href="...">PhD</a>/Doctoral Program</li>
      </ul>

    Retourne le texte après le <strong>, sans les deux-points.
    """
    label_lower = label.lower()
    for li in soup.select("li"):
        strong = li.find("strong")
        if not strong:
            continue
        if label_lower in strong.get_text().lower():
            # Cloner le li, retirer le strong, récupérer le texte restant
            li_copy = BeautifulSoup(str(li), "lxml").find("li")
            li_copy.find("strong").decompose()
            value = li_copy.get_text(separator=" ", strip=True).lstrip(":").strip()
            return value
    return ""


def extract_deadline(soup: BeautifulSoup) -> tuple[str, Optional[str]]:
    """
    Deadline sur SP : <strong>Application Deadline:</strong> 31 October 2025.
    Parfois aussi dans un paragraphe standalone.
    """
    # Chercher le strong "Application Deadline"
    for strong in soup.find_all("strong"):
        if "application deadline" in strong.get_text().lower():
            # Texte après le strong dans le même parent
            parent = strong.parent
            full_text = parent.get_text(" ", strip=True)
            m = re.search(
                r"application deadline[:\s]*(.+?)(?:\.|$)",
                full_text, re.IGNORECASE
            )
            if m:
                raw = m.group(1).strip()
                return raw, parse_deadline(raw)

    # Fallback : chercher dans le texte complet
    content = soup.select_one(".entry-content") or soup.select_one("article")
    if content:
        text = content.get_text(" ", strip=True)
        m = re.search(
            r"application deadline[:\s]*(.+?)(?:\.|$|\n)",
            text, re.IGNORECASE
        )
        if m:
            raw = m.group(1).strip()[:80]
            return raw, parse_deadline(raw)

    return "", None


def extract_eligibility_criteria(soup: BeautifulSoup) -> list:
    """
    Extrait les critères depuis la section Eligibility.
    SP structure : h2 "Eligibility" → ul > li (avec sous-listes pour "Admissible Criteria")
    """
    criteria = []
    content = soup.select_one(".entry-content") or soup.select_one("article")
    if not content:
        return []

    for h in content.find_all(["h2", "h3"]):
        if "eligib" not in h.get_text().lower():
            continue

        # Parcourir les éléments qui suivent le h2
        el = h.find_next_sibling()
        while el and el.name not in ["h2", "h3"]:
            if el.name in ["ul", "ol"]:
                for li in el.find_all("li", recursive=False):
                    text = li.get_text(" ", strip=True)

                    # Les sous-listes "Admissible Criteria" ont leur propre ul
                    sub_ul = li.find("ul")
                    if sub_ul:
                        # Le li parent est un header (ex: "Admissible Criteria:")
                        header = re.sub(r"\s+", " ", li.get_text(strip=True))
                        header = re.sub(r":.*$", "", header, flags=re.DOTALL).strip()
                        if header:
                            for sub_li in sub_ul.find_all("li"):
                                criteria.append(sub_li.get_text(strip=True))
                    else:
                        if len(text) > 10:
                            criteria.append(text)
            el = el.find_next_sibling()
        break

    return criteria[:12]


def extract_benefits(soup: BeautifulSoup) -> list:
    """Extrait les avantages depuis la section Benefits."""
    content = soup.select_one(".entry-content") or soup.select_one("article")
    if not content:
        return []

    for h in content.find_all(["h2", "h3"]):
        if "benefit" not in h.get_text().lower():
            continue
        ul = h.find_next_sibling(["ul", "ol"])
        if ul:
            return [li.get_text(strip=True) for li in ul.find_all("li", recursive=False)][:10]

    return []


def find_apply_link(soup: BeautifulSoup) -> str:
    """
    SP a souvent un bouton "Apply Now" ou un lien explicite vers le formulaire.
    """
    content = soup.select_one(".entry-content") or soup.select_one("article")
    if not content:
        return ""

    apply_kws = [
        "apply now", "apply here", "apply online",
        "application link", "click here to apply",
        "submit application", "application form",
    ]
    for a in content.find_all("a", href=True):
        href = a.get("href", "")
        text = a.get_text(strip=True).lower()
        if BASE_URL not in href and href.startswith("http"):
            if any(kw in text for kw in apply_kws):
                return href

    # Fallback : lien en gras "Apply Now" (souvent dernier lien de l'article)
    for a in reversed(content.find_all("a", href=True)):
        href = a.get("href", "")
        if href.startswith("http") and BASE_URL not in href:
            return href

    return ""


# ─── Scraping listing ─────────────────────────────────────────────────────────

def scrape_listing(soup: BeautifulSoup, level_hint: Optional[str]) -> list[dict]:
    """
    Extrait les cartes d'articles depuis une page listing SP.

    Thème Make (WordPress) — structure réelle :
      <div class="post-NNN type-post ...">
        <header class="entry-header">
          <h2 class="entry-title"><a href="URL">TITRE</a></h2>
        </header>
      </div>

    Ordre de priorité des sélecteurs :
      1. .entry-title a         ← thème Make, le plus fiable
      2. h2.entry-title a       ← variante
      3. [class*="type-post"] h2 a ← fallback WP générique
      4. Regex URL /YYYY/MM/DD/ ← dernier recours
    """
    items = []
    seen_urls: set = set()

    # ── Sélecteurs CSS (du plus précis au plus large) ──────────────
    entry_links = (
        soup.select(".entry-title a")
        or soup.select("h2.entry-title a")
        or soup.select('[class*="type-post"] h2 a')
        or soup.select(".entry-header h2 a")
    )

    for a_el in entry_links:
        url = a_el.get("href", "")
        title = a_el.get_text(strip=True)

        if not url.startswith("http") or not title:
            continue
        # Exclure liens de navigation (catégories, tags, home)
        if re.search(r"/category/|/tag/|/page/|\?", url):
            continue
        if url in seen_urls:
            continue
        seen_urls.add(url)

        # Remonter au conteneur article pour image + catégories
        container = a_el
        for _ in range(6):
            container = container.parent
            if container is None:
                break
            cls = " ".join(container.get("class", []))
            # Remonter jusqu'au conteneur de l'article complet (pas juste l'en-tête)
            # "type-post" ou "hentry" = div.post-NNN qui contient image + meta
            if "type-post" in cls or "hentry" in cls or container.name == "article":
                break

        # Image (lazy-loaded : vraie URL dans data-src)
        image_url = ""
        if container is not None:
            img = container.find("img")
            if img:
                image_url = (img.get("data-src") or img.get("data-lazy-src")
                             or img.get("src", ""))
                if image_url and image_url.startswith("data:"):
                    image_url = img.get("data-src") or img.get("data-lazy-src", "")

        # Catégories de la card
        cats = []
        if container is not None:
            cats = [a.get_text(strip=True)
                    for a in container.select(".post-categories a, .cat-links a")]

        items.append({
            "titre":      title,
            "url":        url,
            "image_url":  image_url,
            "level_hint": level_hint,
            "cats_card":  cats,
        })

    # ── Fallback regex si aucun sélecteur CSS ne retourne de résultat ──
    if not items:
        log.debug("Sélecteurs CSS vides — fallback regex URL")
        article_url_re = re.compile(
            r'href="(https://scholarship-positions\.com/[^"]+/\d{4}/\d{2}/\d{2}/[^"]*)"' 
        )
        raw_html = str(soup)
        for url in dict.fromkeys(article_url_re.findall(raw_html)):
            if url in seen_urls:
                continue
            seen_urls.add(url)
            slug = url.rstrip("/").split("/")[-4]
            title = slug.replace("-", " ").title()
            items.append({
                "titre":      title,
                "url":        url,
                "image_url":  "",
                "level_hint": level_hint,
                "cats_card":  [],
            })

    return items


def get_next_page(soup: BeautifulSoup, current_url: str) -> Optional[str]:
    next_a = soup.select_one("a.next.page-numbers")
    if next_a:
        return next_a.get("href")
    # Pattern /page/N/
    m = re.search(r"/page/(\d+)/?$", current_url.rstrip("/"))
    if m:
        n = int(m.group(1)) + 1
        base = re.sub(r"/page/\d+/?$", "", current_url.rstrip("/"))
        return f"{base}/page/{n}/"
    return current_url.rstrip("/") + "/page/2/"


def get_total_pages(soup: BeautifulSoup) -> int:
    nums = soup.select("a.page-numbers:not(.next):not(.prev)")
    if nums:
        try:
            return int(nums[-1].get_text(strip=True))
        except ValueError:
            pass
    return 1


# ─── Scraping article ─────────────────────────────────────────────────────────

def scrape_article(url: str, base_info: dict, session: requests.Session) -> Bourse:
    """
    Scrape un article scholarship-positions.com.
    Point fort : extraction structurée du bloc Brief Description.
    """
    log.info(f"  → {base_info['titre'][:65]}...")

    bourse = Bourse(
        id=make_id(url),
        url=url,
        titre=base_info["titre"],
        image_url=base_info.get("image_url", ""),
    )

    soup = fetch(url, session)
    if not soup:
        if base_info.get("level_hint"):
            bourse.niveau_etude = [base_info["level_hint"]]
        return bourse

    # ── Image HD via meta og ──────────────────────────────────────
    og_img = soup.select_one("meta[property='og:image']")
    if og_img:
        bourse.image_url = og_img.get("content", bourse.image_url)

    # ── Date publication via meta (ISO complète) ──────────────────
    pub_meta = soup.select_one("meta[property='article:published_time']")
    if pub_meta:
        bourse.date_publication = pub_meta.get("content", "")

    # ── Deadline ─────────────────────────────────────────────────
    bourse.deadline_raw, bourse.deadline = extract_deadline(soup)

    # ── Brief Description — extraction par label ──────────────────
    # C'est le point fort du site : chaque champ est nommé explicitement

    uni = extract_brief_field(soup, "University or Organization")
    bourse.universite = uni

    bourse.departement = extract_brief_field(soup, "Department")

    # Niveau d'études
    niveau_raw = extract_brief_field(soup, "Course Level")
    bourse.niveau_etude = normalize_niveaux(niveau_raw, base_info.get("level_hint"))

    # Financement
    award_raw = extract_brief_field(soup, "Award")
    bourse.financement = normalize_financement(award_raw)

    # Nombre de bourses
    bourse.nb_bourses = extract_brief_field(soup, "Number of Awards")

    # Nationalité éligible
    nat_raw = extract_brief_field(soup, "Nationality")
    bourse.nationalites_eligibles = parse_countries_field(nat_raw) if nat_raw else []

    # Pays de destination
    pays_raw = extract_brief_field(soup, "The award can be taken in")
    bourse.pays_destination = parse_countries_field(pays_raw) if pays_raw else []

    # ── Éligibilité détaillée ─────────────────────────────────────
    bourse.criteres = extract_eligibility_criteria(soup)

    # Langues requises depuis les critères
    criteres_text = " ".join(bourse.criteres)
    bourse.langues_requises = detect_language(criteres_text)

    # ── Avantages ─────────────────────────────────────────────────
    bourse.avantages = extract_benefits(soup)

    # ── Description (meta ou premier paragraphe) ──────────────────
    desc_meta = soup.select_one("meta[name='description']")
    if desc_meta:
        bourse.description = desc_meta.get("content", "")[:600]
    else:
        content = soup.select_one(".entry-content")
        if content:
            paras = [p.get_text(strip=True) for p in content.select("p")
                     if len(p.get_text(strip=True)) > 50]
            bourse.description = " ".join(paras[:2])[:600]

    # ── Domaines depuis les tags WordPress ───────────────────────
    # Les tags SP contiennent les pays ET les domaines — on filtre
    all_tags = [a.get_text(strip=True) for a in soup.select(".post-tags a, .tags-links a")]
    bourse.tags_sp = all_tags

    # Tags qui sont des domaines (pas des noms de pays ou d'universités)
    country_like = {"africa", "asia", "europe", "latin america", "phd", "master",
                    "scholarship", "fellowship", "international", "fully funded"}
    bourse.domaines = [t for t in all_tags
                       if t.lower() not in country_like
                       and not re.search(r"university|institute|college", t, re.I)
                       and len(t) > 3][:8]

    # ── Catégories WordPress ──────────────────────────────────────
    bourse.categories_sp = [a.get_text(strip=True)
                             for a in soup.select(".post-categories a, .cat-links a")]

    # ── Lien de candidature ───────────────────────────────────────
    bourse.lien_candidature = find_apply_link(soup)

    # ── Active ? ─────────────────────────────────────────────────
    if bourse.deadline:
        try:
            dl = datetime.fromisoformat(bourse.deadline).date()
            bourse.active = dl >= date.today()
        except ValueError:
            pass

    return bourse


# ─── Pipeline de scraping ─────────────────────────────────────────────────────

def scrape_category(
    category: str,
    max_pages: int = 999,
    delay: float = DELAY,
    session: Optional[requests.Session] = None,
) -> list[Bourse]:
    """Scrape une catégorie complète de scholarship-positions.com."""
    if session is None:
        session = requests.Session()
        session.headers.update(HEADERS)

    level_hint = CATEGORIES.get(category)
    current_url = f"{BASE_URL}/category/{category}/"
    page = 1
    bourses: list[Bourse] = []
    seen_urls: set[str] = set()

    while page <= max_pages:
        log.info(f"[SP/{category}] Page {page}: {current_url}")
        soup = fetch(current_url, session)
        if not soup:
            break

        if page == 1:
            total = get_total_pages(soup)
            log.info(f"  Total pages: {total}")
            max_pages = min(max_pages, total)

        items = scrape_listing(soup, level_hint)
        if not items:
            log.info("  Aucun article.")
            break

        log.info(f"  {len(items)} articles")

        for item in items:
            url = item["url"]
            if url in seen_urls:
                continue
            seen_urls.add(url)
            time.sleep(delay)
            b = scrape_article(url, item, session)
            bourses.append(b)

        next_url = get_next_page(soup, current_url)
        if not next_url or next_url == current_url:
            break
        current_url = next_url
        page += 1
        time.sleep(delay)

    log.info(f"[SP/{category}] {len(bourses)} bourses collectées")
    return bourses


def scrape_sp(
    categories: list[str] = None,
    max_pages: int = 999,
    delay: float = DELAY,
) -> list[Bourse]:
    """Pipeline principal — plusieurs catégories, déduplication."""
    if categories is None:
        categories = ["africa-scholarships", "masters-scholarships",
                      "phd-scholarships-positions"]

    session = requests.Session()
    session.headers.update(HEADERS)

    all_bourses: list[Bourse] = []
    seen: set[str] = set()

    for cat in categories:
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
    with open(path, "w", encoding="utf-8") as f:
        json.dump([asdict(b) for b in bourses], f,
                  ensure_ascii=False, indent=2, default=str)
    log.info(f"💾 {path} ({len(bourses)} bourses)")


def to_supabase(bourses: list[Bourse], url: str, key: str) -> None:
    try:
        from supabase import create_client
    except ImportError:
        log.error("pip install supabase")
        return
    client = create_client(url, key)
    # Retirer les champs spécifiques SP non présents dans le schéma partagé
    data = []
    for b in bourses:
        d = asdict(b)
        d.pop("categories_sp", None)
        d.pop("tags_sp", None)
        data.append(d)
    client.table("bourses").upsert(data).execute()
    log.info(f"✅ {len(data)} bourses → Supabase")


def print_stats(bourses: list[Bourse]) -> None:
    total = len(bourses)
    if not total:
        return
    active  = sum(1 for b in bourses if b.active)
    funded  = sum(1 for b in bourses if b.financement == "TOTAL")
    with_dl = sum(1 for b in bourses if b.deadline)
    with_pays  = sum(1 for b in bourses if b.pays_destination)
    with_crit  = sum(1 for b in bourses if b.criteres)
    with_uni   = sum(1 for b in bourses if b.universite)
    levels = {}
    for b in bourses:
        for lv in b.niveau_etude:
            levels[lv] = levels.get(lv, 0) + 1

    print(f"\n📊 Rapport scholarship-positions.com:")
    print(f"  Total           : {total}")
    print(f"  Actives         : {active} ({active*100//total}%)")
    print(f"  Entièrement fin.: {funded} ({funded*100//total}%)")
    print(f"  Avec deadline   : {with_dl} ({with_dl*100//total}%)")
    print(f"  Avec université : {with_uni} ({with_uni*100//total}%)")
    print(f"  Avec pays       : {with_pays} ({with_pays*100//total}%)")
    print(f"  Avec critères   : {with_crit} ({with_crit*100//total}%)")
    print(f"  Par niveau      : {levels}")


# ─── CLI ───────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="FlyAI — Scraper scholarship-positions.com")
    parser.add_argument(
        "--categories", nargs="+",
        default=["africa-scholarships", "masters-scholarships", "phd-scholarships-positions"],
        choices=list(CATEGORIES.keys()),
    )
    parser.add_argument("--pages",  type=int,   default=5)
    parser.add_argument("--delay",  type=float, default=1.5)
    parser.add_argument("--output", default="bourses_sp.json")
    parser.add_argument("--push-supabase", action="store_true")
    args = parser.parse_args()

    bourses = scrape_sp(args.categories, args.pages, args.delay)
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