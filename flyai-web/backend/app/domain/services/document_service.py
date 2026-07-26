"""
FlyAI Document Service — §4.5
Génération du dossier pré-rempli :
  - Checklist des pièces exactes par bourse
  - Trame de lettre de motivation §8.1 (ton mentor académique)
  - Plan de travail basé sur la deadline réelle
"""

from __future__ import annotations

import os
from datetime import date, datetime, timedelta
from typing import Any

import httpx


# ─────────────────────────────────────────────────────────────
# Checklists de documents par type de bourse
# ─────────────────────────────────────────────────────────────

BASE_DOCUMENTS = [
    {"type": "cv", "label": "CV académique au format international (2 pages max)", "is_eliminating": True},
    {"type": "motivation_letter", "label": "Lettre de motivation (à rédiger avec FlyAgent)", "is_eliminating": True},
    {"type": "transcripts", "label": "Relevés de notes officiels des 3 dernières années", "is_eliminating": True},
    {"type": "diploma_copy", "label": "Copie du diplôme le plus récent (ou attestation de scolarité)", "is_eliminating": False},
    {"type": "id_document", "label": "Copie du passeport ou de la carte nationale d'identité", "is_eliminating": False},
]

LANGUAGE_DOCUMENTS = [
    {"type": "language_test", "label": "Résultat officiel de test de langue (TOEFL / IELTS / DELF / TCF)", "is_eliminating": True},
]

RECOMMENDATION_DOCUMENTS = [
    {"type": "recommendation_1", "label": "Lettre de recommandation — Professeur référent 1", "is_eliminating": True},
    {"type": "recommendation_2", "label": "Lettre de recommandation — Professeur référent 2", "is_eliminating": False},
]

FINANCIAL_DOCUMENTS = [
    {"type": "financial_statement", "label": "Justificatif de situation financière (relevé de compte ou attestation)", "is_eliminating": False},
]

RESEARCH_DOCUMENTS = [
    {"type": "research_proposal", "label": "Projet de recherche détaillé (5–10 pages)", "is_eliminating": True},
    {"type": "publications", "label": "Liste des publications ou travaux académiques (si applicable)", "is_eliminating": False},
]


def generate_checklist(scholarship: dict[str, Any]) -> list[dict[str, Any]]:
    """
    Génère la checklist des pièces requises pour cette bourse précise.
    Jamais une checklist générique — adaptée aux critères de la bourse.
    """
    docs = list(BASE_DOCUMENTS)

    criteres = [c.lower() for c in (scholarship.get("criteres") or [])]
    description = (scholarship.get("description") or "").lower()
    niveau = [n.lower() for n in (scholarship.get("niveau_etude") or scholarship.get("degree_level") or [])]

    # Langue
    has_lang_req = any(
        k in description or any(k in c for c in criteres)
        for k in ["toefl", "ielts", "delf", "tcf", "language", "anglais", "français"]
    )
    if has_lang_req or scholarship.get("niveau_langue"):
        docs.extend(LANGUAGE_DOCUMENTS)

    # Recommandations (presque toujours requises pour les bourses d'excellence)
    docs.extend(RECOMMENDATION_DOCUMENTS)

    # Doctorat → projet de recherche
    is_phd = any(k in n for n in niveau for k in ["doctorat", "phd", "recherche", "postdoc"])
    if is_phd:
        docs.extend(RESEARCH_DOCUMENTS)

    # Vérification financière si bourse partielle
    funding = (scholarship.get("financement") or "").upper()
    if funding == "PARTIEL":
        docs.extend(FINANCIAL_DOCUMENTS)

    return [{"status": "missing", **doc} for doc in docs]


# ─────────────────────────────────────────────────────────────
# Trame de lettre de motivation
# ─────────────────────────────────────────────────────────────

COVER_LETTER_SYSTEM_PROMPT = """Tu es FlyAgent, copilote de candidature de FlyAI.
Ta mission : générer une trame de lettre de motivation pour une bourse d'études.

RÈGLES ABSOLUES (§8.1) :
- Vouvoiement systématique
- Ton de mentor académique : direct, factuel, sans formules creuses
- Aucun emoji, aucun compliment gratuit dans la lettre
- La lettre doit structurer le raisonnement du jury autour de 3 points :
  1. Cohérence académique (pourquoi ce niveau, ce domaine)
  2. Motivation précise pour CE programme (pas "étudier à l'étranger" en général)
  3. Projet après la bourse (impact, retour, valorisation)
- Laisser des balises [À COMPLÉTER : ...] pour les éléments que l'utilisateur doit personnaliser
- Longueur : 400–500 mots maximum
- Format : paragraphes sans puces (format lettre formelle)

Interdiction : jamais de phrases génériques comme "C'est avec un grand enthousiasme que..."
"""


def generate_cover_letter_draft(
    scholarship: dict[str, Any],
    profile: dict[str, Any],
) -> str:
    """
    Génère une trame de lettre de motivation pré-remplie via Groq (fallback textuel).
    Conforme §8.1 : ton mentor, vouvoiement, orienté action.
    """
    groq_key = os.environ.get("GROQ_API_KEY")
    scholarship_name = scholarship.get("titre") or scholarship.get("title", "cette bourse")
    user_field = profile.get("field_of_study") or profile.get("fieldOfStudy", "[votre domaine]")
    user_degree = profile.get("degree_level") or profile.get("degreeLevel", "[votre niveau]")
    user_name = profile.get("full_name") or profile.get("fullName", "[Votre Nom]")
    destinations = ", ".join(scholarship.get("pays_destination") or scholarship.get("country") or ["[pays cible]"])

    user_prompt = f"""Génère une trame de lettre de motivation pour :
Bourse : {scholarship_name}
Pays : {destinations}
Candidat : {user_name} — {user_degree} en {user_field}
Description de la bourse : {(scholarship.get('description') or '')[:300]}

Structure attendue : accroche factuelle → cohérence académique → motivation spécifique → projet post-bourse → conclusion engagée.
Laisser des balises [À COMPLÉTER : indication précise] pour les éléments personnels manquants."""

    if groq_key:
        try:
            import urllib.request, json
            payload = json.dumps({
                "model": "llama-3.3-70b-versatile",
                "messages": [
                    {"role": "system", "content": COVER_LETTER_SYSTEM_PROMPT},
                    {"role": "user", "content": user_prompt},
                ],
                "temperature": 0.5,
                "max_tokens": 900,
            }).encode()
            req = urllib.request.Request(
                "https://api.groq.com/openai/v1/chat/completions",
                data=payload,
                headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {groq_key}",
                },
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=20) as resp:
                data = json.loads(resp.read())
                content = data["choices"][0]["message"]["content"]
                if content:
                    return content
        except Exception as e:
            print(f"[document_service] Groq cover letter generation failed: {e}")

    # Fallback structuré si l'API est indisponible
    return f"""[Votre Prénom Nom]
[Votre adresse]
[Ville, Date]

Objet : Candidature à la bourse {scholarship_name}

Madame, Monsieur,

[À COMPLÉTER : une phrase d'accroche factuelle sur votre parcours — éviter toute formule générique comme "c'est avec enthousiasme que..."]

Actuellement en {user_degree} de {user_field}, [À COMPLÉTER : décrivez en 2–3 phrases la logique de votre parcours académique et comment elle vous a conduit à candidater à ce programme précis, pas à "étudier à l'étranger" en général].

Ce programme m'intéresse précisément parce que [À COMPLÉTER : citez un élément spécifique du programme — un laboratoire, un module, un réseau, une approche pédagogique — que vous ne retrouvez pas ailleurs]. Ce n'est pas la destination géographique qui motive ma candidature, mais [À COMPLÉTER : la valeur académique ou professionnelle précise de ce programme pour votre projet].

À l'issue de cette formation, [À COMPLÉTER : décrivez concrètement ce que vous ferez des compétences acquises — retour dans votre pays, projet entrepreneurial, poste visé, contribution à votre secteur]. La bourse {scholarship_name} ne représente pas une fin en soi, mais l'accélérateur d'un projet déjà structuré.

Je reste disponible pour tout entretien complémentaire et vous adresse mes sincères salutations.

{user_name}
"""


# ─────────────────────────────────────────────────────────────
# Plan de travail
# ─────────────────────────────────────────────────────────────

def generate_work_plan(
    scholarship: dict[str, Any],
    days_remaining: int,
) -> list[dict[str, Any]]:
    """
    Génère un plan de travail en étapes basé sur le nombre de jours restants.
    Conforme §4.3 étape 6 : actions concrètes avec dates.
    """
    today = date.today()

    if days_remaining <= 0:
        return [{"step": 1, "label": "Deadline dépassée", "due": today.isoformat(), "status": "overdue"}]

    if days_remaining <= 7:
        steps = [
            {"step": 1, "label": "Rassembler tous les documents existants", "days_from_now": 1},
            {"step": 2, "label": "Finaliser et relire la lettre de motivation", "days_from_now": 3},
            {"step": 3, "label": "Vérifier la complétude du dossier", "days_from_now": days_remaining - 1},
            {"step": 4, "label": "Soumettre le dossier", "days_from_now": days_remaining},
        ]
    elif days_remaining <= 21:
        steps = [
            {"step": 1, "label": "Rassembler les documents administratifs (passeport, relevés)", "days_from_now": 2},
            {"step": 2, "label": "Rédiger le premier brouillon de la lettre de motivation avec FlyAgent", "days_from_now": 5},
            {"step": 3, "label": "Obtenir les lettres de recommandation", "days_from_now": 10},
            {"step": 4, "label": "Réviser et affiner la lettre de motivation", "days_from_now": 14},
            {"step": 5, "label": "Vérification finale du dossier complet", "days_from_now": days_remaining - 2},
            {"step": 6, "label": "Soumettre le dossier", "days_from_now": days_remaining},
        ]
    else:
        quarter = days_remaining // 4
        steps = [
            {"step": 1, "label": "Rassembler les documents administratifs", "days_from_now": 3},
            {"step": 2, "label": "Rédiger le premier brouillon de la lettre de motivation", "days_from_now": quarter},
            {"step": 3, "label": "Contacter les professeurs pour les lettres de recommandation", "days_from_now": quarter + 5},
            {"step": 4, "label": "Obtenir les tests de langue si requis", "days_from_now": quarter * 2},
            {"step": 5, "label": "Révision complète du dossier avec FlyAgent", "days_from_now": quarter * 3},
            {"step": 6, "label": "Relecture finale et corrections", "days_from_now": days_remaining - 3},
            {"step": 7, "label": "Soumettre le dossier", "days_from_now": days_remaining},
        ]

    return [
        {
            "step": s["step"],
            "label": s["label"],
            "due": (today + timedelta(days=s["days_from_now"])).isoformat(),
            "status": "pending",
        }
        for s in steps
    ]
