"""
FlyAI — Scraper Erasmus Mundus complet
Pipeline : EMA listing → pages individuelles des programmes → JSON normalisé
Compatibilité totale avec sp_scraper.py (même dataclass Bourse)

Installation : pip install requests beautifulsoup4 lxml selenium webdriver-manager
Usage :
    python erasmus_scraper.py                      # pipeline complet EMA
    python erasmus_scraper.py --source eacea       # via Selenium EACEA
    python erasmus_scraper.py --pages 5
    python erasmus_scraper.py --push-supabase
    python erasmus_scraper.py --test-url https://...
"""

import re, json, time, hashlib, logging, argparse
from datetime import datetime, date
from dataclasses import dataclass, field, asdict
from typing import Optional

import requests
from bs4 import BeautifulSoup

# ─── Config ──────────────────────────────────────────────────────────────────

BASE_EMA   = "https://www.erasmusmundus.eu"
LIST_URL   = f"{BASE_EMA}/programmes/"
DELAY      = 2.0

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/124.0.0.0",
    "Accept": "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://www.google.com/",
}

MONTH_MAP = {
    "january":"01","february":"02","march":"03","april":"04",
    "may":"05","june":"06","july":"07","august":"08",
    "september":"09","october":"10","november":"11","december":"12",
    "jan":"01","feb":"02","mar":"03","apr":"04",
    "jun":"06","jul":"07","aug":"08","sep":"09",
    "oct":"10","nov":"11","dec":"12",
}

# Mots-clés pour flag africains_eligibles
AFRICAN_KW = {
    "africa","african","nigeria","kenya","ghana","ethiopia","senegal",
    "cameroon","togo","benin","mali","niger","rwanda","uganda","zambia",
    "mozambique","zimbabwe","malawi","namibia","botswana","south africa",
    "egypt","morocco","tunisia","algeria","congo","sudan","all countries",
    "all nationalities","international students","worldwide","developing countries",
}

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("flyai.erasmus")


# ─── Modèle de données (aligné sp_scraper.py) ────────────────────────────────

@dataclass
class Bourse:
    id:                     str  = ""
    titre:                  str  = ""
    url:                    str  = ""
    url_programme:          str  = ""     # site officiel du consortium
    deadline:               Optional[str] = None
    deadline_raw:           str  = ""
    universite:             str  = ""     # université coordinatrice
    universites_partenaires: list = field(default_factory=list)
    pays_destination:       list = field(default_factory=list)  # pays d'étude
    niveau_etude:           list = field(default_factory=list)
    financement:            str  = "TOTAL"   # Erasmus = toujours TOTAL
    montant_mensuel:        str  = "€1,400/mois"
    duree_mois:             int  = 24
    nationalites_eligibles: list = field(default_factory=list)
    africains_eligibles:    bool = True    # Erasmus ouvert à tous pays
    domaines:               list = field(default_factory=list)
    langues_requises:       list = field(default_factory=list)
    description:            str  = ""
    avantages:              list = field(default_factory=list)
    criteres:               list = field(default_factory=list)
    lien_candidature:       str  = ""
    image_url:              str  = ""
    date_publication:       Optional[str] = None
    annee:                  Optional[int] = None
    tags_erasmus:           list = field(default_factory=list)
    source:                 str  = "erasmus-mundus"
    active:                 bool = True


# ─── Utilitaires (même logique que sp_scraper.py) ────────────────────────────

def make_id(url: str) -> str:
    return "em_" + hashlib.sha1(url.encode()).hexdigest()[:12]


def fetch(url: str, session: requests.Session, retries: int = 3) -> Optional[BeautifulSoup]:
    for attempt in range(1, retries + 1):
        try:
            r = session.get(url, headers=HEADERS, timeout=15)
            if r.status_code == 404:
                return None
            r.raise_for_status()
            return BeautifulSoup(r.text, "lxml")
        except requests.RequestException as e:
            log.warning(f"Fetch error ({attempt}/{retries}) {url}: {e}")
            if attempt < retries:
                time.sleep(2 ** attempt)
    return None


def parse_deadline(raw: str) -> Optional[str]:
    text = re.sub(r"[^\w\s/\-,]", " ", raw.strip().lower())
    # "31 january 2026"
    m = re.search(r"(\d{1,2})\s+(\w+)\s+(\d{4})", text)
    if m:
        d, mo, y = m.groups()
        month = MONTH_MAP.get(mo)
        if month:
            return f"{y}-{month}-{d.zfill(2)}"
    # "january 31, 2026"
    m = re.search(r"(\w+)\s+(\d{1,2})[,\s]+(\d{4})", text)
    if m:
        mo, d, y = m.groups()
        month = MONTH_MAP.get(mo)
        if month:
            return f"{y}-{month}-{d.zfill(2)}"
    # ISO "2026-01-31"
    m = re.search(r"(\d{4})-(\d{2})-(\d{2})", text)
    if m:
        return m.group(0)
    return None


def detect_language(text: str) -> list:
    langs = []
    if re.search(r"\benglish\b", text, re.I):  langs.append("Anglais")
    if re.search(r"\bfrench\b|\bfrançais\b", text, re.I): langs.append("Français")
    if re.search(r"\bgerman\b|\bdeutsch\b", text, re.I):  langs.append("Allemand")
    if re.search(r"\bspanish\b", text, re.I): langs.append("Espagnol")
    return langs


def is_african_eligible(text: str, nationalites: list) -> bool:
    combined = (text + " ".join(nationalites)).lower()
    return any(kw in combined for kw in AFRICAN_KW)


def extract_year(titre: str) -> Optional[int]:
    m = re.search(r"\b(202[4-9]|203\d)\b", titre)
    return int(m.group(0)) if m else None


# ─── Scraping listing EMA ─────────────────────────────────────────────────────

def scrape_listing_ema(soup: BeautifulSoup) -> list[dict]:
    """
    EMA — erasmusmundus.eu/programmes/
    Structure : cartes de programmes avec titre, domaine, lien.
    """
    items = []
    seen = set()

    # Sélecteurs EMA (WordPress/custom theme)
    links = (
        soup.select(".programme-title a")
        or soup.select(".entry-title a")
        or soup.select("h2 a, h3 a")
        or soup.select("article a[href*='/programmes/']")
    )

    for a in links:
        url = a.get("href", "").strip()
        titre = a.get_text(strip=True)
        if not url or not titre or url in seen:
            continue
        if len(titre) < 10:
            continue
        seen.add(url)

        # Remonter pour trouver domaine/tags
        parent = a.parent
        for _ in range(5):
            if parent is None:
                break
            parent = parent.parent
            if parent and parent.find("img"):
                break

        domaine = ""
        image_url = ""
        if parent:
            cat_el = parent.select_one("[class*='category'], [class*='subject'], [class*='field']")
            if cat_el:
                domaine = cat_el.get_text(strip=True)
            img = parent.find("img")
            if img:
                image_url = img.get("data-src") or img.get("src", "")

        items.append({
            "titre": titre,
            "url": url if url.startswith("http") else f"{BASE_EMA}{url}",
            "domaine": domaine,
            "image_url": image_url,
        })

    log.info(f"  {len(items)} programmes trouvés")
    return items


def get_next_page_ema(soup: BeautifulSoup, page: int) -> Optional[str]:
    """Pagination EMA : /programmes/page/N/ ou ?paged=N."""
    next_a = soup.select_one("a.next, a[rel='next']")
    if next_a:
        return next_a.get("href")
    return f"{LIST_URL}page/{page + 1}/"


# ─── Scraping page programme ──────────────────────────────────────────────────

def scrape_programme(url: str, base_info: dict, session: requests.Session) -> Bourse:
    """
    Scrape une page individuelle de programme Erasmus Mundus.
    Chaque programme a sa propre structure mais des éléments communs :
    - Liste d'universités partenaires
    - Domaines / disciplines
    - Deadline de candidature
    - Lien vers le site officiel du consortium
    """
    log.info(f"  → {base_info['titre'][:60]}...")

    bourse = Bourse(
        id          = make_id(url),
        url         = url,
        titre       = base_info["titre"],
        image_url   = base_info.get("image_url", ""),
        domaines    = [base_info["domaine"]] if base_info.get("domaine") else [],
        annee       = extract_year(base_info["titre"]),
        niveau_etude= ["master"],   # Erasmus Mundus = exclusivement master
        financement = "TOTAL",      # Toujours entièrement financé
        avantages   = [
            "Tuition fees waiver",
            "Monthly stipend €1,400",
            "Travel allowance",
            "Installation allowance",
            "Health insurance",
        ],
        africains_eligibles = True,  # Open to all nationalities
        nationalites_eligibles = ["Tous"],
    )

    soup = fetch(url, session)
    if not soup:
        return bourse

    # ── Titre depuis h1 ───────────────────────────────────────────────────────
    h1 = soup.find("h1")
    if h1:
        bourse.titre = h1.get_text(strip=True)
        bourse.annee = extract_year(bourse.titre)

    # ── Image HD ──────────────────────────────────────────────────────────────
    og_img = soup.select_one("meta[property='og:image']")
    if og_img:
        bourse.image_url = og_img.get("content", bourse.image_url)

    # ── Description ───────────────────────────────────────────────────────────
    desc_meta = soup.select_one("meta[name='description']")
    if desc_meta:
        bourse.description = desc_meta.get("content", "")[:600]
    if not bourse.description:
        content = soup.select_one(".entry-content, article, main")
        if content:
            paras = [p.get_text(strip=True) for p in content.select("p")
                     if len(p.get_text(strip=True)) > 60]
            bourse.description = " ".join(paras[:2])[:600]

    # ── Universités partenaires ───────────────────────────────────────────────
    univs = []
    for h in soup.find_all(["h2", "h3", "h4"]):
        if any(kw in h.get_text().lower() for kw in
               ["partner", "consortium", "universities", "institutions"]):
            ul = h.find_next_sibling(["ul", "ol"])
            if ul:
                univs = [li.get_text(strip=True) for li in ul.find_all("li")][:10]
            break

    # Fallback : chercher les logos d'universités avec alt text
    if not univs:
        univ_imgs = soup.select("img[alt*='University'], img[alt*='university']")
        univs = [img.get("alt", "") for img in univ_imgs if img.get("alt")][:10]

    bourse.universites_partenaires = univs
    if univs:
        bourse.universite = univs[0]  # Coordinateur = premier de la liste

    # ── Pays d'étude (dérivés des universités partenaires) ────────────────────
    # Les pays sont souvent mentionnés dans la liste des partenaires
    country_mentions = []
    partner_text = " ".join(univs)
    eu_countries = [
        "France", "Germany", "Spain", "Italy", "Netherlands", "Belgium",
        "Portugal", "Sweden", "Austria", "Denmark", "Finland", "Poland",
        "Czech Republic", "Hungary", "Romania", "Greece", "Ireland",
        "Luxembourg", "Slovenia", "Slovakia", "Croatia", "Estonia",
        "Latvia", "Lithuania", "Bulgaria", "Cyprus", "Malta",
    ]
    for country in eu_countries:
        if country.lower() in partner_text.lower():
            country_mentions.append(country)

    # Chercher les pays explicitement listés sur la page
    for h in soup.find_all(["h2", "h3", "h4"]):
        if "countr" in h.get_text().lower():
            ul = h.find_next_sibling(["ul", "ol", "p"])
            if ul:
                text = ul.get_text(strip=True)
                for country in eu_countries:
                    if country.lower() in text.lower() and country not in country_mentions:
                        country_mentions.append(country)
            break

    bourse.pays_destination = list(dict.fromkeys(country_mentions))[:8]

    # ── Deadline ──────────────────────────────────────────────────────────────
    content = soup.select_one(".entry-content, article, main")
    if content:
        text = content.get_text(" ", strip=True)
        dl_match = re.search(
            r"(?:deadline|closing|apply by|applications? (?:close|due))[:\s]+"
            r"([A-Za-z0-9\s,]+?\d{4})",
            text, re.IGNORECASE
        )
        if dl_match:
            raw = dl_match.group(1).strip()[:80]
            bourse.deadline_raw = raw
            bourse.deadline = parse_deadline(raw)

    # ── Domaines (enrichissement) ─────────────────────────────────────────────
    if not bourse.domaines or bourse.domaines == [""]:
        for h in soup.find_all(["h2", "h3", "h4"]):
            if any(kw in h.get_text().lower() for kw in
                   ["field", "subject", "discipline", "area", "topic"]):
                ul = h.find_next_sibling(["ul", "ol"])
                if ul:
                    bourse.domaines = [li.get_text(strip=True)
                                       for li in ul.find_all("li")][:6]
                break

    # ── Langues requises ──────────────────────────────────────────────────────
    if content:
        bourse.langues_requises = detect_language(content.get_text())

    # ── Lien de candidature (site du consortium) ──────────────────────────────
    if content:
        apply_kws = ["apply now", "apply here", "official website",
                     "application", "apply online", "programme website"]
        for a in content.find_all("a", href=True):
            href = a.get("href", "")
            text_a = a.get_text(strip=True).lower()
            if href.startswith("http") and BASE_EMA not in href:
                if any(kw in text_a for kw in apply_kws):
                    bourse.lien_candidature = href
                    break
        # Fallback : premier lien externe
        if not bourse.lien_candidature:
            for a in content.find_all("a", href=True):
                href = a.get("href", "")
                if href.startswith("http") and BASE_EMA not in href:
                    bourse.lien_candidature = href
                    break

    bourse.url_programme = bourse.lien_candidature

    # ── Éligibilité africaine (Erasmus = toujours ouvert) ────────────────────
    # Erasmus Mundus est ouvert à TOUTES nationalités
    # Cependant certains programmes ont des restrictions → vérifier
    if content:
        text_lower = content.get_text().lower()
        # Si "EU students only" ou "European students only" → restreint
        if re.search(r"eu\s+students?\s+only|europe(?:an)?\s+only", text_lower):
            bourse.africains_eligibles = False
            bourse.nationalites_eligibles = ["EU students only"]
        else:
            bourse.africains_eligibles = True
            bourse.nationalites_eligibles = ["Tous"]

    # ── Tags ─────────────────────────────────────────────────────────────────
    bourse.tags_erasmus = [
        "Erasmus Mundus", "Master", "Fully Funded",
        *bourse.domaines[:2],
        *bourse.pays_destination[:2],
    ]

    # ── Statut actif ──────────────────────────────────────────────────────────
    if bourse.deadline:
        try:
            dl = datetime.fromisoformat(bourse.deadline).date()
            bourse.active = dl >= date.today()
        except ValueError:
            pass

    return bourse


# ─── Pipeline principal ───────────────────────────────────────────────────────

def scrape_erasmus(max_pages: int = 999, delay: float = DELAY) -> list[Bourse]:
    """
    Pipeline complet Erasmus Mundus via EMA.
    Même interface que scrape_sp() et scrape_sa().
    """
    session = requests.Session()
    session.headers.update(HEADERS)

    all_items = []
    seen_urls = set()
    page = 1

    log.info("📋 Phase 1 — Collecte du listing EMA...")

    while page <= max_pages:
        url = LIST_URL if page == 1 else f"{LIST_URL}page/{page}/"
        log.info(f"[Erasmus] Page {page}: {url}")
        soup = fetch(url, session)
        if not soup:
            break

        items = scrape_listing_ema(soup)
        if not items:
            log.info("  Fin du listing.")
            break

        new_count = 0
        for item in items:
            if item["url"] not in seen_urls:
                seen_urls.add(item["url"])
                all_items.append(item)
                new_count += 1

        log.info(f"  {new_count} nouveaux (total: {len(all_items)})")
        page += 1
        time.sleep(delay)

    log.info(f"\n✅ Phase 1 terminée : {len(all_items)} programmes")

    # Phase 2 : détails
    log.info("\n📖 Phase 2 — Scraping des pages détail...")
    bourses = []

    for i, item in enumerate(all_items, 1):
        log.info(f"[{i}/{len(all_items)}] {item['titre'][:55]}...")
        b = scrape_programme(item["url"], item, session)
        bourses.append(b)
        time.sleep(delay)

        if i % 20 == 0:
            _save_json(bourses, "bourses_erasmus.json.tmp")

    return bourses


def _save_json(bourses, path):
    import json
    with open(path, "w", encoding="utf-8") as f:
        json.dump([asdict(b) for b in bourses], f,
                  ensure_ascii=False, indent=2, default=str)


def to_json(bourses: list[Bourse], path: str) -> None:
    _save_json(bourses, path)
    log.info(f"💾 {path} ({len(bourses)} bourses)")


def to_supabase(bourses: list[Bourse], url: str, key: str) -> None:
    try:
        from supabase import create_client
    except ImportError:
        log.error("pip install supabase")
        return
    client = create_client(url, key)
    data = []
    for b in bourses:
        d = asdict(b)
        d.pop("tags_erasmus", None)
        data.append(d)
    client.table("bourses").upsert(data).execute()
    log.info(f"✅ {len(data)} bourses → Supabase")


def print_stats(bourses: list[Bourse]) -> None:
    total = len(bourses)
    if not total:
        return
    active    = sum(1 for b in bourses if b.active)
    with_dl   = sum(1 for b in bourses if b.deadline)
    africains = sum(1 for b in bourses if b.africains_eligibles)
    with_pays = sum(1 for b in bourses if b.pays_destination)
    with_dom  = sum(1 for b in bourses if b.domaines)

    print(f"\n📊 Rapport Erasmus Mundus :")
    print(f"  Total              : {total}")
    print(f"  Actives            : {active} ({active*100//total}%)")
    print(f"  Entièrement fin.   : {total} (100%) — Erasmus = toujours TOTAL")
    print(f"  Avec deadline      : {with_dl} ({with_dl*100//total}%)")
    print(f"  Avec pays d'étude  : {with_pays} ({with_pays*100//total}%)")
    print(f"  Avec domaines      : {with_dom} ({with_dom*100//total}%)")
    print(f"  Africains élig.    : {africains} ({africains*100//total}%)")
    print(f"  Niveau             : {{'master': {total}}}")
    print(f"  Financement        : {{'TOTAL': {total}}}")


def main():
    parser = argparse.ArgumentParser(
        description="FlyAI — Scraper Erasmus Mundus (EMA + EACEA)"
    )
    parser.add_argument("--source", choices=["ema", "eacea"], default="ema",
                        help="Source : ema (défaut, sans Selenium) ou eacea (avec Selenium)")
    parser.add_argument("--pages",  type=int,   default=999)
    parser.add_argument("--delay",  type=float, default=DELAY)
    parser.add_argument("--output", default="bourses_erasmus.json")
    parser.add_argument("--push-supabase", action="store_true")
    parser.add_argument("--test-url", type=str, default=None)
    args = parser.parse_args()

    if args.test_url:
        session = requests.Session()
        session.headers.update(HEADERS)
        item = {"titre": "Test", "url": args.test_url,
                "domaine": "", "image_url": ""}
        b = scrape_programme(args.test_url, item, session)
        print(json.dumps(asdict(b), ensure_ascii=False, indent=2, default=str))
        return

    if args.source == "eacea":
        log.info("Mode EACEA — Selenium requis (pip install selenium webdriver-manager)")
        log.info("Voir la fonction make_driver() + get_all_programmes_eacea()")
        return

    bourses = scrape_erasmus(args.pages, args.delay)
    to_json(bourses, args.output)
    print_stats(bourses)

    if args.push_supabase:
        import os
        to_supabase(bourses, os.environ.get("SUPABASE_URL",""),
                    os.environ.get("SUPABASE_KEY",""))


if __name__ == "__main__":
    main()