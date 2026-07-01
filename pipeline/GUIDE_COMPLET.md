# Guide complet — Pipeline FlyAI
## Réponses à tes questions dans l'ordre

---

## Question 1 : Est-ce que je dois supprimer les bourses existantes ?

**NON.** Ne supprime rien.

Le pipeline fait des "upsert" : si une bourse existe déjà → il la met à jour.
Si elle n'existe pas → il l'insère.
Tes données existantes sont conservées.

---

## Question 2 : Que faire avec clean_bourses.csv ?

Le fichier clean_bourses.csv c'est juste un aperçu de ce que le pipeline
a produit pour vérification. Tu n'as PAS à l'importer manuellement.

À la place, le script clean_existing.py le fait automatiquement
et envoie directement dans Supabase.

---

## Question 3 : Par où commencer ? (ordre exact)

### ÉTAPE 1 — Supabase SQL Editor (2 minutes)

1. Va sur https://supabase.com → ton projet
2. Clique sur "SQL Editor" dans le menu gauche
3. Copie-colle tout le contenu du fichier schema_pipeline_patch.sql
4. Clique sur "Run"
5. Tu dois voir : "Success. No rows returned"

C'est tout pour Supabase pour l'instant.

---

### ÉTAPE 2 — Mettre le code pipeline dans ton projet GitHub

Ton projet GitHub s'appelle FlyAI-app (ou similaire).
Il ressemble à ça actuellement :

    FlyAI-app/
    ├── flyai/          ← ton app Flutter
    ├── data/
    ├── scripts/        ← tes anciens scrapers (NE PAS TOUCHER)
    └── architecture.md

Tu dois ajouter le dossier flyai_pipeline comme ça :

    FlyAI-app/
    ├── flyai/
    ├── data/
    ├── scripts/        ← tes anciens scrapers (inchangés)
    ├── pipeline/       ← le nouveau dossier (renomme flyai_pipeline en pipeline)
    │   ├── scripts/
    │   │   ├── models/
    │   │   ├── parsers/
    │   │   ├── normalizers/
    │   │   ├── clean_existing.py
    │   │   ├── pipeline.py
    │   │   ├── requirements.txt
    │   │   └── .env.example
    │   └── schema_pipeline_patch.sql
    └── architecture.md

Comment faire :
- Extrais le ZIP flyai_pipeline.zip
- Renomme le dossier en "pipeline"
- Glisse-le dans ton repo FlyAI-app

---

### ÉTAPE 3 — Créer le fichier .env dans pipeline/scripts/

Dans le dossier pipeline/scripts/, crée un fichier nommé ".env"
(copie .env.example et remplis-le) :

    SUPABASE_URL=https://nymqiqkuotwuccitbzfq.supabase.co
    SUPABASE_KEY=ta_clé_anon_ici

La clé anon se trouve dans Supabase → Settings → API → "anon public"

IMPORTANT : ajoute .env dans ton .gitignore (ne jamais commiter les clés)

---

### ÉTAPE 4 — Nettoyer et importer tes 100 bourses existantes (une seule fois)

Ouvre PowerShell dans le dossier pipeline/scripts/ :

    pip install -r requirements.txt

    python clean_existing.py --input bourses_rows.csv --push

Le script va :
- Parser toutes les deadlines
- Calculer les statuts (expired, open, upcoming...)
- Dédupliquer
- Envoyer tout dans Supabase automatiquement

---

### ÉTAPE 5 — GitHub Actions (exécution automatique quotidienne)

GitHub Actions = GitHub exécute ton script chaque jour sur ses serveurs.
Tu n'as rien à faire tourner sur ton ordi.

1. Dans ton repo FlyAI-app, crée ce dossier : .github/workflows/
   (le point devant .github est important)

2. Dans ce dossier, crée un fichier pipeline.yml
   (copie le contenu de .github_workflow_example.yml livré dans le ZIP)

3. Va sur GitHub → ton repo → Settings → Secrets and variables → Actions
   → New repository secret :
   - Nom : SUPABASE_URL   Valeur : https://nymqiqkuotwuccitbzfq.supabase.co
   - Nom : SUPABASE_KEY   Valeur : ta_clé_anon

4. Push tout sur GitHub.

C'est tout. GitHub lancera le pipeline automatiquement chaque jour à 06:00 UTC.
Tu peux aussi le déclencher manuellement :
  GitHub → ton repo → Actions → FlyAI Pipeline → Run workflow

---

## Question 4 : Où est .github/workflows/ ?

Ce dossier n'existe pas encore — tu dois le créer toi-même
à la RACINE de ton repo FlyAI-app (pas dans pipeline/).

Structure finale complète :

    FlyAI-app/                          ← racine du repo
    ├── .github/                        ← à créer
    │   └── workflows/                  ← à créer
    │       └── pipeline.yml            ← à créer (contenu dans le ZIP)
    ├── flyai/                          ← app Flutter (inchangée)
    ├── pipeline/                       ← le nouveau dossier pipeline
    │   └── scripts/
    │       ├── .env                    ← à créer, NE PAS commiter
    │       ├── clean_existing.py
    │       ├── pipeline.py
    │       └── requirements.txt
    └── .gitignore                      ← ajouter "pipeline/scripts/.env"

---

## Résumé en 5 actions

| # | Où             | Quoi                                               |
|---|----------------|----------------------------------------------------|
| 1 | Supabase       | Coller schema_pipeline_patch.sql → Run             |
| 2 | Ton ordi       | Extraire ZIP → renommer en "pipeline" → dans repo  |
| 3 | Ton ordi       | Créer pipeline/scripts/.env avec tes clés          |
| 4 | PowerShell     | pip install + python clean_existing.py --push      |
| 5 | GitHub         | Créer .github/workflows/pipeline.yml + secrets     |

