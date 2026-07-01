# Lancer le pipeline sur Windows (PowerShell)

## Pourquoi l'erreur ?
Sur Linux/Mac, on peut faire `KEY=value python script.py`.
Sur Windows PowerShell, cette syntaxe n'existe pas.
Il faut définir les variables d'environnement AVANT la commande.

---

## Méthode 1 — Variables temporaires (session uniquement)

```powershell
# Dans PowerShell, depuis le dossier scripts/
$env:SUPABASE_URL = "https://nymqiqkuotwuccitbzfq.supabase.co"
$env:SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

python clean_existing.py --input bourses_rows.csv --push
```

---

## Méthode 2 — Fichier .env (recommandé)

Créer le fichier `scripts/.env` (copie de `.env.example`) :

```
SUPABASE_URL=https://nymqiqkuotwuccitbzfq.supabase.co
SUPABASE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

Puis simplement :

```powershell
cd scripts
python clean_existing.py --input bourses_rows.csv --push
```

Le script charge automatiquement `.env` via python-dotenv.

---

## Méthode 3 — Script PowerShell tout-en-un

Créer `run_pipeline.ps1` à la racine :

```powershell
$env:SUPABASE_URL = "https://nymqiqkuotwuccitbzfq.supabase.co"
$env:SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

Set-Location scripts
python clean_existing.py --input bourses_rows.csv --push
```

Exécuter avec :
```powershell
.\run_pipeline.ps1
```

---

## Installation des dépendances (une seule fois)

```powershell
cd scripts
pip install -r requirements.txt
```

---

## Ordre complet d'exécution

```powershell
# 1. SQL patch Supabase → coller schema_pipeline_patch.sql dans SQL Editor

# 2. Aller dans le dossier scripts
cd C:\Users\netha\Dev\FlyAI-app\files\flyai_pipeline\scripts

# 3. Installer les deps
pip install -r requirements.txt

# 4. Créer le .env
Copy-Item .env.example .env
notepad .env   # Remplir SUPABASE_URL et SUPABASE_KEY

# 5. Lancer le nettoyage + push
python clean_existing.py --input bourses_rows.csv --push
```
